import SwiftUI

// MARK: - Expressions (used across app)

enum BubbleExpression {
    case smile, gentle, neutral, sad, wink, surprised, focused

    var mouthCurve: CGFloat {
        switch self {
        case .smile: return 10
        case .gentle: return 6
        case .neutral: return 0
        case .sad: return -10
        case .wink: return 6
        case .surprised: return 0
        case .focused: return -2
        }
    }

    var dotOpacity: Double {
        switch self {
        case .gentle: return 0.82
        case .focused, .sad: return 0.78
        default: return 0.90
        }
    }

    var eyesYOffset: CGFloat {
        switch self {
        case .smile, .wink: return 0.025
        case .gentle, .neutral: return 0.055
        case .focused: return 0.045
        case .sad: return 0.060
        case .surprised: return 0.040
        }
    }

    var blushOpacity: Double {
        (self == .focused) ? 0.18 : 0.10
    }
}

// MARK: - Eye gaze (dot system)

enum EyeGaze {
    case center, down, up, upStrong, left, right

    var dotOffset: CGSize {
        switch self {
        case .center:   return .zero
        case .down:     return CGSize(width: 0, height: 2.5)
        case .up:       return CGSize(width: 0, height: -2.5)
        case .upStrong: return CGSize(width: 0, height: -4.6)  // ✅ stronger for large characters
        case .left:     return CGSize(width: -2.5, height: 0)
        case .right:    return CGSize(width: 2.5, height: 0)
        }
    }
}

// MARK: - Eye state

enum EyeState: Equatable {
    case open, blink, closed
    case happy // ✅ NEW (٨٨ / m vibe)
}

// MARK: - Motion Style

enum VeloraMotionStyle: Equatable {
    case staticCalm
    case subtle
    case lively
}

// MARK: - Mouth Mode

enum VeloraMouthMode: Equatable {
    case auto
    case dot
    case curve
    case o(openness: Double) // 0...1
}

// MARK: - View

struct VeloraCharacterView: View {
    var expression: BubbleExpression = .gentle
    var size: CGFloat = 120

    var gaze: EyeGaze = .center
    var eyeState: EyeState = .open

    var motionStyle: VeloraMotionStyle = .subtle
    var mouthMode: VeloraMouthMode = .auto

    /// ✅ When true, bias visuals so it feels like Velora is looking up at text.
    var lookAtText: Bool = false

    /// ✅ Subtle on-appear animation that "locks" attention upward.
    var lockOnAnimation: Bool = true

    /// ✅ boost blush (0...1). Use for "success" moments.
    var blushBoost: CGFloat = 0

    /// ✅ NEW: Optional face controls (safe defaults)
    /// - featureScale shrinks facial features (eyes + mouth) without changing body size.
    /// - lineWidthScale makes strokes thinner for a softer look.
    /// Defaults preserve current look everywhere.
    var featureScale: CGFloat = 1.0
    var lineWidthScale: CGFloat = 1.0

    @State private var shinePhase: CGFloat = 0
    @State private var breathePhase: CGFloat = 0

    /// 0 → normal, 1 → focused-up
    @State private var attention: CGFloat = 0

    // MARK: - Auto Blink

    /// Internal copy of `eyeState` so async blink loop can react to updates.
    @State private var observedEyeState: EyeState = .open

    /// When true AND the requested eyeState is `.open`, we temporarily render `.blink`.
    @State private var isAutoBlinking: Bool = false

