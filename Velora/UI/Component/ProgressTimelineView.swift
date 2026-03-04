//
//  ProgressTimelineView.swift
//  Velora
//
//  Top timeline shown ONLY during the live practice engine (SessionView).
//  Timeline steps:
//   1) Breathing (already completed when SessionView appears)
//   2) Easy Onset
//   3) Rhythm
//
//  Design rules:
//  - Light mode only
//  - Brand gradient Mint <-> Aqua
//  - Soft, minimal, no harsh contrast
//
//  Created by Layan on 05/09/1447 AH.
//

//

import SwiftUI

private enum TimelineMouthStyle {
    case neutral
    case smile
    case excited
}

struct ProgressTimelineView: View {

    enum StepState { case done, current, upcoming }
    enum StepKind { case breathing, easyOnset, rhythm }

    struct Step: Identifiable {
        let id = UUID()
        let title: String
        let state: StepState
        let kind: StepKind
    }

    let steps: [Step]

    // MARK: - Tuning (you can tweak fast)

    var nodeSize: CGFloat = 33

    /// ✅ Wider timeline: increase this.
    var connectorWidth: CGFloat = 96

    var showsLabels: Bool = true

    /// Halo closer + smaller
    var haloDiameterExtra: CGFloat = 14

    /// ✅ Smaller = closer to circle (more negative offset)
    var haloOffsetMultiplier: CGFloat = 0.22

    /// Halo arc visibility (almost invisible)
    var arcOpacity: Double = 0.01

    /// Icons smaller
    var haloIconSize: CGFloat = 6.0

