//
//  SpeechTranscriber.swift
//  Velora
//
//  On-device speech recognition + speech activity + ONSET QUALITY (Easy Onset).
//  Offline-first (requiresOnDeviceRecognition = true).
//
//  ✅ Adds expected phrase matching (for auto-stop behavior in EasyOnsetView).
//  ✅ Adds rawRMS + optional file recording sink (for Rhythm playback recording).
//
//  Created by Velora on 24/02/2026.
//  Updated by Velora on 26/02/2026.
//
//  Updated by Velora on 28/02/2026:
//
//  ✅ Less strict matching using IDEA (2) + (3):
//     (2) Fuzzy word similarity (typos / near-words).
//     (3) Subsequence matching (LCS) to tolerate repeats / skips.
//
//  ✅ Does NOT require first word exact match anymore.
//

import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
final class SpeechTranscriber: ObservableObject {

    // MARK: - Published
    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var audioLevel: Float = 0     // 0...1 approx (RMS normalized)
    @Published var voicing: Float = 0        // same scale as audioLevel
    @Published var rawRMS: Float = 0         // ✅ raw RMS (for scoring capture)
    @Published var statusMessage: String? = nil
    @Published var isAuthorized: Bool = false
    @Published var supportsOnDevice: Bool = false

    // Onset outputs
    @Published var onsetScore: Int = 0
    @Published var onsetKind: OnsetMetrics.Kind = .unknown
    @Published var onsetVerdict: OnsetMetrics.Verdict = .notDetected
    @Published var onsetHint: String = "Start gently…"
    @Published var onsetConfidence: Float = 0.0
    @Published var onsetDebug: String? = nil

    // Expected phrase match flag (for EasyOnsetView auto-stop)
    @Published var didMatchExpectedPhrase: Bool = false

    // MARK: - Private
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?

    private let onsetAnalyzer = OnsetAnalyzer()
    private var currentSampleRate: Double = 44100
    private let tapBufferSize: AVAudioFrameCount = 1024

    private let speakingThreshold: Float = 0.028
    private var expectedWords: [String] = []

    // MARK: - Matching Tunables (IDEA 2 + 3)
    /// Ratio of expected words that must be matched via subsequence (LCS).
    /// Example: 0.70 means "match ~70% of expected words" (order-respecting but tolerant).
    private var lcsMatchRatio: Float = 0.70

    /// If expected phrase is very short, ensure at least this many words match.
    private var minimumMatchedWords: Int = 1

    // ✅ File recording (Rhythm segments)
    private var recordURL: URL? = nil
    private var recordFile: AVAudioFile? = nil
    private var shouldRecordToFile: Bool = false