    /// Keeps the blink loop alive for the lifetime of this view instance.
    @State private var blinkLoopTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            if motionStyle != .staticCalm {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.aqua.opacity(0.55),
                                AppTheme.mint.opacity(0.25),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.85
                        )
                    )
                    .frame(width: size * 1.35, height: size * 1.35)
                    .blur(radius: 18)
                    .opacity(0.9)
            }

            Circle()
                .fill(bodyGradient)
                .overlay(innerHighlight)
                .overlay(shineOverlayIfNeeded)
                .overlay(foreheadGlint)
                .overlay(blushOverlay)
                .overlay(face)
                .frame(width: size, height: size)
                .shadow(
                    color: .black.opacity(motionStyle == .staticCalm ? 0.03 : 0.06),
                    radius: motionStyle == .staticCalm ? 10 : 18,
                    x: 0,
                    y: motionStyle == .staticCalm ? 6 : 10
                )
                .scaleEffect(idleBreathingScale)
        }
        .compositingGroup()
        .onAppear {
            // Keep a live copy of the externally-requested eye state.
            observedEyeState = eyeState
            startBlinkLoopIfNeeded()

            // Visual motion (shine/breathe) can be disabled, but blinking still feels alive.
            guard motionStyle != .staticCalm else { return }

            withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                shinePhase = 1
            }

            // ✅ FIX: subtle MUST animate breathePhase too (slow & calm).
            // Previously: subtle had NO breathe animation, so it looked frozen (especially in overlays).
            startBreathingAnimationForMotionStyle()

            if lookAtText {
                if lockOnAnimation {
                    attention = 0
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        attention = 1
                    }
                } else {
                    attention = 1
                }
            } else {
                attention = 0
            }
        }
        .onChange(of: eyeState) { _, newValue in
            observedEyeState = newValue
            // If caller forces a non-open state, ensure we don't "fight" it.
            if newValue != .open {
                isAutoBlinking = false
            }
        }
        .onChange(of: lookAtText) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    attention = 1
                }
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    attention = 0
                }
            }
        }
        .onChange(of: motionStyle) { _, _ in
            // ✅ If a screen changes motionStyle dynamically, keep breathing correct.
            startBreathingAnimationForMotionStyle()
        }
        .onDisappear {
            stopBlinkLoop()
        }
    }

    // MARK: - Breathing Animation (NEW)

    /// Keeps breathePhase alive for subtle/lively while respecting staticCalm.
    private func startBreathingAnimationForMotionStyle() {
        // Reset phase so animation always starts predictably.
        breathePhase = 0

        switch motionStyle {
        case .staticCalm:
            // No internal breathing. (Screens can still animate via external scaleEffect if they want.)
            return

        case .subtle:
            // Very calm breathing (slow).
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                breathePhase = .pi * 2
            }

        case .lively:
            // Slightly faster, more “alive”.
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                breathePhase = .pi * 2
            }
        }
    }

    // MARK: - Auto Blink Helpers

    /// Starts a lightweight blink loop once per view instance.
    /// - Important: We only blink when the requested eyeState is exactly `.open`.
    private func startBlinkLoopIfNeeded() {
        guard blinkLoopTask == nil else { return }

        blinkLoopTask = Task {
            while !Task.isCancelled {
                // Human-ish blink cadence (random so it doesn't feel robotic).
                let waitSeconds = Double.random(in: 3.2...6.4)
                try? await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000))

                if Task.isCancelled { break }

                // Only blink when the current requested state is `.open`.
                if observedEyeState == .open {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.10)) {
                            isAutoBlinking = true
                        }
                    }

                    // A short eyelid close.
                    try? await Task.sleep(nanoseconds: 140_000_000)

                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            isAutoBlinking = false
                        }
                    }
                }
            }
        }
    }

    private func stopBlinkLoop() {
        blinkLoopTask?.cancel()
        blinkLoopTask = nil
        isAutoBlinking = false
    }

    // MARK: - Body

    private var bodyGradient: LinearGradient {
        LinearGradient(
            colors: [
                AppTheme.mint.opacity(0.96),
                AppTheme.aqua.opacity(0.96),
                AppTheme.paper.opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var innerHighlight: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.70),
                        .white.opacity(0.10),
                        .clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .padding(size * 0.085)
            .opacity(0.8)
    }

    private var shineOverlayIfNeeded: some View {
        Group {
            if motionStyle == .staticCalm {
                EmptyView()
            } else {
                RoundedRectangle(cornerRadius: size * 0.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.0),
                                .white.opacity(0.55),
                                .white.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.22, height: size * 0.90)
                    .rotationEffect(.degrees(18))
                    .offset(x: (-size * 0.35) + (size * 0.70 * shinePhase), y: 0)
                    .blendMode(.screen)
                    .opacity(0.24)
                    .clipShape(Circle())
            }
        }
    }

    private var foreheadGlint: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        .white.opacity(0.55),
                        .white.opacity(0.18),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.26
                )
            )
            .frame(width: size * 0.46, height: size * 0.30)
            .offset(x: 0, y: -size * 0.26)
            .blur(radius: 10)
            .opacity(0.16 + (0.22 * Double(attention)))
            .blendMode(.screen)
    }

    private var blushOverlay: some View {
        let boost = max(0, min(1, blushBoost))
        let baseOpacity = expression.blushOpacity
        let boostedOpacity = min(0.55, baseOpacity + (0.28 * Double(boost)))

        let baseW: CGFloat = size * 0.32
        let baseH: CGFloat = size * 0.18

        let w = baseW * (1.0 + 0.10 * boost)
        let h = baseH * (1.0 + 0.10 * boost)

        return ZStack {
            Circle()
                .fill(Color.pink.opacity(boostedOpacity))
                .frame(width: w, height: h)
                .offset(x: -size * 0.20, y: size * 0.18)

            Circle()
                .fill(Color.pink.opacity(boostedOpacity))
                .frame(width: w, height: h)
                .offset(x: size * 0.20, y: size * 0.18)
        }
        .blur(radius: 6)
        .opacity(0.9)
        .animation(.spring(response: 0.25, dampingFraction: 0.82), value: boost)
    }

    private var idleBreathingScale: CGFloat {
        switch motionStyle {
        case .staticCalm:
            return 1.0
        case .subtle:
            return 1.0 + (sin(breathePhase) * 0.006)
        case .lively:
            return 1.0 + (sin(breathePhase) * 0.015)
        }
    }

    // MARK: - Face

    private var face: some View {
        ZStack {
            eyes.offset(y: eyesLiftedYOffset)
            mouth.offset(y: size * 0.18)
        }
        .accessibilityElement(children: .ignore)
    }

    private var eyesLiftedYOffset: CGFloat {
        let base = size * expression.eyesYOffset
        let lift = -(size * 0.10) * attention
        return base + lift
    }

    private var eyes: some View {
        HStack(spacing: size * 0.18) {
            EyeView(
                side: .left,
                expression: expression,
                eyeState: renderedEyeState,
                gaze: effectiveGaze,
                characterSize: size,
                featureScale: featureScale,
                lineWidthScale: lineWidthScale
            )
            EyeView(
                side: .right,
                expression: expression,
                eyeState: renderedEyeState,
                gaze: effectiveGaze,
                characterSize: size,
                featureScale: featureScale,
                lineWidthScale: lineWidthScale
            )
        }
    }

    private var effectiveGaze: EyeGaze {
        if lookAtText { return .upStrong }
        return gaze
    }

    private var renderedEyeState: EyeState {
        // Auto blink ONLY when the requested state is explicitly `.open`.
        if eyeState == .open {
            return isAutoBlinking ? .blink : .open
        }
        return eyeState
    }

    private var mouth: some View {
        switch mouthMode {
        case .auto:
            return AnyView(curveMouth.opacity(1.0))

        case .curve:
            return AnyView(curveMouth.opacity(1.0))

        case .dot:
            let d = max(5, size * 0.045) * max(0.60, featureScale)
            return AnyView(
                Circle()
                    .fill(AppTheme.ink.opacity(0.85))
                    .frame(width: d, height: d)
                    .animation(.easeInOut(duration: 0.18), value: mouthMode)
            )

        case .o(let opennessRaw):
            let o = max(0, min(1, opennessRaw))
            let lineOpacity = 1.0 - smoothstep(o, edge0: 0.10, edge1: 0.30)
            let circleOpacity = smoothstep(o, edge0: 0.35, edge1: 0.65)

            let lw = 3 * max(0.60, lineWidthScale)
            let s = max(0.60, featureScale)

            return AnyView(
                ZStack {
                    curveMouth.opacity(lineOpacity)

                    Circle()
                        .stroke(AppTheme.ink.opacity(0.85), lineWidth: lw)
                        .frame(width: size * 0.085 * s, height: size * 0.085 * s)
                        .opacity(circleOpacity)
                }
                .animation(.easeInOut(duration: 0.22), value: o)
            )
        }
    }

    private var curveMouth: some View {
        let lw = 3 * max(0.60, lineWidthScale)
        let s = max(0.60, featureScale)

        return MouthShape(curve: expression.mouthCurve)
            .stroke(
                AppTheme.ink.opacity(0.85),
                style: StrokeStyle(lineWidth: lw, lineCap: .round)
            )
            .frame(width: size * 0.26 * s, height: size * 0.16 * s)
    }

    private func smoothstep(_ x: Double, edge0: Double, edge1: Double) -> Double {
        if edge0 == edge1 { return x < edge0 ? 0 : 1 }
        let t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
        return t * t * (3 - 2 * t)
    }
}

