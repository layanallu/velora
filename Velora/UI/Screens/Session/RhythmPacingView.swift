//
//  RhythmPacingView.swift
//  Velora
//
//  Phase 2: Rhythm Pacing (Word-by-word gating)
//
//  ✅ Goal: progress when the HIGHLIGHTED word is detected (not the whole sentence).
//  ✅ Does NOT change Easy Onset logic.
//  ✅ Keeps audio segment recording for Feedback playback.
//
//  ✅ FIX: keep sentence-ending punctuation in the UI text,
//  while SR gating ignores punctuation (speakable tokens only).
//
//  ✅ Technique intro supports:
//     - Auto-show first time
//     - Info (i) button
//  ✅ TRUE freeze when card opens:
//     - Mic closes immediately
//     - No transcript handling / pops / sampling while frozen
//
//  ✅ Demo Preview Mode (28/02/2026):
//  - No microphone / speech recognition required.
//  - Tap mic to "Start Preview" (no permissions).
//  - Double-tap anywhere to advance the highlighted word.
//
//  Updated by Velora on 27/02/2026.
//  Updated by Velora on 28/02/2026:
//  ✅ Demo hint under mic improved.
//

import SwiftUI
import Combine

struct RhythmPacingView: View {
    let topic: Topic
    var mode: SessionMode = .normal
    let onComplete: () -> Void

    var onMetrics: ((RhythmMetrics) -> Void)? = nil
    var onAudioFilename: ((String?) -> Void)? = nil

    /// Provided by SessionView (GLOBAL overlay presenter)
    let isTechniqueIntroPresented: Bool
    let requestTechniqueIntro: (_ markSeen: Bool) -> Void

    @StateObject private var transcriber = SpeechTranscriber()

    @State private var isListening: Bool = false
    @State private var showMicDeniedAlert: Bool = false

    @State private var clauses: [ParagraphPacingTextView.Clause] = []
    @State private var clauseIndex: Int = 0
    @State private var wordIndexInClause: Int = 0
    @State private var popped: Int = 0

    /// ✅ Key fix:
    /// Tracks how far we've "consumed" the SR transcript.
    /// This makes progression word-by-word instead of "repeat full sentence".
    @State private var lastMatchedSpokenIndex: Int = 0

    @State private var hint: String = "Tap the mic to start."
    @State private var lastPopTime: CFTimeInterval = 0

    @State private var rmsSamples: [Float] = []
    private let sampleTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    @State private var segmentURLs: [URL] = []
    private let popDebounce: Double = 0.18

    // ✅ Freeze (driven by SessionView overlay)
    @State private var isFrozen: Bool = false

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                header

                Spacer(minLength: 4)

                BubbleWordRailView(
                    total: currentClauseSpeakableCount,
                    progress: popped,
                    isActive: (isListening && !isFrozen)
                )
                .padding(.horizontal, 18)

                ParagraphPacingTextView(
                    clauses: clauses,
                    activeClauseIndex: clauseIndex,
                    activeWordIndexInClause: wordIndexInClause
                )
                .frame(maxWidth: .infinity, maxHeight: 320)
                .padding(.horizontal, 10)

                micButton