    init(locale: Locale = Locale(identifier: "en_US")) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
        self.supportsOnDevice = recognizer?.supportsOnDeviceRecognition ?? false
    }

    // MARK: - Expected phrase API
    func setExpectedPhrase(_ text: String) { expectedWords = Self.words(from: text) }
    func resetExpectedMatch() { didMatchExpectedPhrase = false }

    /// Configure relaxed matching strictness (optional).
    /// ratio is clamped to 0.40...1.00
    func configureMatch(ratio: Float, minWords: Int = 1) {
        lcsMatchRatio = min(max(ratio, 0.40), 1.00)
        minimumMatchedWords = max(1, minWords)
    }

    // MARK: - File recording API (Rhythm)
    func startFileRecording(to url: URL) {
        recordURL = url
        recordFile = nil
        shouldRecordToFile = true
    }

    func stopFileRecording() {
        shouldRecordToFile = false
        recordFile = nil
        recordURL = nil
    }

    // MARK: - Permissions
    func requestPermissions() async {
        let micGranted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in c.resume(returning: granted) }
        }

        let speechStatus = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in c.resume(returning: status) }
        }

        let speechGranted = (speechStatus == .authorized)
        isAuthorized = micGranted && speechGranted

        if !micGranted {
            statusMessage = "Microphone permission is needed."
        } else if !speechGranted {
            statusMessage = "Speech Recognition permission is needed."
        } else {
            statusMessage = nil
        }
    }

    // MARK: - Control
    func resetTranscript() {
        transcript = ""
        didMatchExpectedPhrase = false
    }

    func resetOnset() {
        onsetScore = 0
        onsetKind = .unknown
        onsetVerdict = .notDetected
        onsetHint = "Start gently…"
        onsetConfidence = 0.0
        onsetDebug = nil
    }

    func start() {
        guard isRecording == false else { return }

        guard isAuthorized else {
            statusMessage = statusMessage ?? "Permissions are not granted yet."
            return
        }

        guard let recognizer, recognizer.isAvailable else {
            statusMessage = "Speech recognition is not available right now."
            return
        }

        supportsOnDevice = recognizer.supportsOnDeviceRecognition

        do {
            try configureSessionSafely()
        } catch {
            statusMessage = "Audio setup failed: \(error.localizedDescription)"
            stop()
            return
        }

        transcript = ""
        didMatchExpectedPhrase = false
        resetOnset()

        startEngineTapIfNeeded()

        if supportsOnDevice {
            startRecognitionTask(recognizer: recognizer)
        } else {
            statusMessage = "On-device recognition isn't supported on this device."
        }

        isRecording = true
        statusMessage = nil
    }

    func stop() {
        task?.cancel()
        task = nil

        request?.endAudio()
        request = nil

        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)

        isRecording = false
        isSpeaking = false

        // Keep file open only per segment (caller controls)
        recordFile = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // harmless
        }
    }

    // MARK: - Audio session
    private func configureSessionSafely() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetooth]
        )

        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Engine Tap (mic level + onset + optional file recording)
    private func startEngineTapIfNeeded() {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        currentSampleRate = format.sampleRate

        onsetAnalyzer.reset(sampleRate: currentSampleRate, framesPerBuffer: Double(tapBufferSize))

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: tapBufferSize, format: format) { [weak self] buffer, _ in
            guard let self else { return }

            self.request?.append(buffer)
            self.updateLevelAndOnset(from: buffer)
            self.writeBufferToFileIfNeeded(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            statusMessage = "Could not start microphone."
        }
    }

    private func writeBufferToFileIfNeeded(_ buffer: AVAudioPCMBuffer) {
        guard shouldRecordToFile else { return }
        guard let url = recordURL else { return }

        do {
            if recordFile == nil {
                // Create file on first buffer so format matches mic format
                recordFile = try AVAudioFile(forWriting: url, settings: buffer.format.settings)
            }
            try recordFile?.write(from: buffer)
        } catch {
            // If writing fails, stop file recording gracefully (no crash)
            shouldRecordToFile = false
            recordFile = nil
        }
    }

    // MARK: - Recognition Task (restart-safe)
    private func startRecognitionTask(recognizer: SFSpeechRecognizer) {
        task?.cancel()
        task = nil

        let r = SFSpeechAudioBufferRecognitionRequest()
        r.shouldReportPartialResults = true
        r.requiresOnDeviceRecognition = true
        request = r

        task = recognizer.recognitionTask(with: r) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.transcript = result.bestTranscription.formattedString
                self.checkExpectedPhraseMatch()
            }

            if let error {
                let msg = error.localizedDescription
                if msg.lowercased().contains("no speech detected") {
                    self.statusMessage = nil
                    self.restartRecognition(recognizer: recognizer)
                    return
                }
                self.statusMessage = "Recognition paused: \(msg)"
                self.restartRecognition(recognizer: recognizer)
            }
        }
    }

    private func restartRecognition(recognizer: SFSpeechRecognizer) {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil

        let r = SFSpeechAudioBufferRecognitionRequest()
        r.shouldReportPartialResults = true
        r.requiresOnDeviceRecognition = true
        request = r

        task = recognizer.recognitionTask(with: r) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.transcript = result.bestTranscription.formattedString
                self.checkExpectedPhraseMatch()
            }
            if let error {
                let msg = error.localizedDescription
                if msg.lowercased().contains("no speech detected") {
                    self.statusMessage = nil
                    return
                }
                self.statusMessage = "Recognition paused: \(msg)"
            }
        }
    }

    // MARK: - Expected phrase matching (IDEA 2 + 3 ✅)

    /// IDEA (2): Fuzzy word similarity
    /// IDEA (3): LCS / subsequence matching
    private func checkExpectedPhraseMatch() {
        guard didMatchExpectedPhrase == false else { return }
        guard expectedWords.isEmpty == false else { return }

        let spoken = Self.words(from: transcript)
        guard spoken.isEmpty == false else { return }

        // Subsequence match ratio
        let lcs = lcsMatchCount(expected: expectedWords, spoken: spoken)
        let ratio: Float = expectedWords.isEmpty ? 0 : Float(lcs) / Float(expectedWords.count)

        // For short phrases be extra kind
        let requiredCount = max(minimumMatchedWords, Int(ceil(Float(expectedWords.count) * lcsMatchRatio)))

        if lcs >= requiredCount || ratio >= lcsMatchRatio {
            didMatchExpectedPhrase = true
        }
    }

    /// LCS count using fuzzy word equality.
    private func lcsMatchCount(expected: [String], spoken: [String]) -> Int {
        let n = expected.count
        let m = spoken.count
        if n == 0 || m == 0 { return 0 }

        // DP with rolling rows (memory friendly)
        var prev = Array(repeating: 0, count: m + 1)
        var cur  = Array(repeating: 0, count: m + 1)

        for i in 1...n {
            cur[0] = 0
            for j in 1...m {
                if fuzzyEqual(expected[i - 1], spoken[j - 1]) {
                    cur[j] = prev[j - 1] + 1
                } else {
                    cur[j] = max(prev[j], cur[j - 1])
                }
            }
            prev = cur
        }
        return prev[m]
    }

    /// IDEA (2): fuzzy word equality:
    /// - exact match
    /// - OR small edit distance
    /// - OR strong prefix similarity
    private func fuzzyEqual(_ a: String, _ b: String) -> Bool {
        if a == b { return true }

        // If any is very short, allow tiny deviation only
        let la = a.count
        let lb = b.count
        let minLen = min(la, lb)

        // Prefix similarity (helps with partial SR tokens)
        if minLen >= 3 {
            let pref = commonPrefixLength(a, b)
            let need = max(3, Int(round(Double(minLen) * 0.60)))
            if pref >= need { return true }
        }

        // Edit distance (typos / near words)
        let d = levenshtein(a, b, cap: 2)
        if minLen <= 4 {
            return d <= 1
        } else {
            return d <= 2
        }
    }

    private func commonPrefixLength(_ a: String, _ b: String) -> Int {
        let aa = Array(a)
        let bb = Array(b)
        let n = min(aa.count, bb.count)
        var k = 0
        while k < n {
            if aa[k] != bb[k] { break }
            k += 1
        }
        return k
    }

    /// Small capped Levenshtein distance (fast, offline).
    /// cap=2 means we early-stop once distance exceeds 2.
    private func levenshtein(_ s: String, _ t: String, cap: Int) -> Int {
        if s == t { return 0 }
        let a = Array(s)
        let b = Array(t)
        let n = a.count
        let m = b.count
        if n == 0 { return min(m, cap + 1) }
        if m == 0 { return min(n, cap + 1) }

        // If length diff already > cap, we can return cap+1
        if abs(n - m) > cap { return cap + 1 }

        var prev = Array(0...m)
        var cur = Array(repeating: 0, count: m + 1)

        for i in 1...n {
            cur[0] = i
            var rowMin = cur[0]

            for j in 1...m {
                let cost = (a[i - 1] == b[j - 1]) ? 0 : 1
                cur[j] = min(
                    prev[j] + 1,        // deletion
                    cur[j - 1] + 1,     // insertion
                    prev[j - 1] + cost  // substitution
                )
                rowMin = min(rowMin, cur[j])
            }

            if rowMin > cap { return cap + 1 }
            prev = cur
        }
        return prev[m]
    }

    private static func words(from input: String) -> [String] {
        let lower = input.lowercased()
        let cleaned = lower
            .replacingOccurrences(of: "[^a-z\\s']", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty { return [] }
        return cleaned.split(separator: " ").map { String($0) }
    }

    // MARK: - Level + Onset
    private func updateLevelAndOnset(from buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?.pointee else { return }
        let n = Int(buffer.frameLength)
        if n == 0 { return }

        var sum: Float = 0
        for i in 0..<n {
            let s = channel[i]
            sum += s * s
        }

        let rms = sqrt(sum / Float(n))
        let normalized = min(max(rms * 10, 0), 1)

        let metrics = onsetAnalyzer.process(rms: rms)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.rawRMS = rms
            self.audioLevel = normalized
            self.voicing = normalized
            self.isSpeaking = normalized > self.speakingThreshold

            if let m = metrics {
                self.onsetScore = m.score
                self.onsetKind = m.kind
                self.onsetVerdict = m.verdict
                self.onsetHint = m.hint
                self.onsetConfidence = m.confidence
                self.onsetDebug = m.debug
            }
        }
    }
}
