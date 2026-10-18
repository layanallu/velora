//
//  BreathingGateView.swift
//  Velora
//
//  Step 4: Breathing Gate (60s Entry Ritual)
//  - No skip initially
//  - Start button enabled after completion
//  - Guided technique: Inhale 4s • Hold 2s • Exhale 6s • Hold 2s (repeat)
//
//  Created by LAYAN on 03/09/1447 AH.
//  Updated by Velora: Headspace-like guided breathing visuals (brand-safe).
//
//  Updated by Velora on 27/02/2026:
//  ✅ Background freezes when technique card opens.
//  ✅ Back arrow is HIDDEN while card is open.
//  ✅ Title + (i) centered as one unit, aligned higher.
//  ✅ Subtitle centered under title.
//
//  Updated by Velora on 28/02/2026:
//  ✅ FIX: When frozen, do NOT update `now` every tick.
//  ✅ Added stable overlay identity via .id("techniqueIntro").
//
//  Updated: Demo mode support
//  ✅ Demo mode runs only 2 breathing cycles instead of 4.
//     Normal mode is completely unaffected.
//

import SwiftUI
import Combine

struct BreathingGateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    let topic: Topic
    var mode: SessionMode = .normal

    // MARK: - Timing
    private let inhaleDuration: TimeInterval  = 4
    private let holdInDuration: TimeInterval  = 2
    private let exhaleDuration: TimeInterval  = 7
    private let holdOutDuration: TimeInterval = 2

    private var cycleTotal: TimeInterval {
        inhaleDuration + holdInDuration + exhaleDuration + holdOutDuration
    }

    // ✅ Demo = 2 cycles, Normal = 4 cycles
    private var totalCycles: Int {
        mode.isDemo ? 1 : 4
    }

    // Total session duration derived from cycle count (keeps everything consistent)
    private var totalDuration: TimeInterval {
        cycleTotal * Double(totalCycles)
    }

    // MARK: - Target Scales
    private let bigScale: CGFloat   = 1.26
    private let smallScale: CGFloat = 0.94

    // MARK: - State
    @State private var startDate: Date?       = nil
    @State private var didFinish: Bool        = false
    @State private var crossfade: Double      = 0

    private let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    @State private var now: Date = Date()

    // MARK: - Technique Intro Overlay (Freeze System)
    @State private var showTechniqueIntro: Bool  = false
    @State private var isFrozen: Bool            = false
    @State private var frozenElapsed: TimeInterval = 0

    // An optional exit is different from skipping the breathing ritual.
    // The confirmation overlay pauses the timer so deciding never costs practice time.
    @State private var showExitConfirmation: Bool = false
    @State private var isBackgroundPaused: Bool = false

    var body: some View {
        ZStack {
            backgroundStack
                .allowsHitTesting(!showTechniqueIntro && !showExitConfirmation)
                .transaction { tx in tx.animation = nil }

            // A subtle exit stays in one place throughout Breathing -> Ready.
            // Keep it separate from the timeline so the timeline remains centered.
            if !showTechniqueIntro {
                VStack {
                    HStack {
                        Spacer()
                        exitButton
                    }
                    Spacer()
                }
                // Align with the Rhythm *node row*. The button floats over the
                // header rather than joining the HStack, so connector widths,
                // node centering, and label alignment are never displaced.
                .padding(.top, 2)
                .padding(.trailing, 3)
            }

            if showTechniqueIntro {
                TechniqueIntroOverlay(
                    technique: .breathing,
                    onDismiss: { dismissTechniqueIntro() }
                )
                .id("techniqueIntro")
                .transition(.opacity)
                .zIndex(999)
            }

        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // The native navigation bar placed an arrow and title above the timeline.
        // A controlled exit replaces that arrow without changing the session flow.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        // Present ABOVE this screen, sized by the viewport, not as an iOS
        // floating sheet. This also covers the Ready crossfade state.
        .overlay {
            if showExitConfirmation {
                SessionExitConfirmationOverlay(
                    title: crossfade > 0.98 ? "Leave before starting?" : "Leave for now?",
                    message: crossfade > 0.98
                        ? "You can start a new session whenever you feel ready."
                        : "Your breathing progress will restart next time.",
                    onKeepPracticing: resumeAfterExitCancelled,
                    onLeave: leaveSession
                )
                .zIndex(1000)
            }
        }
        .onAppear {
            if startDate == nil {
                startDate = Date()
                now       = Date()
                didFinish = false
                crossfade = 0
            }

            if !TechniqueIntroStore.hasSeen(.breathing) {
                presentTechniqueIntro(markSeen: true)
            }
        }
        .task {
            // Storage maintenance is not part of the app startup path.
            // Do it at the start of a real session while the user is breathing.
            // The serialized URL factory ensures cleanup finishes before any
            // Rhythm recording is created, even if preparation is still running.
            if !mode.isDemo {
                AudioRecorder.prepareStorageInBackground()
            }
        }

        .onChange(of: scenePhase) { phase in
            handleScenePhaseChange(phase)
        }
        .onReceive(ticker) { tick in
            guard !isFrozen else { return }

            now = tick
            guard crossfade < 0.999 else { return }

            let e = elapsedSeconds(now: tick)
            if !didFinish && e >= totalDuration {
                didFinish = true
                Haptics.success()
                withAnimation(.easeInOut(duration: 1.20)) { crossfade = 1 }
            }
        }
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            guard isBackgroundPaused else { return }
            isBackgroundPaused = false
            guard !showTechniqueIntro && !showExitConfirmation else { return }
            startDate = Date().addingTimeInterval(-frozenElapsed)
            now = Date()
            isFrozen = false
        case .inactive, .background:
            guard !didFinish else { return }
            guard !isBackgroundPaused else { return }
            frozenElapsed = elapsedSeconds(now: now)
            isFrozen = true
            isBackgroundPaused = true
        @unknown default:
            break
        }
    }

    // MARK: - Exit without accidentally skipping breathing

    private var exitButton: some View {
        SessionExitButton(action: presentExitConfirmation, disabled: showExitConfirmation)
    }

    private func presentExitConfirmation() {
        guard !showTechniqueIntro && !showExitConfirmation else { return }
        Haptics.tap()
        frozenElapsed = elapsedSeconds(now: now)
        isFrozen = true
        withAnimation(.spring(response: 0.32, dampingFraction: 0.90)) {
            showExitConfirmation = true
        }
    }

    private func leaveSession() {
        Haptics.tap()
        showExitConfirmation = false
        dismiss()
    }

    private func resumeAfterExitCancelled() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.92)) {
            showExitConfirmation = false
        }
        // A swipe down means Keep Practicing; never skip the breathing gate.
        // If the app is still in the background, keep the timer frozen until
        // scenePhase returns to active.
        guard scenePhase == .active else {
            isBackgroundPaused = true
            return
        }
        startDate = Date().addingTimeInterval(-frozenElapsed)
        now = Date()
        isFrozen = false
        isBackgroundPaused = false
    }

    // MARK: - Background Stack

    private var backgroundStack: some View {
        ZStack {
            if crossfade > 0.001 {
                ScenarioStartView(topic: topic, mode: mode)
                    .opacity(crossfade)
                    .blur(radius: (1 - crossfade) * 5)
                    .allowsHitTesting(crossfade > 0.98)
            }

            breathingLayer
                .opacity(1 - crossfade)
                .blur(radius: crossfade * 5)
                .allowsHitTesting(crossfade < 0.02)
        }
    }

    // MARK: - Breathing UI

    private var breathingLayer: some View {
        let elapsed       = elapsedSeconds(now: now)
        let cycle         = cycleState(at: elapsed)
        let phase         = cycle.phase
        let phaseProgress = cycle.phaseProgress

        let ringProgress     = activityRingProgress(phase: phase, phaseProgress: phaseProgress)
        let completedCycles  = completedCycleCount(elapsed: elapsed)
        let cycleIndex       = currentCycleIndex(elapsed: elapsed)
        let isFinalHoldOut   = (cycleIndex == totalCycles - 1) && (phase == .holdOut)

        let finalHoldProgress  = isFinalHoldOut ? phaseProgress : 0
        let displayExpression: BubbleExpression = finalHoldProgress > 0.55 ? .smile : .gentle
        let displayEyeState: EyeState           = finalHoldProgress > 0.65 ? .open  : .closed

        let resolvedExpression: BubbleExpression = isFinalHoldOut ? displayExpression : .gentle
        let resolvedEyeState: EyeState           = isFinalHoldOut ? displayEyeState   : phase.eyeState

        return ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Carry the existing session timeline into the breathing ritual.
                // This is navigation context only; it never controls the timer.
                ProgressTimelineView(steps: breathingTimelineSteps, nodeSize: 33)

                header
                    .padding(.top, -8)
                    .padding(.bottom, 10)
                    .padding(.horizontal, 18)

                Spacer(minLength: 4)

                BreathingRing(progress: ringProgress)
                    .overlay {
                        VeloraCharacterView(
                            expression: resolvedExpression,
                            size: 182,
                            gaze: .center,
                            eyeState: resolvedEyeState,
                            motionStyle: .staticCalm,
                            mouthMode: phase.mouthMode
                        )
                        .scaleEffect(
                            characterScale(
                                for: phase,
                                phaseProgress: phaseProgress,
                                isFinalHoldOut: isFinalHoldOut
                            )
                        )
                        .animation(.easeInOut(duration: phase.animationDuration), value: phase)
                        .animation(.easeInOut(duration: phase.animationDuration), value: phaseProgress)
                        .animation(.easeInOut(duration: 0.35), value: resolvedExpression)
                        .animation(.easeInOut(duration: 0.35), value: resolvedEyeState)
                    }
                    .padding(.top, 6)

                Spacer().frame(height: 22)

                Text(phase.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)

                Spacer().frame(height: 22)

                CycleDots(completed: completedCycles, total: totalCycles)

                Spacer()
            }
        }
    }

    // MARK: - Journey Timeline

    private var breathingTimelineSteps: [ProgressTimelineView.Step] {
        [
            .init(title: "Breathing", state: .current, kind: .breathing),
            .init(title: "Easy Onset", state: .upcoming, kind: .easyOnset),
            .init(title: "Rhythm", state: .upcoming, kind: .rhythm)
        ]
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Text("Breathing")
                        .font(AppTheme.titleFont)
                        .foregroundStyle(AppTheme.ink)

                    Button {
                        Haptics.tap()
                        presentTechniqueIntro(markSeen: false)
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.ink.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Breathing info"))
                }

                Spacer(minLength: 0)
            }

            Text(topic.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.ink.opacity(0.50))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Freeze / Overlay Controls

    private func presentTechniqueIntro(markSeen: Bool) {
        frozenElapsed = elapsedSeconds(now: now)
        isFrozen = true
        if markSeen { TechniqueIntroStore.markSeen(.breathing) }
        withAnimation(.easeInOut(duration: 0.18)) { showTechniqueIntro = true }
    }

    private func dismissTechniqueIntro() {
        withAnimation(.easeInOut(duration: 0.18)) { showTechniqueIntro = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            // If Exit was tapped during the overlay fade, keep the clock paused.
            guard !showExitConfirmation else { return }
            startDate = Date().addingTimeInterval(-frozenElapsed)
            isFrozen  = false
            isBackgroundPaused = false
        }
    }

    // MARK: - Scale Logic

    private func characterScale(
        for phase: BreathPhase,
        phaseProgress: Double,
        isFinalHoldOut: Bool
    ) -> CGFloat {
        let p = max(0, min(1, phaseProgress))
        switch phase {
        case .inhale:  return lerp(from: 1.08, to: bigScale, t: p)
        case .holdIn:  return bigScale
        case .exhale:  return lerp(from: bigScale, to: smallScale, t: p)
        case .holdOut:
            return isFinalHoldOut
                ? lerp(from: smallScale, to: bigScale, t: smoothstep(p))
                : smallScale
        }
    }

    private func lerp(from: CGFloat, to: CGFloat, t: Double) -> CGFloat {
        from + (to - from) * CGFloat(max(0, min(1, t)))
    }

    private func smoothstep(_ t: Double) -> Double {
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }

    // MARK: - Time Helpers

    private func elapsedSeconds(now: Date) -> TimeInterval {
        if isFrozen { return min(totalDuration, max(0, frozenElapsed)) }
        guard let startDate else { return 0 }
        return min(totalDuration, max(0, now.timeIntervalSince(startDate)))
    }

    private func completedCycleCount(elapsed: TimeInterval) -> Int {
        guard cycleTotal > 0 else { return 0 }
        return max(0, min(totalCycles, Int(floor(elapsed / cycleTotal))))
    }

    private func currentCycleIndex(elapsed: TimeInterval) -> Int {
        guard cycleTotal > 0 else { return 0 }
        return max(0, min(totalCycles - 1, Int(floor(elapsed / cycleTotal))))
    }

    // MARK: - Ring Progress

    private func activityRingProgress(phase: BreathPhase, phaseProgress: Double) -> Double {
        let p = max(0, min(1, phaseProgress))
        switch phase {
        case .exhale:  return p
        case .holdOut: return 1.0
        case .inhale:  return 1.0 - p
        case .holdIn:  return 0.0
        }
    }

    // MARK: - Phase State

    private func cycleState(at elapsed: TimeInterval) -> CycleState {
        let total = cycleTotal
        if total <= 0 { return CycleState(phase: .inhale, phaseProgress: 0) }

        let local = elapsed.truncatingRemainder(dividingBy: total)
        let a1 = inhaleDuration
        let a2 = inhaleDuration + holdInDuration
        let a3 = inhaleDuration + holdInDuration + exhaleDuration
        let a4 = total

        let phase: BreathPhase
        let start: TimeInterval
        let end: TimeInterval

        if local < a1 {
            phase = .inhale;  start = 0;  end = a1
        } else if local < a2 {
            phase = .holdIn;  start = a1; end = a2
        } else if local < a3 {
            phase = .exhale;  start = a2; end = a3
        } else {
            phase = .holdOut; start = a3; end = a4
        }

        let denom = max(0.001, end - start)
        let progress = max(0, min(1, (local - start) / denom))
        return CycleState(phase: phase, phaseProgress: progress)
    }
}

