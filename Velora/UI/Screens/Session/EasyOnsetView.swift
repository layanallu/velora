
//
//  EasyOnsetView.swift
//  Velora
//
//  Phase 1: Easy Onset (Guided Karaoke + Friendly Feedback)
//
//  ✅ Preserves layout + BottomPeek.
//  ✅ No Debug panel.
//  ✅ No text above the mic.
//  ✅ Status text under the mic.
//  ✅ ONE compact feedback toast (Apple-style).
//
//  ✅ Scoring support (V1):
//  - Samples transcriber.rawRMS while listening (no second audio engine).
//  - Collects onsetScores per evaluation.
//  - Emits EasyOnsetMetrics when phase completes.
//
//  ✅ Demo Preview Mode (28/02/2026):
//  - No microphone / speech recognition required.
//  - Tap mic -> waits briefly -> auto-success -> progresses steps.
//  - Keeps the full UI flow for judges.
//
//  Updated by Velora on 27/02/2026.
//  Updated by Velora on 28/02/2026:
//  ✅ Matching relaxed using IDEA (2) + (3):
//     - Fuzzy similarity + subsequence LCS (no first-word strict gate)
//  ✅ Onset gate relaxed.
//

import SwiftUI
import Combine

struct EasyOnsetView: View {
    let topic: Topic
    var mode: SessionMode = .normal
    let onComplete: () -> Void

    var onMetrics: ((EasyOnsetMetrics) -> Void)? = nil

    let isTechniqueIntroPresented: Bool
    let requestTechniqueIntro: (_ markSeen: Bool) -> Void

    @State private var index: Int = 0

    @State private var isTutorialPlaying: Bool = true
    @State private var tutorialKey: UUID = UUID()

    @State private var tutorialRemaining: Double = 0
    @State private var lastTutorialTick: Date = Date()

    @State private var isListening: Bool = false
    @State private var justSucceeded: Bool = false

    @State private var guidanceStartToken: UUID = UUID()
    @State private var wasSpeaking: Bool = false

    @State private var feedback: FeedbackToastModel? = nil

    @StateObject private var transcriber = SpeechTranscriber(locale: Locale(identifier: "en_US"))

    // MARK: - Scoring capture (V1)
    @State private var rmsSamples: [Float] = []
    @State private var onsetScores: [Int] = []

    private let sampleTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let tutorialTicker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    /// Honest gate: only block if system is VERY confident it was not a soft start.
    private let honestGateConfidence: Float = 0.80

    /// Transcript acceptance ratio (IDEA 3): subsequence LCS ratio.
    private let transcriptLCSRatio: Float = 0.70

    @State private var isFrozen: Bool = false

    // MARK: - Demo Preview
    @State private var demoInFlight: Bool = false
    private let demoSuccessDelay: Double = 0.75

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                    .padding(.horizontal, 18)

                Spacer(minLength: 18)

                VStack(spacing: 14) {
                    stepTextBlock
                    micButton

                    Text(statusLine)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(0.55))

                    if let feedback, isTutorialPlaying == false {
                        FeedbackToast(model: feedback)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .frame(height: 272, alignment: .top)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)

                Spacer(minLength: 18)