                Text(hintLine)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.ink.opacity(0.62))
                    .padding(.horizontal, 18)

                Spacer(minLength: 22)
            }
            // ✅ Demo: double-tap anywhere to progress
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                guard mode.isDemo else { return }
                guard isFrozen == false else { return }
                guard isListening else { return }
                demoAdvanceOneWord()
            }
        }
        .onAppear {
            buildClauses()
            reset()

            rmsSamples = []
            segmentURLs = []

            if !TechniqueIntroStore.hasSeen(.rhythm) {
                requestTechniqueIntro(true)
            }
        }
        .onDisappear { stopListening() }
        .onChange(of: isTechniqueIntroPresented) { presented in
            handleFreezeChange(presented)
        }
        .onChange(of: transcriber.transcript) { _, newValue in
            guard mode.isDemo == false else { return }
            guard isFrozen == false else { return }
            guard isListening else { return }
            handleTranscriptUpdate(newValue)
        }
        .onReceive(sampleTimer) { _ in
            guard mode.isDemo == false else { return }
            guard isFrozen == false else { return }
            guard isListening else { return }
            rmsSamples.append(transcriber.rawRMS)
        }
        .alert("Microphone Access Needed", isPresented: $showMicDeniedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please allow microphone + speech recognition access in Settings so Velora can listen.")
        }
        .task {
            if mode.isDemo == false {
                await transcriber.requestPermissions()
            }
        }
    }

    // MARK: - Header (centered + info next to title)
    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("Rhythm Pacing")
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.ink)

                Button {
                    Haptics.tap()
                    requestTechniqueIntro(false)
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.55))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Rhythm info"))
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 12)
            .padding(.horizontal, 18)

            Text(topic.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.ink.opacity(0.50))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 18)
        }
    }

    // MARK: - Freeze handling
    private func handleFreezeChange(_ shouldFreeze: Bool) {
        if shouldFreeze {
            isFrozen = true
            if isListening { stopListening() }
            hint = "Paused."
        } else {
            isFrozen = false
            // Normal mode still uses `hint` — demo uses hintLine logic
            hint = "Tap the mic to start."
        }
    }

    // ✅ Demo-only hint under mic
    private var hintLine: String {
        if isFrozen { return "Paused." }

        if mode.isDemo {
            if isListening { return "Double-tap anywhere to advance." }
            return "Tap the mic, then double-tap to continue."
        }

        return hint
    }

    // MARK: - Mic
    private var micButton: some View {
        Button {
            Haptics.tap()
            guard isFrozen == false else { return }
            isListening ? stopListening() : startListening()
        } label: {
            ZStack {
                Circle()
                    .fill(AppTheme.paper.opacity(0.92))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [AppTheme.mint, AppTheme.aqua],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .opacity((isListening && !isFrozen) ? 1.0 : 0.60)
                    )
                    .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)

                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.ink.opacity(0.75))
            }
            .opacity(isFrozen ? 0.40 : 1.0)
            .scaleEffect(isListening ? 1.05 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: isListening)
        }
        .buttonStyle(.plain)
        .disabled(isFrozen)
        .accessibilityLabel(isListening ? "Stop microphone" : "Start microphone")
    }

    private func startListening() {
        if mode.isDemo {
            // ✅ Demo: no permissions, no SR, no recording.
            isListening = true
            // hintLine will show the right instruction
            return
        }

        Task { @MainActor in
            if transcriber.isAuthorized == false { await transcriber.requestPermissions() }

            guard transcriber.isAuthorized else {
                showMicDeniedAlert = true
                return
            }

            let segURL = AudioRecorder.makeSegmentURL()
            segmentURLs.append(segURL)
            transcriber.startFileRecording(to: segURL)

            transcriber.resetTranscript()
            lastMatchedSpokenIndex = 0

            transcriber.start()
            isListening = true
            hint = "Speak gently… focus on the highlighted word."
        }
    }

    private func stopListening() {
        isListening = false

        if mode.isDemo {
            // hintLine handles demo copy
            return
        }

        transcriber.stopFileRecording()
        transcriber.stop()
        hint = "Tap the mic to start."
    }

    // MARK: - Demo progression
    private func demoAdvanceOneWord() {
        let expected = expectedSpeakableWordsForCurrentClause()
        guard expected.isEmpty == false else { return }

        let next = popped + 1
        popTo(next, total: expected.count)
    }

    // MARK: - Word-by-word gating (normal only)
    private func handleTranscriptUpdate(_ transcript: String) {
        guard clauseIndex >= 0, clauseIndex < clauses.count else { return }

        let expected = expectedSpeakableWordsForCurrentClause()
        guard expected.isEmpty == false else { return }

        let spoken = normalizedWords(from: transcript)
        guard spoken.isEmpty == false else { return }

        let nextExpectedIndex = popped
        guard nextExpectedIndex >= 0, nextExpectedIndex < expected.count else { return }
        let target = expected[nextExpectedIndex]

        if lastMatchedSpokenIndex > spoken.count { lastMatchedSpokenIndex = 0 }

        if let matchEndIndex = findNextMatchEndIndex(
            spoken: spoken,
            startIndex: lastMatchedSpokenIndex,
            target: target
        ) {
            lastMatchedSpokenIndex = matchEndIndex
            popTo(popped + 1, total: expected.count)
        }
    }

    private func popTo(_ newCount: Int, total: Int) {
        guard isFrozen == false else { return }

        let now = CACurrentMediaTime()
        if now - lastPopTime < popDebounce { return }
        lastPopTime = now

        let clamped = min(max(newCount, 0), total)
        guard clamped > popped else { return }

        Haptics.tap()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            popped = clamped
            wordIndexInClause = min(clamped, total)
        }

        if wordIndexInClause >= total { completeClause() }
    }

    private func completeClause() {
        guard isFrozen == false else { return }

        Haptics.success()
        hint = "Nice. Tiny pause…"

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard self.isFrozen == false else { return }

            if self.clauseIndex >= self.clauses.count - 1 {
                self.finish()
            } else {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                    self.clauseIndex += 1
                    self.wordIndexInClause = 0
                    self.popped = 0
                }

                if self.mode.isDemo == false {
                    self.transcriber.resetTranscript()
                    self.lastMatchedSpokenIndex = 0
                }

                self.hint = self.mode.isDemo ? "" : "Keep it gentle."
            }
        }
    }

    private func finish() {
        stopListening()

        if mode.isDemo {
            // ✅ Demo: give “nice looking” metrics to scoring
            onMetrics?(RhythmMetrics(rmsSamples: [0.02, 0.03, 0.02, 0.04]))
            onAudioFilename?(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) { onComplete() }
            return
        }

        let mergedURL = AudioRecorder.makeMergedURL(topicID: topic.id)
        let out = AudioRecorder.mergeSegments(segmentURLs, outputURL: mergedURL)
        onAudioFilename?(out?.lastPathComponent)

        AudioRecorder.cleanup(segmentURLs)

        onMetrics?(RhythmMetrics(rmsSamples: rmsSamples))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { onComplete() }
    }

    // MARK: - Data helpers
    private var currentClauseSpeakableCount: Int {
        guard clauseIndex >= 0, clauseIndex < clauses.count else { return 0 }
        return clauses[clauseIndex].speakableCount
    }

    private func reset() {
        clauseIndex = 0
        wordIndexInClause = 0
        popped = 0
        lastMatchedSpokenIndex = 0
        hint = "Tap the mic to start."
    }

    // MARK: - Clause building (kept)
    private func buildClauses() {
        let sentences = splitIntoSentences(topic.paragraph)
        var out: [ParagraphPacingTextView.Clause] = []
        for s in sentences {
            let tokens = tokenize(s)
            let chunks = chunkTokensIntoClauses(tokens)
            out.append(contentsOf: chunks)
        }
        if out.isEmpty { out = [ParagraphPacingTextView.Clause(tokens: tokenize("I can take my time."))] }
        clauses = out
    }

    // ✅ FIX: keep sentence-ending punctuation (. ! ? …) in the UI text,
    // while SR gating still ignores punctuation because it only uses isSpeakable tokens.
    private func splitIntoSentences(_ text: String) -> [String] {
        let cleaned = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.isEmpty == false else { return [] }

        let pattern = #"[^.!?…]+(?:[.!?…]+|$)"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let ns = cleaned as NSString
        let matches = regex?.matches(in: cleaned, options: [], range: NSRange(location: 0, length: ns.length)) ?? []

        let parts = matches
            .map { ns.substring(with: $0.range).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return parts.isEmpty ? [cleaned] : parts
    }

    private func tokenize(_ sentence: String) -> [ParagraphPacingTextView.Token] {
        let pattern = #"[A-Za-z']+|[^\sA-Za-z']"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let ns = sentence as NSString
        let matches = regex?.matches(in: sentence, options: [], range: NSRange(location: 0, length: ns.length)) ?? []

        var tokens: [ParagraphPacingTextView.Token] = []
        for m in matches {
            let t = ns.substring(with: m.range)
            let isWord = t.range(of: #"^[A-Za-z']+$"#, options: .regularExpression) != nil
            let isPunct = isWord == false && t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            tokens.append(.init(text: t, isSpeakable: isWord, isPunctuation: isPunct))
        }
        return tokens
    }

    private func chunkTokensIntoClauses(_ tokens: [ParagraphPacingTextView.Token]) -> [ParagraphPacingTextView.Clause] {
        var clauses: [ParagraphPacingTextView.Clause] = []
        var current: [ParagraphPacingTextView.Token] = []

        func flush() {
            let trimmed = current.filter { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            if trimmed.isEmpty == false { clauses.append(.init(tokens: trimmed)) }
            current = []
        }

        for token in tokens {
            current.append(token)
            if token.text == "," || token.text == ";" || token.text == ":" { flush() }
        }
        flush()
        return clauses
    }

    private func expectedSpeakableWordsForCurrentClause() -> [String] {
        guard clauseIndex >= 0, clauseIndex < clauses.count else { return [] }
        let clause = clauses[clauseIndex]
        return clause.tokens
            .filter { $0.isSpeakable }
            .map { normalizeWord($0.text) }
            .filter { !$0.isEmpty }
    }

    private func normalizedWords(from input: String) -> [String] {
        let lower = input.lowercased()
        let cleaned = lower
            .replacingOccurrences(of: "[^a-z\\s']", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty { return [] }

        return cleaned
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { normalizeWord(String($0)) }
            .filter { !$0.isEmpty }
    }

    private func findNextMatchEndIndex(spoken: [String], startIndex: Int, target: String) -> Int? {
        let start = min(max(startIndex, 0), spoken.count)
        if start >= spoken.count { return nil }

        var s = start
        while s < spoken.count {
            if wordsAreClose(spoken[s], target) { return s + 1 }

            if s + 1 < spoken.count {
                let merged = spoken[s] + spoken[s + 1]
                if wordsAreClose(merged, target) { return s + 2 }
            }
            s += 1
        }
        return nil
    }

    private func normalizeWord(_ w: String) -> String {
        w.lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func wordsAreClose(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        if a.hasPrefix(b) || b.hasPrefix(a) { return true }
        return false
    }
}

// MARK: - Preview

struct RhythmPacingView_Previews: PreviewProvider {
    struct Host: View {
        @State private var showIntro: Bool = false

        private let demoTopic = Topic(
            id: "demo",
            category: .readingPassages,
            title: "Quick Preview",
            icon: "sparkles",
            paragraph: "Welcome to Velora. I can take my time."
        )

        var body: some View {
            ZStack {
                RhythmPacingView(
                    topic: demoTopic,
                    mode: .demoPreview,
                    onComplete: {},
                    onMetrics: { _ in },
                    onAudioFilename: { _ in },
                    isTechniqueIntroPresented: showIntro,
                    requestTechniqueIntro: { markSeen in
                        if markSeen { TechniqueIntroStore.markSeen(.rhythm) }
                        withAnimation(.easeInOut(duration: 0.18)) { showIntro = true }
                    }
                )

                if showIntro {
                    TechniqueIntroOverlay(
                        technique: .rhythm,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.18)) { showIntro = false }
                        }
                    )
                    .zIndex(999)
                }
            }
        }
    }

    static var previews: some View {
        Host()
            .preferredColorScheme(.light)
    }
}