// MARK: - Supporting Types

private struct CycleState {
    let phase: BreathPhase
    let phaseProgress: Double
}

private enum BreathPhase: Equatable {
    case inhale, holdIn, exhale, holdOut

    var title: String {
        switch self {
        case .inhale:  return "Breathe in"
        case .holdIn:  return "Hold"
        case .exhale:  return "Breathe out"
        case .holdOut: return "Hold"
        }
    }

    var eyeState: EyeState { .closed }

    var mouthMode: VeloraMouthMode {
        switch self {
        case .inhale:  return .curve
        case .holdIn:  return .curve
        case .exhale:  return .dot
        case .holdOut: return .curve
        }
    }

    var animationDuration: Double {
        switch self {
        case .inhale:  return 0.40
        case .holdIn:  return 0.22
        case .exhale:  return 0.45
        case .holdOut: return 0.22
        }
    }
}

private struct BreathingRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.ink.opacity(0.06), lineWidth: 22)
                .frame(width: 260, height: 260)

            Circle()
                .fill(AppTheme.paper.opacity(0.75))
                .frame(width: 190, height: 190)
                .shadow(color: .black.opacity(0.02), radius: 10, x: 0, y: 6)

            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.mint.opacity(0.95), AppTheme.aqua.opacity(0.95)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 22, lineCap: .round)
                )
                .frame(width: 260, height: 260)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1.0 / 30.0), value: progress)
        }
    }
}

private struct CycleDots: View {
    let completed: Int
    let total: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<total, id: \.self) { idx in
                Circle()
                    .fill(dotFill(isFilled: idx < completed))
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle()
                            .stroke(AppTheme.ink.opacity(0.08), lineWidth: 1)
                    )
                    .animation(.easeInOut(duration: 0.45), value: completed)
            }
        }
    }

    private func dotFill(isFilled: Bool) -> LinearGradient {
        LinearGradient(
            colors: isFilled
                ? [AppTheme.mint.opacity(0.95), AppTheme.aqua.opacity(0.95)]
                : [AppTheme.ink.opacity(0.14), AppTheme.ink.opacity(0.10)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

