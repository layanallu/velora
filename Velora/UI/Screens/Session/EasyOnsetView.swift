
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
    @State private var isStartingMicrophone: Bool = false
    @State private var isScreenActive: Bool = false
    @State private var microphoneToken = UUID()
    @State private var speechRecoveryIssue: SpeechRecognitionIssue? = nil
    @State private var hasSpokenInAttempt: Bool = false
    @State private var justSucceeded: Bool = false

    @State private var guidanceStartToken: UUID = UUID()
    @State private var wasSpeaking: Bool = false

    @State private var feedback: FeedbackToastModel? = nil

    @StateObject private var transcriber = SpeechTranscriber(locale: Locale(identifier: "en_US"))

    // MARK: - Scoring capture (V1)
    // Only accepted steps contribute to the session summary.
    // Keep a separate buffer for the active attempt so an uncertain microphone
    // reading or an unrecognized phrase cannot lower the user's scores.
    @State private var rmsSamples: [Float] = []
    @State private var onsetScores: [Int] = []
    @State private var attemptRMSSamples: [Float] = []

    private let sampleTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private let tutorialTicker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    /// Keep word recognition flexible: Apple Speech may omit or revise a
    /// token. Word matching and gentle-onset quality are separate checks.
    private let transcriptLCSRatio: Float = 0.80

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

                    // Readiness is explicit: preparing is NOT permission to speak.
                    // Once AVAudioEngine has started, the invitation is immediate.
                    Text(statusLine)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(isListening ? 0.78 : 0.55))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)

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
            isScreenActive = true
            // ✅ Demo mode: skip permissions + SR config (still shows full UI)
            if mode.isDemo == false {
                await transcriber.requestPermissions()
                guard isScreenActive else { return }
                transcriber.setExpectedPhrase(sanitizedStep)
                transcriber.configureMatch(ratio: transcriptLCSRatio, minWords: 1)
            }

            rmsSamples = []
            onsetScores = []
            attemptRMSSamples = []

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
            guard !mode.isDemo, isListening, !isFrozen, !isTutorialPlaying else {
                wasSpeaking = speaking
                return
            }

            if speaking && !hasSpokenInAttempt {
                // Start the guided karaoke once, not again after every pause.
                hasSpokenInAttempt = true
                guidanceStartToken = UUID()
            }
            wasSpeaking = speaking
        }
        .onChange(of: transcriber.didMatchExpectedPhrase) { matched in
            guard matched, !mode.isDemo, isScreenActive, isListening,
                  !isFrozen, !isTutorialPlaying else { return }

            // Auto-complete exactly as Velora originally did: the recognized
            // phrase stops the mic and immediately triggers technique feedback.
            // The match is NOT itself a success: evaluate() still checks onset.
            stopListening(userInitiated: false)
            evaluate()
        }
        .onReceive(sampleTimer) { _ in
            // ✅ Demo mode: no RMS sampling from SR
            guard mode.isDemo == false else { return }

            guard isFrozen == false else { return }
            guard isListening else { return }
            attemptRMSSamples.append(transcriber.rawRMS)
        }
        .onChange(of: transcriber.recoveryIssue) { _, issue in
            guard isScreenActive, !mode.isDemo else { return }
            if let issue { speechRecoveryIssue = issue }
        }
        .onChange(of: transcriber.isRecording) { _, recording in
            // Handle failures reported asynchronously by Apple's Speech service.
            if !recording && isListening {
                isListening = false
                hasSpokenInAttempt = false
            }
        }
        .speechRecoveryAlert(issue: $speechRecoveryIssue) {
            guard isScreenActive, !mode.isDemo else { return }
            transcriber.clearRecoveryIssue()
            startListening()
        }
        .onDisappear {
            isScreenActive = false
            speechRecoveryIssue = nil
            microphoneToken = UUID()
            isStartingMicrophone = false
            isListening = false
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
            microphoneToken = UUID()
            isStartingMicrophone = false
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
                    isActive: (isListening && !mode.isDemo && hasSpokenInAttempt && !isFrozen),
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

        if isStartingMicrophone { return "Just a moment… preparing the mic." }
        if let message = transcriber.statusMessage { return message }
        if transcriber.isAuthorized == false { return "Microphone and speech access needed." }
        if transcriber.supportsOnDevice == false {
            return "English speech recognition isn't available offline on this device."
        }
        if isListening {
            if transcriber.isSpeaking { return "I hear you. Keep going!" }
            if hasSpokenInAttempt { return "Take your time. I'm still listening." }
            return "Ready! You can speak now."
        }
        return "Tap the mic to speak."
    }

    // MARK: - Mic
    private var micButton: some View {
        Button {
            Haptics.tap()
            guard isFrozen == false else { return }
            guard isTutorialPlaying == false else { return }
            guard demoInFlight == false else { return }
            guard !isStartingMicrophone, !justSucceeded else { return }

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
                    // Mint is a clear ready-to-speak signal, not an onset score.
                    // Keep setup pale and visibly different from active listening.
                    .fill(isListening ? AppTheme.mint.opacity(0.48) : AppTheme.paper.opacity(0.88))
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: [AppTheme.mint, AppTheme.aqua],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isListening ? 3.5 : 3
                        )
                    )
                    .frame(width: 66, height: 66)
                    .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)

                if isStartingMicrophone {
                    // Clearly not listening yet: never show a live waveform
                    // until the audio engine has successfully started.
                    ProgressView()
                        .tint(AppTheme.ink.opacity(0.65))
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.ink.opacity(0.72))
                }
            }
            .opacity((isTutorialPlaying || isFrozen) ? 0.40 : 1.0)
            .scaleEffect(isListening && transcriber.isSpeaking ? 1.09 : (isListening ? 1.05 : 1.0))
            .animation(.spring(response: 0.28, dampingFraction: 0.80), value: isListening)
            .animation(.easeInOut(duration: 0.16), value: transcriber.isSpeaking)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isStartingMicrophone ? "Preparing microphone, please wait" :
                (isListening ? "Microphone active, speak now" : "Start microphone")
        )
        .accessibilityHint("The microphone stops automatically when Velora recognizes the phrase.")
        .disabled(isTutorialPlaying || isFrozen || demoInFlight || isStartingMicrophone || justSucceeded)
    }

    private func startListening() {
        guard isScreenActive, !isStartingMicrophone, !isFrozen, !isTutorialPlaying else { return }
        isStartingMicrophone = true
        let token = UUID()
        microphoneToken = token

        Task { @MainActor in
            // A first tap must work even if the permission sheet was delayed.
            // No overlapping microphone starts while permission is being shown.
            if !transcriber.isAuthorized { await transcriber.requestPermissions() }

            guard microphoneToken == token else { return }
            defer { isStartingMicrophone = false }
            guard isScreenActive, !isFrozen, !isTutorialPlaying, !isListening else { return }
            guard transcriber.isAuthorized else {
                speechRecoveryIssue = .permissionRequired
                return
            }

            justSucceeded = false
            wasSpeaking = false
            hasSpokenInAttempt = false
            attemptRMSSamples.removeAll(keepingCapacity: true)
            withAnimation(.easeInOut(duration: 0.12)) { feedback = nil }
            guidanceStartToken = UUID()

            transcriber.setExpectedPhrase(sanitizedStep)
            transcriber.configureMatch(ratio: transcriptLCSRatio, minWords: 1)
            transcriber.resetExpectedMatch()
            transcriber.resetOnset()
            transcriber.resetTranscript()

            // No green/waveform UI unless the underlying audio engine started.
            isListening = transcriber.start()
        }
    }

    private func stopListening(userInitiated: Bool) {
        let hadAttempt = isListening
        // The recognizer can finish its phrase before the audio tap's completed
        // onset result has reached @Published state. Commit only real completed
        // evidence before stop invalidates callbacks and releases the mic.
        if hadAttempt && !mode.isDemo {
            transcriber.commitCompletedOnsetForEvaluation()
        }
        isListening = false
        transcriber.stop()
        // Manual stop remains a fallback when Apple's recognizer cannot
        // match the phrase. It is NOT required for ordinary completion.
        if userInitiated && hadAttempt { evaluateAtEndOfSpeech() }
        hasSpokenInAttempt = false
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
            guard self.isScreenActive else { return }
            guard self.isFrozen == false else { return }
            guard self.isTutorialPlaying == false else { return }

            // Fake some scoring samples so Feedback doesn't look empty
            self.rmsSamples.append(0.02)
            self.onsetScores.append(88)

            self.setFeedback(.success, "Lovely! Gentle start.")
            self.demoInFlight = false
            self.triggerSuccess()
        }
    }

    // MARK: - Tutorial
    private func playTutorial() {
        microphoneToken = UUID()
        isStartingMicrophone = false
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

        let expected = SpeechWordMatcher.words(from: sanitizedStep)
        let spoken = SpeechWordMatcher.words(from: transcriber.transcript, expected: expected)

        guard !expected.isEmpty else { return }

        // First decide whether Apple recognized the target phrase. This must
        // come before the onset check: unclear audio should never be described
        // as a correct phrase (or a failed technique) without evidence.
        guard !spoken.isEmpty else {
            setFeedback(.neutral, "I missed that. Try again?")
            return
        }

        let transcriptOK = transcriber.didMatchExpectedPhrase || relaxedTranscriptCheck(expected: expected, spoken: spoken)

        // If the words do not match, show what speech recognition actually
        // returned. Do not make a claim about onset quality in this branch.
        if !transcriptOK {
            setFeedback(.neutral, "I heard “\(previewHeard(spoken))”.\nTry again.")
            return
        }

        // When a short or fast phrase produces no complete onset sample,
        // avoid blaming the microphone OR claiming the user made a mistake.
        // Give a gentle, actionable prompt without changing the pass criteria.
        guard transcriber.onsetVerdict != .notDetected else {
            setFeedback(.neutral, "I heard your words.\nLet's try the start once more.")
            return
        }

        // Only real acoustic evidence can establish a gentle start. The prior
        // score-only fallback could accept .tryAgain, particularly on long
        // sentences. Sentence length must never lower the onset bar.
        let onsetDecision = EasyOnsetAcceptance.classify(
            verdict: transcriber.onsetVerdict,
            kind: transcriber.onsetKind,
            confidence: transcriber.onsetConfidence,
            score: transcriber.onsetScore,
            expectedWords: expected
        )
        let onsetOK = onsetDecision == .accepted
        let score = transcriber.onsetScore

        if onsetOK {
            // A step is scored only after BOTH gates pass: recognized phrase
            // and valid gentle-onset evidence. Retries and missing measurements
            // never leak into Smoothness or Confidence.
            rmsSamples.append(contentsOf: attemptRMSSamples)
            onsetScores.append(Swift.max(0, Swift.min(100, score)))
            attemptRMSSamples.removeAll(keepingCapacity: true)
            setFeedback(.success, "Lovely! Gentle start.")
            triggerSuccess()
        } else {
            switch onsetDecision {
            case .accepted:
                break // handled above
            case .retryGentler:
                setFeedback(.neutral, "Words right! Try a softer start.")
            case .uncertain:
                setFeedback(.neutral, "I heard your words.\nLet's try the start once more.")
            }
            triggerOnsetRetry()
        }
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
        return matched >= expected.count
    }

    // MARK: - Feedback helpers
    private func setFeedback(_ style: FeedbackToastModel.Style, _ text: String) {
        withAnimation(.easeInOut(duration: 0.14)) {
            feedback = FeedbackToastModel(style: style, text: text)
        }
    }

    private func previewHeard(_ spoken: [String]) -> String {
        let firstFew = spoken.prefix(4).joined(separator: " ")
        guard !firstFew.isEmpty else { return "…" }
        return spoken.count > 4 ? firstFew + "…" : firstFew
    }

    // MARK: - Retry / success
    private func triggerOnsetRetry() {
        guard mode.isDemo == false else { return }
        guard isFrozen == false else { return }
        Haptics.tap()
        stopListening(userInitiated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            guard self.isScreenActive, self.isFrozen == false else { return }
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
            guard self.isScreenActive, self.isFrozen == false else { return }
            withAnimation(.easeInOut(duration: 0.18)) { self.justSucceeded = false }

            if self.isLast {
                self.onMetrics?(EasyOnsetMetrics(rmsSamples: self.rmsSamples, onsetScores: self.onsetScores))
                self.onComplete()
            } else {
                self.index += 1
            }
        }
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
            // Feedback may wrap to two lines; both lines stay centered under
            // the microphone rather than inheriting Text's leading alignment.
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            // Let the text determine the toast width. The surrounding VStack
            // constrains long recognized phrases to the available screen width.
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
