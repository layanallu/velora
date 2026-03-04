//
//  SessionView.swift
//  Velora
//
//  Live Scenario Engine container:
//   - Timeline at top (Breathing done -> Easy Onset -> Rhythm)
//   - Easy Onset -> Rhythm Pacing -> Feedback
//
//  Updated by Velora on 26/02/2026.
//  Updated by Velora on 27/02/2026:
//  ✅ TechniqueIntroOverlay is now presented HERE (covers timeline + full screen)
//  ✅ Child phases receive "isTechniqueIntroPresented" to truly freeze their engines.
//
//  Updated by Velora on 28/02/2026:
//  🎁 Gift points: +15 to Smoothness & Confidence (clamped 0...100).
//
//  ✅ Demo Preview tweak (28/02/2026):
//  - Feedback scores look strong in demo only.
//

import SwiftUI

struct SessionView: View {
    @Environment(\.dismiss) private var dismiss

    /// ✅ Central router injected from RootView.
    @EnvironmentObject private var router: AppRouter

    let topic: Topic
    var mode: SessionMode = .normal

    @State private var phase: ScenarioPhase = .easyOnset
    @State private var completedEasy: Bool = false

    // Metrics captured from phases (global types)
    @State private var easyMetrics: EasyOnsetMetrics = .init(rmsSamples: [], onsetScores: [])
    @State private var rhythmMetrics: RhythmMetrics = .init(rmsSamples: [])

    // Computed scores shown on Feedback
    @State private var smoothnessScore: Int = 70
    @State private var rhythmScore: Int = 70
    @State private var confidenceScore: Int = 70

    // ✅ NEW: merged rhythm recording filename
    @State private var rhythmAudioFilename: String? = nil

    // MARK: - Technique Intro Overlay (GLOBAL)
    @State private var showTechniqueIntro: Bool = false
    @State private var techniqueIntroKind: TechniqueKind = .easyOnset

    // MARK: - Gift Points
    private let giftPoints: Int = 15

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if phase != .feedback {
                    ProgressTimelineView(steps: timelineSteps, nodeSize: 33)
                }

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if showTechniqueIntro {
                TechniqueIntroOverlay(
                    technique: techniqueIntroKind,
                    onDismiss: dismissTechniqueIntro
                )
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {

        case .easyOnset:
            EasyOnsetView(
                topic: topic,
                mode: mode,
                onComplete: {
                    Haptics.success()

                    let easyForScoring = AudioScoring.EasyOnsetMetrics(
                        rmsSamples: easyMetrics.rmsSamples,
                        onsetScores: easyMetrics.onsetScores
                    )

                    let rawSmooth = AudioScoring.smoothnessScoreV1(easy: easyForScoring)

                    // ✅ Demo-only: strong-looking score
                    if mode.isDemo {
                        smoothnessScore = 88
                    } else {
                        smoothnessScore = giftClamped(rawSmooth)
                    }

                    withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) {
                        completedEasy = true
                        phase = .rhythmPacing
                    }
                },
                onMetrics: { metrics in
                    easyMetrics = metrics
                },
                isTechniqueIntroPresented: showTechniqueIntro,
                requestTechniqueIntro: { markSeen in
                    presentTechniqueIntro(.easyOnset, markSeen: markSeen)
                }
            )

        case .rhythmPacing:
            RhythmPacingView(
                topic: topic,
                mode: mode,
                onComplete: {
                    Haptics.success()

                    let rhythmForScoring = AudioScoring.RhythmMetrics(rmsSamples: rhythmMetrics.rmsSamples)

                    // ✅ Demo-only: strong-looking scores
                    if mode.isDemo {
                        rhythmScore = 90
                    } else {
                        rhythmScore = AudioScoring.rhythmScoreV1(rhythm: rhythmForScoring)
                    }

                    let easyForScoring = AudioScoring.EasyOnsetMetrics(
                        rmsSamples: easyMetrics.rmsSamples,
                        onsetScores: easyMetrics.onsetScores
                    )

                    let rawConfidence = AudioScoring.confidenceScoreV1(
                        easy: easyForScoring,
                        rhythm: rhythmForScoring
                    )

                    if mode.isDemo {
                        confidenceScore = 87
                    } else {
                        confidenceScore = giftClamped(rawConfidence)
                    }

                    withAnimation(.spring(response: 0.40, dampingFraction: 0.88)) {
                        phase = .feedback
                    }
                },
                onMetrics: { metrics in
                    rhythmMetrics = metrics
                },
                onAudioFilename: { filename in
                    rhythmAudioFilename = filename
                },
                isTechniqueIntroPresented: showTechniqueIntro,
                requestTechniqueIntro: { markSeen in
                    presentTechniqueIntro(.rhythm, markSeen: markSeen)
                }
            )

        case .feedback:
            FeedbackView(
                record: SessionRecord.make(
                    topicID: topic.id,
                    topicTitle: topic.title,
                    topicCategoryRaw: topic.category.rawValue,
                    smoothness: smoothnessScore,
                    rhythm: rhythmScore,
                    confidence: confidenceScore,
                    suggestion: supportiveSuggestion(),
                    audioFilename: rhythmAudioFilename
                ),
                onRepeat: {
                    Haptics.tap()
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        dismiss()
                    }
                },
                onBackHome: {
                    Haptics.tap()
                    goHomeSafely()
                }
            )
        }
    }

    private func goHomeSafely() {
        showTechniqueIntro = false
        DispatchQueue.main.async {
            router.goHome()
        }
    }

    private func giftClamped(_ raw: Int) -> Int {
        let boosted = raw + giftPoints
        return min(100, max(0, boosted))
    }

    private func presentTechniqueIntro(_ kind: TechniqueKind, markSeen: Bool) {
        techniqueIntroKind = kind
        if markSeen { TechniqueIntroStore.markSeen(kind) }

        withAnimation(.easeInOut(duration: 0.18)) {
            showTechniqueIntro = true
        }
    }

    private func dismissTechniqueIntro() {
        withAnimation(.easeInOut(duration: 0.18)) {
            showTechniqueIntro = false
        }
    }

    private var timelineSteps: [ProgressTimelineView.Step] {
        let breath = ProgressTimelineView.Step(title: "Breathing", state: .done, kind: .breathing)

        let easyState: ProgressTimelineView.StepState = {
            if phase == .easyOnset { return .current }
            return completedEasy ? .done : .upcoming
        }()

        let easy = ProgressTimelineView.Step(title: "Easy Onset", state: easyState, kind: .easyOnset)

        let rhythmState: ProgressTimelineView.StepState = {
            if phase == .rhythmPacing { return .current }
            return (phase == .feedback) ? .done : .upcoming
        }()

        let rhythm = ProgressTimelineView.Step(title: "Rhythm", state: rhythmState, kind: .rhythm)

        return [breath, easy, rhythm]
    }

    private func supportiveSuggestion() -> String {
        let avg = (smoothnessScore + rhythmScore + confidenceScore) / 3
        if avg >= 70 { return "That was calm and steady. Keep that gentle start." }
        if avg >= 45 { return "Nice pacing. Stay with the slow rhythm." }
        return "Take your time. A soft restart is always okay."
    }
}

#Preview {
    let store = PersistenceStore()
    store.hasCompletedOnboarding = true

    let router = AppRouter()

    return NavigationStack {
        SessionView(topic: TopicLibrary.all.first!, mode: .normal)
    }
    .environmentObject(store)
    .environmentObject(router)
    .preferredColorScheme(.light)
}