// MARK: - EyeView

private struct EyeView: View {
    enum Side { case left, right }

    let side: Side
    let expression: BubbleExpression
    let eyeState: EyeState
    let gaze: EyeGaze
    let characterSize: CGFloat

    let featureScale: CGFloat
    let lineWidthScale: CGFloat

    var body: some View {
        Group {
            switch resolvedEyeStyle {
            case .closedLine:
                Capsule()
                    .fill(AppTheme.ink.opacity(0.85))
                    .frame(width: eyeWidth, height: lineHeight)

            case .dot:
                Circle()
                    .fill(AppTheme.ink.opacity(expression.dotOpacity))
                    .frame(width: dotSize, height: dotSize)
                    .offset(resolvedDotOffset)

            case .softDot:
                Circle()
                    .fill(AppTheme.ink.opacity(0.78))
                    .frame(width: dotSize * 0.92, height: dotSize * 0.92)
                    .offset(resolvedDotOffset)

            case .happyArc:
                EyeHappyArc()
                    .stroke(
                        AppTheme.ink.opacity(0.85),
                        style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round)
                    )
                    .frame(width: arcWidth, height: arcHeight)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: eyeState)
        .animation(.easeInOut(duration: 0.18), value: gaze)
        .animation(.easeInOut(duration: 0.18), value: expression)
    }

