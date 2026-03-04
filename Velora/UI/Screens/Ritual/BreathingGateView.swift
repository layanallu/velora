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
//     This prevents the overlay from being re-built 30fps,
//     which was resetting BreathingExampleView (making it look stuck).
//  ✅ Added stable overlay identity via .id("techniqueIntro").
//

import SwiftUI
import Combine

struct BreathingGateView: View {
    let topic: Topic
    var mode: SessionMode = .normal

    // MARK: - Timing
    private let totalDuration: TimeInterval = 60
    private let inhaleDuration: TimeInterval = 4
    private let holdInDuration: TimeInterval = 2
    private let exhaleDuration: TimeInterval = 7
    private let holdOutDuration: TimeInterval = 2

    private var cycleTotal: TimeInterval {
        inhaleDuration + holdInDuration + exhaleDuration + holdOutDuration
    }

    private let totalCycles: Int = 4

    // MARK: - Target Scales
    private let bigScale: CGFloat = 1.26
    private let smallScale: CGFloat = 0.94

    // MARK: - State
    @State private var startDate: Date? = nil
    @State private var didFinish: Bool = false
    @State private var crossfade: Double = 0

    private let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    @State private var now: Date = Date()

    // MARK: - Technique Intro Overlay (Freeze System)
    @State private var showTechniqueIntro: Bool = false
    @State private var isFrozen: Bool = false
    @State private var frozenElapsed: TimeInterval = 0

    var body: some View {
        ZStack {
            // ✅ BACKGROUND ONLY (this is what freezes)
            backgroundStack
                .allowsHitTesting(!showTechniqueIntro)
                .transaction { tx in
                    // Kill implicit animations ONLY for background
                    tx.animation = nil
                }

            // ✅ CARD OVERLAY (must stay alive)
            if showTechniqueIntro {
                TechniqueIntroOverlay(
                    technique: .breathing,
                    onDismiss: { dismissTechniqueIntro() }
                )
                // ✅ Stable identity so SwiftUI doesn't treat it as a fresh view every tick
                .id("techniqueIntro")
                .transition(.opacity)
                .zIndex(999)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)

        // ✅ CRITICAL: Back arrow MUST disappear while card is open
        .navigationBarBackButtonHidden(showTechniqueIntro)

        .onAppear {
            if startDate == nil {
                startDate = Date()
                now = Date()
                didFinish = false
                crossfade = 0
            }

            if !TechniqueIntroStore.hasSeen(.breathing) {
                presentTechniqueIntro(markSeen: true)
            }
        }
        .onReceive(ticker) { tick in
            // ✅ IMPORTANT:
            // If frozen, do NOT touch `now`.
            // Updating it forces a full re-render at 30fps, which can reset the overlay content.
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

    // MARK: - Background Stack

    private var backgroundStack: some View {
        ZStack {
            // ✅ Don't render ScenarioStartView until visible (prevents hidden repeatForever)
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
        let elapsed = elapsedSeconds(now: now)
        let cycle = cycleState(at: elapsed)
        let phase = cycle.phase
        let phaseProgress = cycle.phaseProgress

        let ringProgress = activityRingProgress(phase: phase, phaseProgress: phaseProgress)
        let completedCycles = completedCycleCount(elapsed: elapsed)

        let cycleIndex = currentCycleIndex(elapsed: elapsed) // 0...3
        let isFinalHoldOut = (cycleIndex == totalCycles - 1) && (phase == .holdOut)

        let finalHoldProgress = isFinalHoldOut ? phaseProgress : 0
        let displayExpression: BubbleExpression = finalHoldProgress > 0.55 ? .smile : .gentle
        let displayEyeState: EyeState = finalHoldProgress > 0.65 ? .open : .closed

        let resolvedExpression: BubbleExpression = isFinalHoldOut ? displayExpression : .gentle
        let resolvedEyeState: EyeState = isFinalHoldOut ? displayEyeState : phase.eyeState

        return ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                // ✅ Raised + centered header (title + i next to it)
                header
                    .padding(.top, -8)          // higher
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

    private var header: some View {
        VStack(spacing: 6) {

            // ✅ Center the "Breathing + i" as ONE centered unit
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

        withAnimation(.easeInOut(duration: 0.18)) {
            showTechniqueIntro = true
        }
    }

    private func dismissTechniqueIntro() {
        withAnimation(.easeInOut(duration: 0.18)) {
            showTechniqueIntro = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            startDate = Date().addingTimeInterval(-frozenElapsed)
            isFrozen = false
        }
    }

    // MARK: - Scale Logic

    private func characterScale(for phase: BreathPhase,
                                phaseProgress: Double,
                                isFinalHoldOut: Bool) -> CGFloat {
        let p = max(0, min(1, phaseProgress))

        switch phase {
        case .inhale:
            return lerp(from: 1.08, to: bigScale, t: p)
        case .holdIn:
            return bigScale
        case .exhale:
            return lerp(from: bigScale, to: smallScale, t: p)
        case .holdOut:
            if isFinalHoldOut {
                return lerp(from: smallScale, to: bigScale, t: smoothstep(p))
            } else {
                return smallScale
            }
        }
    }

    private func lerp(from: CGFloat, to: CGFloat, t: Double) -> CGFloat {
        let clamped = max(0, min(1, t))
        return from + (to - from) * CGFloat(clamped)
    }

    private func smoothstep(_ t: Double) -> Double {
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }

    // MARK: - Time helpers

    private func elapsedSeconds(now: Date) -> TimeInterval {
        if isFrozen { return min(totalDuration, max(0, frozenElapsed)) }
        guard let startDate else { return 0 }
        return min(totalDuration, max(0, now.timeIntervalSince(startDate)))
    }

    private func completedCycleCount(elapsed: TimeInterval) -> Int {
        guard cycleTotal > 0 else { return 0 }
        let raw = Int(floor(elapsed / cycleTotal))
        return max(0, min(totalCycles, raw))
    }

    private func currentCycleIndex(elapsed: TimeInterval) -> Int {
        guard cycleTotal > 0 else { return 0 }
        let idx = Int(floor(elapsed / cycleTotal))
        return max(0, min(totalCycles - 1, idx))
    }

    // MARK: - Ring progress

    private func activityRingProgress(phase: BreathPhase, phaseProgress: Double) -> Double {
        let p = max(0, min(1, phaseProgress))
        switch phase {
        case .exhale:  return p
        case .holdOut: return 1.0
        case .inhale:  return 1.0 - p
        case .holdIn:  return 0.0
        }
    }

    // MARK: - Phase state

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
            phase = .inhale; start = 0; end = a1
        } else if local < a2 {
            phase = .holdIn; start = a1; end = a2
        } else if local < a3 {
            phase = .exhale; start = a2; end = a3
        } else {
            phase = .holdOut; start = a3; end = a4
        }

        let denom = max(0.001, end - start)
        let phaseProgress = max(0, min(1, (local - start) / denom))
        return CycleState(phase: phase, phaseProgress: phaseProgress)
    }
}

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
