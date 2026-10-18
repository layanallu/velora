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
//  App Store readiness: fail closed when offline recognition cannot start;
//  never report an active microphone for unsupported/failed recognition.
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
    // Non-nil only when speech access/service needs the user’s attention.
    @Published private(set) var recoveryIssue: SpeechRecognitionIssue? = nil
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
    // Ignore delayed callbacks from previously cancelled recognition requests.
    private var recognitionGenerationID = UUID()
    // A second generation rejects queued mic-level updates after stopping/restarting.
    private var audioSessionGenerationID = UUID()

    // Audio taps run off the main thread. Protect request replacement while
    // appending audio, especially when on-device recognition ends in silence.
    private let bufferRequestLock = NSLock()
    private var bufferRequest: SFSpeechAudioBufferRecognitionRequest?

    // Do not restart the Speech service forever on a no-speech error.
    private var silenceRecoveryCount = 0
    private let maximumSilenceRecoveries = 2

    // Publish display levels at a readable pace, not once per 1024-frame buffer.
    private var lastLevelPublishTime: TimeInterval = 0
    private var lastActiveSpeechTime: TimeInterval = 0
    private let levelPublishInterval: TimeInterval = 1.0 / 15.0
    private let speechHangover: TimeInterval = 0.28

    private let recognizer: SFSpeechRecognizer?

    private let onsetAnalyzer = OnsetAnalyzer()
    // Preserve completed analyzer evidence independently from queued UI updates.
    // The speech recognizer may auto-stop while that main-thread update is pending.
    private let onsetEvidence = OnsetEvidenceStore()
    private var currentSampleRate: Double = 44100
    private let tapBufferSize: AVAudioFrameCount = 1024
    private var hasInstalledTap = false

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
    func setExpectedPhrase(_ text: String) { expectedWords = SpeechWordMatcher.words(from: text) }
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

    // MARK: - Recovery
    func clearRecoveryIssue() {
        recoveryIssue = nil
        statusMessage = nil
    }

    private func report(_ issue: SpeechRecognitionIssue) {
        recoveryIssue = issue
        statusMessage = issue.title
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

    // MARK: - Offline-only activation

    /// Returns true only when the microphone and the English on-device recognizer
    /// have started successfully. Screens use this result for their mic state.
    @discardableResult
    func start() -> Bool {
        guard !isRecording else { return true }
        clearRecoveryIssue()

        // Settings can change while Velora is in the background.
        let microphoneAllowed = AVAudioSession.sharedInstance().recordPermission == .granted
        let speechAllowed = SFSpeechRecognizer.authorizationStatus() == .authorized
        isAuthorized = microphoneAllowed && speechAllowed
        guard isAuthorized else {
            report(.permissionRequired)
            return false
        }

        guard let recognizer else {
            supportsOnDevice = false
            report(.onDeviceEnglishUnavailable)
            return false
        }

        supportsOnDevice = recognizer.supportsOnDeviceRecognition
        guard supportsOnDevice else {
            report(.onDeviceEnglishUnavailable)
            return false
        }

        guard recognizer.isAvailable else {
            report(.serviceInterrupted)
            return false
        }

        do {
            try configureSessionSafely()
            transcript = ""
            didMatchExpectedPhrase = false
            resetOnset()
            silenceRecoveryCount = 0
            lastLevelPublishTime = 0
            lastActiveSpeechTime = 0
            rawRMS = 0
            audioLevel = 0
            voicing = 0
            isSpeaking = false

            // Set active before creating the asynchronous recognition task: its
            // callback may arrive before AVAudioEngine.start() returns.
            isRecording = true
            startRecognitionTask(recognizer: recognizer)
            try startEngineTapIfNeeded()

            statusMessage = nil
            return true
        } catch {
            stop()
            report(.microphoneUnavailable)
            return false
        }
    }

    func stop() {
        // Mark the session inactive before cancelling a recognition task, because
        // cancellation can trigger delayed Speech framework callbacks.
        isRecording = false
        isSpeaking = false

        recognitionGenerationID = UUID()
        audioSessionGenerationID = UUID()
        onsetEvidence.invalidate()
        closeRecognitionRequest()
        task?.cancel()
        task = nil
        rawRMS = 0
        audioLevel = 0
        voicing = 0

        // Stop the audio callback before closing its CAF writer.
        if audioEngine.isRunning { audioEngine.stop() }
        if hasInstalledTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        shouldRecordToFile = false
        recordFile = nil
        recordURL = nil

        do {
            try AVAudioSession.sharedInstance().setActive(
                false, options: .notifyOthersOnDeactivation
            )
        } catch {
            // Deactivation is best-effort; all mic/recognition resources are closed.
        }
    }

    // MARK: - Easy Onset evidence handoff

    /// Commit an ALREADY COMPLETED acoustic measurement before automatic or
    /// manual stop. This does not manufacture a result if capture was short.
    /// Rhythm never calls this method; its scoring and playback are unchanged.
    func commitCompletedOnsetForEvaluation() {
        guard isRecording else { return }
        guard let metrics = onsetEvidence.snapshot(generation: audioSessionGenerationID) else { return }
        applyOnsetMetrics(metrics)
    }

    private func applyOnsetMetrics(_ metrics: OnsetMetrics) {
        onsetScore = metrics.score
        onsetKind = metrics.kind
        onsetVerdict = metrics.verdict
        onsetHint = metrics.hint
        onsetConfidence = metrics.confidence
        onsetDebug = metrics.debug
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
    private func startEngineTapIfNeeded() throws {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        currentSampleRate = format.sampleRate

        onsetAnalyzer.reset(sampleRate: currentSampleRate, framesPerBuffer: Double(tapBufferSize))

        if hasInstalledTap {
            input.removeTap(onBus: 0)
            hasInstalledTap = false
        }
        let audioGeneration = UUID()
        audioSessionGenerationID = audioGeneration
        onsetEvidence.begin(generation: audioGeneration)
        input.installTap(onBus: 0, bufferSize: tapBufferSize, format: format) { [weak self] buffer, _ in
            guard let self else { return }

            self.appendAudioBuffer(buffer)
            self.updateLevelAndOnset(from: buffer, generation: audioGeneration)
            self.writeBufferToFileIfNeeded(buffer)
        }

        hasInstalledTap = true
        audioEngine.prepare()
        try audioEngine.start()
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

    // MARK: - Speech framework lifecycle

    /// Send a buffer only to the active recognition request. This lock also
    /// serializes endAudio() with append(), preventing request-replacement races.
    /// The critical section is tiny and contains no SwiftUI work.
    private func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferRequestLock.lock()
        bufferRequest?.append(buffer)
        bufferRequestLock.unlock()
    }

    private func replaceBufferRequest(with next: SFSpeechAudioBufferRecognitionRequest?) {
        bufferRequestLock.lock()
        let previous = bufferRequest
        bufferRequest = next
        previous?.endAudio()
        bufferRequestLock.unlock()
    }

    private func closeRecognitionRequest() {
        replaceBufferRequest(with: nil)
        request = nil
    }

    private func startRecognitionTask(recognizer: SFSpeechRecognizer) {
        // Invalidate old callbacks *before* cancelling the previous task.
        recognitionGenerationID = UUID()
        let generation = recognitionGenerationID
        task?.cancel()
        task = nil

        let nextRequest = SFSpeechAudioBufferRecognitionRequest()
        nextRequest.shouldReportPartialResults = true
        nextRequest.requiresOnDeviceRecognition = true
        request = nextRequest
        replaceBufferRequest(with: nextRequest)

        task = recognizer.recognitionTask(with: nextRequest) { [weak self] result, error in
            // SFSpeechRecognizer does not guarantee a main-thread callback.
            // All @Published mutations and Speech task transitions stay on main.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isRecording,
                      self.recognitionGenerationID == generation else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    self.checkExpectedPhraseMatch()
                }

                if let error {
                    let nsError = error as NSError
                    // A cancelled task must never turn into a failure popup.
                    if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                        return
                    }
                    if let issue = SpeechRecognitionIssue.from(error: nsError) {
                        // Connection failures (1101/1107/4097) are not silence.
                        // Stop fully, surface one alert, and wait for a user retry.
                        self.stop()
                        self.report(issue)
                        return
                    }
                    // Code 1110 is ordinary no-speech detection, not a
                    // permission problem. Limit automatic recovery attempts.
                    if self.silenceRecoveryCount < self.maximumSilenceRecoveries {
                        self.silenceRecoveryCount += 1
                        self.startRecognitionTask(recognizer: recognizer)
                    } else {
                        self.stop()
                        self.statusMessage = "I couldn't hear speech. Tap the mic to try again."
                    }
                }
            }
        }
    }

    // MARK: - Expected phrase matching (IDEA 2 + 3 ✅)

    /// IDEA (2): Fuzzy word similarity
    /// IDEA (3): LCS / subsequence matching
    private func checkExpectedPhraseMatch() {
        guard didMatchExpectedPhrase == false else { return }
        guard expectedWords.isEmpty == false else { return }

        let spoken = SpeechWordMatcher.words(from: transcript, expected: expectedWords)
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
        if minLen >= 5 && abs(la - lb) <= 1 {
            let pref = commonPrefixLength(a, b)
            let need = max(4, Int(round(Double(minLen) * 0.80)))
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

    // MARK: - Level + Onset
    private func updateLevelAndOnset(from buffer: AVAudioPCMBuffer, generation: UUID) {
        guard let channel = buffer.floatChannelData?.pointee else { return }
        let n = Int(buffer.frameLength)
        guard n > 0 else { return }

        var sum: Float = 0
        for i in 0..<n {
            let value = channel[i]
            sum += value * value
        }

        let rms = sqrt(sum / Float(n))
        let normalized = min(max(rms * 10, 0), 1)
        let metrics = onsetAnalyzer.process(rms: rms)
        // Commit completed results synchronously on the tap side. Otherwise a
        // phrase-match callback can stop the mic before the UI receives them.
        if let metrics {
            onsetEvidence.recordCompleted(metrics, generation: generation)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRecording,
                  self.audioSessionGenerationID == generation else { return }

            let now = Date.timeIntervalSinceReferenceDate
            if now - self.lastLevelPublishTime >= self.levelPublishInterval {
                self.lastLevelPublishTime = now
                self.rawRMS = rms
                self.audioLevel = normalized
                self.voicing = normalized

                // A natural pause between words is not the end of an attempt.
                if normalized > self.speakingThreshold {
                    self.lastActiveSpeechTime = now
                    if !self.isSpeaking { self.isSpeaking = true }
                } else if self.isSpeaking,
                          now - self.lastActiveSpeechTime >= self.speechHangover {
                    self.isSpeaking = false
                }
            }

            // The audio tap may detect multiple acoustic starts in one phrase.
            // Display the SAME first completed result used at auto-stop rather
            // than allowing later words to overwrite the early-onset verdict.
            if metrics != nil,
               let first = self.onsetEvidence.snapshot(generation: generation) {
                self.applyOnsetMetrics(first)
            }
        }
    }
}