    var body: some View {
        VStack(spacing: 10) {

            // Node — connector — node — connector — node
            HStack(spacing: 0) {
                ForEach(steps.indices, id: \.self) { idx in
                    TimelineNodeView(
                        step: steps[idx],
                        size: nodeSize,
                        haloDiameterExtra: haloDiameterExtra,
                        haloOffsetMultiplier: haloOffsetMultiplier,
                        arcOpacity: arcOpacity,
                        haloIconSize: haloIconSize
                    )

                    if idx != steps.count - 1 {
                        Capsule(style: .continuous)
                            .fill(AppTheme.ink.opacity(0.10))
                            .frame(width: connectorWidth, height: 3)
                    }
                }
            }

            if showsLabels {
                HStack(spacing: 0) {
                    ForEach(steps.indices, id: \.self) { idx in

                        Text(steps[idx].title)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(
                                AppTheme.ink.opacity(
                                    steps[idx].state == .upcoming ? 0.28 : 0.62
                                )
                            )
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false) // ✅ يخلي الكلمة كاملة
                            .frame(width: nodeSize, alignment: .center)   // ✅ نفس عرض الدائرة

                        if idx != steps.count - 1 {
                            Spacer()
                                .frame(width: connectorWidth)
                        }
                    }
                }
                .padding(.top, 0)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

// MARK: - Node

private struct TimelineNodeView: View {
    let step: ProgressTimelineView.Step
    let size: CGFloat

    let haloDiameterExtra: CGFloat
    let haloOffsetMultiplier: CGFloat
    let arcOpacity: Double
    let haloIconSize: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(fillStyle)
                .overlay(
                    Circle().stroke(AppTheme.ink.opacity(step.state == .upcoming ? 0.10 : 0.14), lineWidth: 1)
                )
                .overlay(glowOverlay) // ✅ REAL glow layer
                .shadow(color: shadowGlowColor, radius: shadowGlowRadius, x: 0, y: 8)

            face
                .frame(width: size, height: size)
                .clipped()
                .opacity(step.state == .upcoming ? 0.35 : 0.82)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .top) {
            // Halo always for all 3
            halo
                .offset(y: -(size * haloOffsetMultiplier)) // ✅ closer to bubble
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(step.title)
    }

    private var fillStyle: AnyShapeStyle {
        switch step.state {
        case .done:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.mint.opacity(0.95), AppTheme.aqua.opacity(0.95)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .current:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.mint.opacity(0.78), AppTheme.aqua.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .upcoming:
            return AnyShapeStyle(AppTheme.paper.opacity(0.55))
        }
    }

    // MARK: - Glow (REAL, visible)

    private var glowOverlay: some View {
        Group {
            if step.state == .current {
                // Strong glow: two blurred rings for "alive" feel
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [AppTheme.mint.opacity(0.75), AppTheme.aqua.opacity(0.65)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 10
                    )
                    .blur(radius: 10)
                    .opacity(0.70)

                Circle()
                    .stroke(AppTheme.mint.opacity(0.55), lineWidth: 6)
                    .blur(radius: 8)
                    .opacity(0.55)
            } else if step.state == .done {
                // Softer glow for done
                Circle()
                    .stroke(AppTheme.aqua.opacity(0.28), lineWidth: 6)
                    .blur(radius: 10)
                    .opacity(0.40)
            }
        }
        .allowsHitTesting(false)
    }

    private var shadowGlowColor: Color {
        switch step.state {
        case .current:
            return AppTheme.mint.opacity(0.35)
        case .done:
            return AppTheme.aqua.opacity(0.18)
        case .upcoming:
            return .clear
        }
    }

    private var shadowGlowRadius: CGFloat {
        switch step.state {
        case .current: return 14
        case .done: return 8
        case .upcoming: return 0
        }
    }

    // MARK: - Face

    private var face: some View {
        ZStack {
            // Eyes
            if step.kind == .breathing {
                // Calm closed eyes (safe)
                TimelineClosedEyes()
                    .stroke(AppTheme.ink.opacity(0.68), lineWidth: max(1, size * 0.028))
                    .frame(width: size * 0.42, height: size * 0.16)
                    .position(x: size * 0.50, y: size * 0.43)
            } else {
                HStack(spacing: size * 0.22) {
                    Circle()
                        .fill(AppTheme.ink.opacity(0.80))
                        .frame(width: size * 0.085, height: size * 0.085)
                    Circle()
                        .fill(AppTheme.ink.opacity(0.80))
                        .frame(width: size * 0.085, height: size * 0.085)
                }
                .position(x: size * 0.50, y: size * 0.43)
            }

            // Mouth
            TimelineMouthShape(style: mouthStyle)
                .stroke(AppTheme.ink.opacity(0.70), lineWidth: max(1, size * 0.030))
                .frame(width: size * 0.20, height: size * 0.11)
                .position(x: size * 0.50, y: size * 0.64)

            // ✅ Blush only in Rhythm (more visible)
            if step.kind == .rhythm {
                HStack(spacing: size * 0.34) {
                    Circle()
                        .fill(Color.pink.opacity(step.state == .upcoming ? 0.20 : 0.40))
                        .frame(width: size * 0.16, height: size * 0.16)
                        .blur(radius: 2.2)

                    Circle()
                        .fill(Color.pink.opacity(step.state == .upcoming ? 0.20 : 0.40))
                        .frame(width: size * 0.16, height: size * 0.16)
                        .blur(radius: 2.2)
                }
                .position(x: size * 0.50, y: size * 0.58)
            }
        }
    }

    private var mouthStyle: TimelineMouthStyle {
        switch step.kind {
        case .breathing: return .smile
        case .easyOnset: return .smile
        case .rhythm: return .excited
        }
    }

    // MARK: - Halo (arc nearly invisible + tiny icons)

    private var halo: some View {
        let haloSize = size + haloDiameterExtra

        return ZStack {
            TimelineArcShape()
                .stroke(AppTheme.ink.opacity(arcOpacity), lineWidth: 1) // ✅ almost invisible
                .frame(width: haloSize, height: haloSize)

            HaloIconsOnArc(
                symbols: haloSymbols,
                diameter: haloSize,
                opacity: step.state == .upcoming ? 0.18 : 0.48,
                iconSize: haloIconSize
            )
        }
        .frame(width: haloSize, height: haloSize)
    }

    // ✅ Unified + exactly 3 icons
    private var haloSymbols: [String] {
        switch step.kind {
        case .breathing:
            return ["wind", "wind", "wind"]
        case .easyOnset:
            return ["textformat.abc", "textformat.abc", "textformat.abc"]
        case .rhythm:
            return ["music.note", "music.note", "music.note"]
        }
    }
}

// MARK: - Halo icon placement

private struct HaloIconsOnArc: View {
    let symbols: [String]
    let diameter: CGFloat
    let opacity: Double
    let iconSize: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let d = min(proxy.size.width, proxy.size.height)
            let r = d / 2
            let center = CGPoint(x: r, y: r)

            let angles: [Double] = [225, 270, 315]

            ZStack {
                ForEach(symbols.indices, id: \.self) { i in
                    let sym = symbols[i]
                    let angle = angles[min(i, angles.count - 1)]

                    Image(systemName: sym)
                        .font(.system(size: iconSize, weight: .bold))
                        .foregroundStyle(AppTheme.ink.opacity(opacity))
                        .position(point(onCircleWithRadius: r, angleDegrees: angle, center: center))
                }
            }
        }
    }

