//
//  BreathingExampleView.swift
//  Velora
//
//  Minimal realistic breathing example (tiny, calm, centered).
//  - No ring, no progress bar, no hold
//  - Velora centered
//  - Only "In" / "Out" under the character (small, not bold)
//  - Slow exhale (Out) then slow inhale (In)
//  - Runs for 20 loops max, then shows Repeat (CPU friendly).
//
//  Created by Velora on 27/02/2026.
//  Updated by Velora on 27/02/2026.
//

import SwiftUI
import Combine

struct BreathingExampleView: View {

    // Very calm loop (Out -> In)
    private let outDuration: TimeInterval = 3.8
    private let inDuration: TimeInterval = 3.2
    private var cycleTotal: TimeInterval { outDuration + inDuration }

    private let maxLoops: Int = 20

    private enum Phase: Equatable {
        case out
        case `in`

        var label: String {
            switch self {
            case .out: return "Out"
            case .in:  return "In"
            }
        }
    }

    @State private var t0: Date = Date()
    @State private var phase: Phase = .out
    @State private var p: Double = 0 // 0...1 within current phase

    // ✅ loop limiting
    @State private var lastLoopIndex: Int = 0
    @State private var showRepeat: Bool = false
    @State private var didFinishLoops: Bool = false

    private let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.paper.opacity(0.60))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.ink.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 8) {

                VeloraCharacterView(
                    expression: .gentle,
                    size: 52,
                    gaze: .center,
                    eyeState: .closed,
                    motionStyle: .staticCalm,
                    mouthMode: phase == .out ? .dot : .curve,
                    // ✅ softer smaller face
                    featureScale: 0.70,
                    lineWidthScale: 0.72
                )
                .scaleEffect(breathScale(phase: phase, p: p))
                .animation(.easeInOut(duration: 0.22), value: phase)
                .animation(.linear(duration: 1.0 / 30.0), value: p)
                .shadow(color: AppTheme.shadow.opacity(0.30), radius: 8, x: 0, y: 6)

                Text(phase.label)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(AppTheme.ink.opacity(0.55))

                if showRepeat {
                    Button {
                        Haptics.tap()
                        restart()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .bold))
                            Text("Repeat")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(AppTheme.ink.opacity(0.70))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.paper.opacity(0.75))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.ink.opacity(0.10), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 10)
        }
        .frame(height: 108) // ✅ أطول شوي عشان زر Repeat يكون مريح
        .onAppear { restart() }
        .onReceive(ticker) { now in
            guard didFinishLoops == false else { return }

            let e = now.timeIntervalSince(t0)
            let safeCycle = max(0.001, cycleTotal)

            // ✅ count completed loops
            let loopIndex = Int(floor(e / safeCycle))
            if loopIndex != lastLoopIndex {
                lastLoopIndex = loopIndex

                if loopIndex >= maxLoops {
                    // stop at the end of 20 loops (freeze calmly)
                    didFinishLoops = true
                    withAnimation(.easeInOut(duration: 0.20)) {
                        showRepeat = true
                    }
                    // Freeze to a calm state (start of Out)
                    phase = .out
                    p = 0
                    return
                }
            }

            let local = e.truncatingRemainder(dividingBy: safeCycle)
            updatePhase(local: local)
        }
        .accessibilityLabel(Text("Breathing example"))
    }

    private func restart() {
        t0 = Date()
        lastLoopIndex = 0
        didFinishLoops = false
        withAnimation(.easeInOut(duration: 0.16)) {
            showRepeat = false
        }
        phase = .out
        p = 0
    }

    private func updatePhase(local: TimeInterval) {
        if local < outDuration {
            phase = .out
            p = max(0, min(1, local / max(0.001, outDuration)))
        } else {
            phase = .in
            let t = local - outDuration
            p = max(0, min(1, t / max(0.001, inDuration)))
        }
    }

    /// Out = gentle shrink, In = gentle expand (slow)
    private func breathScale(phase: Phase, p: Double) -> CGFloat {
        let big: CGFloat = 1.18
        let small: CGFloat = 0.90
        let t = CGFloat(smoothstep(p))

        switch phase {
        case .out:
            return big + (small - big) * t
        case .in:
            return small + (big - small) * t
        }
    }

    private func smoothstep(_ t: Double) -> Double {
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }
}

// MARK: - Preview

struct BreathingExampleView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Breathing Example (Minimal)")
                    .font(AppTheme.titleFont)

                // ✅ Preview shows just the example
                BreathingExampleView()
                    .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(.light)
    }
}