    private var fs: CGFloat { max(0.60, featureScale) }
    private var ls: CGFloat { max(0.60, lineWidthScale) }

    private var dotSize: CGFloat { max(10, characterSize * 0.090) * fs }
    private var eyeWidth: CGFloat { max(12, characterSize * 0.16) * fs }
    private var lineHeight: CGFloat { max(3, characterSize * 0.03) * ls }

    private var arcWidth: CGFloat { max(14, characterSize * 0.18) * fs }
    private var arcHeight: CGFloat { max(10, characterSize * 0.10) * fs }
    private var arcLineWidth: CGFloat { max(3, characterSize * 0.035) * ls }

    private var resolvedDotOffset: CGSize {
        let base = gaze.dotOffset
        let damp: CGFloat = (expression == .focused || expression == .sad) ? 0.75 : 1.0
        return CGSize(width: base.width * damp, height: base.height * damp)
    }

    private enum EyeStyle { case dot, softDot, closedLine, happyArc }

    private var resolvedEyeStyle: EyeStyle {
        if eyeState == .happy { return .happyArc }
        if eyeState == .closed { return .closedLine }
        if eyeState == .blink { return .closedLine }
        if expression == .wink && side == .left { return .closedLine }
        if expression == .sad || expression == .focused { return .softDot }
        return .dot
    }
}

// MARK: - Happy Eye Shape

private struct EyeHappyArc: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.midX, y: rect.minY)
        )
        return p
    }
}

// MARK: - Mouth Shape

struct MouthShape: Shape {
    var curve: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let start = CGPoint(x: rect.minX, y: rect.midY)
        let end = CGPoint(x: rect.maxX, y: rect.midY)
        let control = CGPoint(x: rect.midX, y: rect.midY + curve)
        p.move(to: start)
        p.addQuadCurve(to: end, control: control)
        return p
    }
}