                bottomPeekVelora
            }
        }
        .task {
            // ✅ Demo mode: skip permissions + SR config (still shows full UI)
            if mode.isDemo == false {
                await transcriber.requestPermissions()
                transcriber.setExpectedPhrase(sanitizedStep)
                transcriber.configureMatch(ratio: transcriptLCSRatio, minWords: 1)
            }

            rmsSamples = []
            onsetScores = []

            if !TechniqueIntroStore.hasSeen(.easyOnset) {
                requestTechniqueIntro(true)
            }

            playTutorial()
        }
        .onChange(of: index) { _ in
            if mode.isDemo == false {
                transcriber.setExpectedPhrase(sanitizedStep)
                transcriber.configureMatch(ratio: transcriptLCSRatio, minWords: 1)
            }
            playTutorial()
        }
        .onChange(of: isTechniqueIntroPresented) { presented in
            handleFreezeChange(presented)
        }
        .onReceive(tutorialTicker) { tick in
            defer { lastTutorialTick = tick }
            guard isTutorialPlaying else { return }
            guard isFrozen == false else { return }

            let dt = tick.timeIntervalSince(lastTutorialTick)
            guard dt > 0 else { return }

            tutorialRemaining -= dt
            if tutorialRemaining <= 0 { finishTutorial() }
        }
        .onChange(of: transcriber.isSpeaking) { speaking in
            // ✅ Demo mode: do not evaluate via SR speaking edges
            guard mode.isDemo == false else { return }

            guard isFrozen == false else { return }
            guard isTutorialPlaying == false else { wasSpeaking = speaking; return }
            guard isListening else { wasSpeaking = speaking; return }

            if wasSpeaking == false && speaking == true {
                guidanceStartToken = UUID()
            }

            if wasSpeaking == true && speaking == false {
                evaluateAtEndOfSpeech()
            }

            wasSpeaking = speaking
        }
        .onChange(of: transcriber.didMatchExpectedPhrase) { matched in
            // ✅ Demo mode: no SR auto-match
            guard mode.isDemo == false else { return }

            guard isFrozen == false else { return }
            guard isListening else { return }
            guard isTutorialPlaying == false else { return }
            guard matched else { return }
            stopListening(userInitiated: false)
            evaluate()
        }
        .onReceive(sampleTimer) { _ in
            // ✅ Demo mode: no RMS sampling from SR
            guard mode.isDemo == false else { return }

            guard isFrozen == false else { return }
            guard isListening else { return }
            rmsSamples.append(transcriber.rawRMS)
        }
        .onDisappear {
            transcriber.stop()
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Text("Easy Onset")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
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
                .accessibilityLabel(Text("Easy Onset info"))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text(topic.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.ink.opacity(0.50))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Freeze handling
    private func handleFreezeChange(_ shouldFreeze: Bool) {
        if shouldFreeze {
            isFrozen = true
            if isListening { stopListening(userInitiated: false) }
            demoInFlight = false
        } else {
            isFrozen = false
            lastTutorialTick = Date()
        }
    }

    // MARK: - Step Text Block
    private var stepTextBlock: some View {
        let text = sanitizedStep
        let modeView: EasyOnsetKaraokeTextView.Mode = {
            if isTutorialPlaying {
                return .tutorial(phrase: text, totalDuration: tutorialDuration(for: text))
            } else {
                return .guidedPractice(
                    phrase: text,
                    isActive: (isListening && (mode.isDemo ? false : transcriber.isSpeaking) && isFrozen == false),
                    startToken: guidanceStartToken,
                    mismatch: false,
                    totalDuration: tutorialDuration(for: text)
                )
            }
        }()

        return Group {
            EasyOnsetKaraokeTextView(mode: modeView)
                .id(tutorialKey)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: 350, alignment: .center)
        }
        .modifier(RealWidthClamp(horizontalPadding: 28))
        .clipped()
    }

    private struct RealWidthClamp: ViewModifier {
        let horizontalPadding: CGFloat
        func body(content: Content) -> some View {
            if #available(iOS 17.0, *) {
                content
                    .containerRelativeFrame(.horizontal)
                    .padding(.horizontal, horizontalPadding)
            } else {
                let w = Swift.max(0, UIScreen.main.bounds.width - (horizontalPadding * 2))
                content
                    .frame(width: w, alignment: .center)
            }
        }
    }

    // MARK: - Bottom Peek
    private var bottomPeekVelora: some View {
        let characterSize: CGFloat = 720
        let peekHeight: CGFloat = 330
        let characterOffsetY: CGFloat = 92

        return ZStack(alignment: .bottom) {
            PeekArcLine(yFactor: 0.68)
                .stroke(AppTheme.ink.opacity(0.10), lineWidth: 2)
                .frame(height: peekHeight)
                .padding(.bottom, 10)

            VeloraCharacterView(
                expression: .gentle,
                size: characterSize,
                gaze: .center,
                eyeState: justSucceeded ? .happy : .open,
                motionStyle: .lively,
                mouthMode: .curve,
                lookAtText: true,
                lockOnAnimation: true,
                blushBoost: justSucceeded ? 1.0 : 0.0
            )
            .offset(y: characterOffsetY)
            .mask(PeekMaskShape(yFactor: 0.68).fill(Color.black))
            .allowsHitTesting(false)
        }
        .frame(height: peekHeight)
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Data
    private var currentStep: String {
        guard !topic.easyOnsetSteps.isEmpty else { return "…" }
        let safe = Swift.min(Swift.max(index, 0), topic.easyOnsetSteps.count - 1)
        return topic.easyOnsetSteps[safe]
    }

    private var sanitizedStep: String {
        currentStep
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{2007}", with: " ")
            .replacingOccurrences(of: "\u{2009}", with: " ")
            .replacingOccurrences(of: "\u{200A}", with: " ")
            .replacingOccurrences(of: "\u{2060}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
    }

    private var isLast: Bool {
        guard !topic.easyOnsetSteps.isEmpty else { return true }
        return index >= topic.easyOnsetSteps.count - 1
    }

    private func tutorialDuration(for text: String) -> Double {
        let c = Swift.max(8, text.count)
        let base = 2.4
        let extra = Swift.min(1.9, Double(c) * 0.018)
        return base + extra
    }

    // MARK: - Status
    private var statusLine: String {
        if isFrozen { return "Paused." }
        if isTutorialPlaying { return "Watch once… then try." }

        if mode.isDemo {
            if demoInFlight { return "Previewing…" }
            if isListening { return "Preview running…" }
            return "Tap the mic to preview."
        }

        if transcriber.isAuthorized == false { return "Permissions not granted." }
        if transcriber.supportsOnDevice == false { return "On-device speech isn’t available." }
        if isListening { return "Listening…" }
        return "Tap the mic to speak."
    }

    // MARK: - Mic
    private var micButton: some View {
        Button {
            Haptics.tap()
            guard isFrozen == false else { return }
            guard isTutorialPlaying == false else { return }
            guard demoInFlight == false else { return }

            if mode.isDemo {
                // ✅ Demo: tap -> brief wait -> auto success
                startDemoAttempt()
                return
            }

            if isListening {
                stopListening(userInitiated: true)
            } else {
                startListening()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(AppTheme.paper.opacity(0.88))
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: [AppTheme.mint, AppTheme.aqua],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                    )
                    .frame(width: 66, height: 66)
                    .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)

                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.ink.opacity(0.72))
            }
            .opacity((isTutorialPlaying || isFrozen) ? 0.40 : 1.0)
            .scaleEffect(isListening ? 1.05 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.80), value: isListening)
        }
        .buttonStyle(.plain)
        .disabled(isTutorialPlaying || isFrozen || demoInFlight)
    }

    private func startListening() {
        justSucceeded = false
        isListening = true
        wasSpeaking = false

        withAnimation(.easeInOut(duration: 0.12)) { feedback = nil }
        guidanceStartToken = UUID()

        transcriber.setExpectedPhrase(sanitizedStep)
        transcriber.configureMatch(ratio: transcriptLCSRatio, minWords: 1)

        transcriber.resetExpectedMatch()
        transcriber.resetOnset()
        transcriber.resetTranscript()
        transcriber.start()
    }

    private func stopListening(userInitiated: Bool) {
        isListening = false
        transcriber.stop()
        if userInitiated { evaluateAtEndOfSpeech() }
    }

    // MARK: - Demo attempt

    private func startDemoAttempt() {
        justSucceeded = false
        isListening = true
        demoInFlight = true

        withAnimation(.easeInOut(duration: 0.12)) { feedback = nil }
        guidanceStartToken = UUID()

        // Give judges immediate “success feedback” vibe
        DispatchQueue.main.asyncAfter(deadline: .now() + demoSuccessDelay) {
            guard self.isFrozen == false else { return }
            guard self.isTutorialPlaying == false else { return }

            // Fake some scoring samples so Feedback doesn't look empty
            self.rmsSamples.append(0.02)
            self.onsetScores.append(88)

            self.setFeedback(.success, "Nice. Smooth start ✅")
            self.demoInFlight = false
            self.triggerSuccess()
        }
    }

    // MARK: - Tutorial
    private func playTutorial() {
        stopListening(userInitiated: false)
        wasSpeaking = false
        guidanceStartToken = UUID()
        demoInFlight = false

        withAnimation(.easeInOut(duration: 0.12)) { feedback = nil }

        if mode.isDemo == false {
            transcriber.resetOnset()
            transcriber.resetExpectedMatch()
            transcriber.setExpectedPhrase(sanitizedStep)
            transcriber.configureMatch(ratio: transcriptLCSRatio, minWords: 1)
        }

        isTutorialPlaying = true
        justSucceeded = false
        tutorialKey = UUID()

        tutorialRemaining = tutorialDuration(for: sanitizedStep)
        lastTutorialTick = Date()
    }

    private func finishTutorial() {
        isTutorialPlaying = false
        tutorialRemaining = 0
        if mode.isDemo == false {
            transcriber.resetTranscript()
            transcriber.resetExpectedMatch()
        }
    }

    // MARK: - Evaluation (normal only)
    private func evaluateAtEndOfSpeech() {
        guard mode.isDemo == false else { return }
        guard isFrozen == false else { return }
        guard isTutorialPlaying == false else { return }
        evaluate()
    }

    private func evaluate() {
        guard mode.isDemo == false else { return }
        guard isFrozen == false else { return }

        onsetScores.append(Swift.max(0, Swift.min(100, transcriber.onsetScore)))

        let expected = expectedWords(from: sanitizedStep)
        let spoken = expectedWords(from: transcriber.transcript)

        guard !expected.isEmpty else { return }

        guard !spoken.isEmpty else {
            setFeedback(.neutral, "I couldn’t catch that.\nTry again, a bit closer to the mic.")
            return
        }

        let transcriptOK = transcriber.didMatchExpectedPhrase || relaxedTranscriptCheck(expected: expected, spoken: spoken)

        let threshold = adaptiveOnsetThreshold(for: expected)
        let verdict = transcriber.onsetVerdict
        let conf = transcriber.onsetConfidence
        let score = transcriber.onsetScore
        let kind = transcriber.onsetKind
        let nonExplosiveAttempt = (kind != .hard)

        let onsetOK: Bool = {
            if verdict == .great || verdict == .good { return true }
            if verdict == .tryAgain && conf >= honestGateConfidence { return false }
            if nonExplosiveAttempt && score >= (threshold - 6) { return true }
            return false
        }()

        if transcriptOK && onsetOK {
            setFeedback(.success, "Nice. Smooth start ✅")
            triggerSuccess()
            return
        }

        if onsetOK && !transcriptOK {
            let heard = previewHeard(spoken)
            setFeedback(.neutral, "Good start.\nI heard “\(heard)”. Try the phrase again.")
            return
        }

        if transcriptOK && !onsetOK {
            setFeedback(.neutral, "Close ✅\nTry a softer start—air first, then voice.")
            triggerOnsetRetry()
            return
        }

        let heard = previewHeard(spoken)
        setFeedback(.neutral, "Try again.\nI heard “\(heard)”.")
    }

    private func relaxedTranscriptCheck(expected: [String], spoken: [String]) -> Bool {
        if expected.isEmpty || spoken.isEmpty { return false }
        var i = 0
        var j = 0
        var matched = 0
        while i < expected.count && j < spoken.count {
            if expected[i] == spoken[j] {
                matched += 1
                i += 1
                j += 1
            } else {
                j += 1
            }
        }
        let required = max(1, Int(ceil(Float(expected.count) * transcriptLCSRatio)))
        return matched >= required
    }

    // MARK: - Less strict threshold
    private func adaptiveOnsetThreshold(for expectedWords: [String]) -> Int {
        var t = 50

        let phrase = expectedWords.joined(separator: " ")
        let totalChars = phrase.count
        let wordCount = expectedWords.count
        let first = expectedWords.first ?? ""

        if wordCount <= 1 && totalChars <= 4 { t -= 12 }
        else if wordCount <= 2 && totalChars <= 10 { t -= 9 }

        if wordCount >= 4 || totalChars >= 18 { t -= 5 }
        if startsWithPlosive(first) { t -= 10 }
        if startsWithVowel(first) { t += 2 }

        return Swift.max(36, Swift.min(66, t))
    }

    private func startsWithPlosive(_ word: String) -> Bool {
        guard let c = word.lowercased().first else { return false }
        return ["p","t","k","b","d","g"].contains(c)
    }

    private func startsWithVowel(_ word: String) -> Bool {
        guard let c = word.lowercased().first else { return false }
        return ["a","e","i","o","u"].contains(c)
    }

    // MARK: - Feedback helpers
    private func setFeedback(_ style: FeedbackToastModel.Style, _ text: String) {
        withAnimation(.easeInOut(duration: 0.14)) {
            feedback = FeedbackToastModel(style: style, text: text)
        }
    }

    private func previewHeard(_ spoken: [String]) -> String {
        let firstFew = spoken.prefix(4).joined(separator: " ")
        return firstFew.isEmpty ? "…" : firstFew
    }

    // MARK: - Retry / success
    private func triggerOnsetRetry() {
        guard mode.isDemo == false else { return }
        guard isFrozen == false else { return }
        Haptics.tap()
        stopListening(userInitiated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard self.isFrozen == false else { return }
            self.transcriber.resetTranscript()
            self.transcriber.resetOnset()
            self.transcriber.resetExpectedMatch()
            self.wasSpeaking = false
            self.guidanceStartToken = UUID()
        }
    }

    private func triggerSuccess() {
        guard isFrozen == false else { return }
        stopListening(userInitiated: false)
        Haptics.success()

        withAnimation(.easeInOut(duration: 0.18)) { justSucceeded = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            guard self.isFrozen == false else { return }
            withAnimation(.easeInOut(duration: 0.18)) { self.justSucceeded = false }

            if self.isLast {
                self.onMetrics?(EasyOnsetMetrics(rmsSamples: self.rmsSamples, onsetScores: self.onsetScores))
                self.onComplete()
            } else {
                self.index += 1
            }
        }
    }

    // MARK: - Word normalization
    private func expectedWords(from input: String) -> [String] {
        let lower = input.lowercased()
        let cleaned = lower
            .replacingOccurrences(of: "[^a-z\\s']", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty { return [] }
        return cleaned.split(separator: " ").map { String($0) }
    }
}

// MARK: - Feedback Toast (ONE message)

private struct FeedbackToastModel: Equatable {
    enum Style: Equatable { case success, neutral }
    let style: Style
    let text: String
}

private struct FeedbackToast: View {
    let model: FeedbackToastModel

    var body: some View {
        Text(model.text)
            .font(.system(size: 12.5, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.ink.opacity(model.style == .success ? 0.90 : 0.70))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.paper.opacity(model.style == .success ? 0.80 : 0.72))
            )
    }
}

// MARK: - Peek shapes (preserved)

private struct PeekMaskShape: Shape {
    let yFactor: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.height * yFactor
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: y))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: y),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

private struct PeekArcLine: Shape {
    let yFactor: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.height * yFactor
        p.move(to: CGPoint(x: rect.minX, y: y))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: y),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return p
    }
}

// MARK: - Preview

struct EasyOnsetView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            EasyOnsetView(
                topic: TopicLibrary.all.first!,
                mode: .demoPreview,
                onComplete: {},
                onMetrics: nil,
                isTechniqueIntroPresented: false,
                requestTechniqueIntro: { _ in }
            )
        }
        .preferredColorScheme(.light)
    }
}