    private func point(onCircleWithRadius radius: CGFloat, angleDegrees: Double, center: CGPoint) -> CGPoint {
        let a = angleDegrees * .pi / 180
        return CGPoint(
            x: center.x + radius * CGFloat(cos(a)),
            y: center.y + radius * CGFloat(sin(a))
        )
    }
}

// MARK: - Shapes

private struct TimelineArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        p.addArc(center: center, radius: radius, startAngle: .degrees(210), endAngle: .degrees(-30), clockwise: false)
        return p
    }
}

private struct TimelineMouthShape: Shape {
    let style: TimelineMouthStyle

    func path(in rect: CGRect) -> Path {
        var p = Path()

        switch style {
        case .neutral:
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))

        case .smile:
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.maxY)
            )

        case .excited:
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.30)
            )
        }

        return p
    }
}

private struct TimelineClosedEyes: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()

        let left = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width * 0.38,
            height: rect.height
        )
        p.addPath(singleEyeArc(in: left))

        let right = CGRect(
            x: rect.minX + rect.width * 0.62,
            y: rect.minY,
            width: rect.width * 0.38,
            height: rect.height
        )
        p.addPath(singleEyeArc(in: right))

        return p
    }

    private func singleEyeArc(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.midY))
        p.addQuadCurve(
            to: CGPoint(x: r.maxX, y: r.midY),
            control: CGPoint(x: r.midX, y: r.minY)
        )
        return p
    }
}

// MARK: - Preview Playground (Temporary Dev Tool)

private struct ProgressTimelinePlayground: View {

    enum DemoPhase: String { case easy, rhythm, done }

    @State private var phase: DemoPhase = .easy

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 18) {

                ProgressTimelineView(steps: stepsForPhase(phase))
//                ProgressTimelineView(
//                    steps: stepsForPhase(phase),
//                    nodeSize: 46,
//                    connectorWidth: 96,          // ✅ wide spacing
//                    showsLabels: true,
//                    haloDiameterExtra: 11,
//                    haloOffsetMultiplier: 0.22,  // ✅ closer halo
//                    arcOpacity: 0.01,            // ✅ arc nearly invisible
//                    haloIconSize: 8              // ✅ smaller icons
//                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {

                        Text("Timeline Playground")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.ink)

                        Picker("Phase", selection: $phase) {
                            Text("Easy").tag(DemoPhase.easy)
                            Text("Rhythm").tag(DemoPhase.rhythm)
                            Text("Done").tag(DemoPhase.done)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding(.horizontal, 18)

                Spacer()
            }
            .padding(.top, 24)
        }
    }

    private func stepsForPhase(_ phase: DemoPhase) -> [ProgressTimelineView.Step] {
        let breathing = ProgressTimelineView.Step(title: "Breathing", state: .done, kind: .breathing)

        switch phase {
        case .easy:
            return [
                breathing,
                .init(title: "Easy Onset", state: .current, kind: .easyOnset),
                .init(title: "Rhythm", state: .upcoming, kind: .rhythm)
            ]
        case .rhythm:
            return [
                breathing,
                .init(title: "Easy Onset", state: .done, kind: .easyOnset),
                .init(title: "Rhythm", state: .current, kind: .rhythm)
            ]
        case .done:
            return [
                breathing,
                .init(title: "Easy Onset", state: .done, kind: .easyOnset),
                .init(title: "Rhythm", state: .done, kind: .rhythm)
            ]
        }
    }
}

#Preview {
    ProgressTimelinePlayground()
        .preferredColorScheme(.light)
}

