//
//  WaveformMiniView.swift
//  Velora
//
//  Premium Rim Wave Orb (Siri-ish, lightweight) — v3 (Inner Power Ring)
//  ✅ Base rim always visible
//  ✅ Outer rim = waveform (edge wave)
//  ✅ Inner ring = stronger + moves INWARD on loud moments
//  ✅ Light mesh dots band
//  ✅ TimelineView 30fps (no infinite loops)
//  ✅ Safe margins (no clipping)
//
//  Updated by Velora on 26/02/2026.
//

import SwiftUI

struct WaveformMiniView: View {
    var level: Float          // 0...1
    var isActive: Bool

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate

                Canvas(rendersAsynchronously: true) { context, size in
                    draw(context: &context, size: size, time: t)
                }
                .drawingGroup()
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: - Drawing

    private func draw(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let rect = CGRect(origin: .zero, size: size)
        let c = CGPoint(x: rect.midX, y: rect.midY)

        let minSide = min(size.width, size.height)

        // Safe margin so nothing clips even when it deforms
        let safe = minSide * 0.14
        let drawSide = max(10, minSide - safe * 2)

        let baseR = drawSide * 0.36

        // --- Audio shaping ---
        let raw = CGFloat(max(0, min(1, level)))
        let shaped = pow(raw, 0.62)                          // boosts quiet input
        let gate: CGFloat = isActive ? 1.0 : 0.55

        // energy: 0..1 (visual)
        let energy = clamp(0.10 + 0.95 * shaped * gate, 0, 1)

        // spike: more aggressive for “power moments”
        let spike = clamp(pow(shaped, 0.32) * gate, 0, 1)    // jumps faster on loud

        // --- Brand gradient ---
        let rimGradient = Gradient(colors: [
            AppTheme.mint.opacity(0.98),
            AppTheme.aqua.opacity(0.98),
            AppTheme.mint.opacity(0.88)
        ])

        // MARK: - Soft aura
        let auraR = baseR * (1.18 + 0.24 * energy)
        let auraRect = CGRect(x: c.x - auraR, y: c.y - auraR, width: auraR * 2, height: auraR * 2)

        context.addFilter(.shadow(color: AppTheme.aqua.opacity(0.16 + 0.22 * energy),
                                  radius: 18 + 22 * energy, x: 0, y: 0))
        context.fill(
            Path(ellipseIn: auraRect),
            with: .radialGradient(
                Gradient(colors: [
                    AppTheme.aqua.opacity(0.14 + 0.16 * energy),
                    AppTheme.mint.opacity(0.06 + 0.10 * energy),
                    .clear
                ]),
                center: c,
                startRadius: baseR * 0.20,
                endRadius: auraR
            )
        )
        context.addFilter(.shadow(color: .clear, radius: 0))

        // MARK: - Base rim (always visible)
        let rimR = baseR * 1.02
        let baseCircle = Path(ellipseIn: CGRect(x: c.x - rimR, y: c.y - rimR, width: rimR * 2, height: rimR * 2))

        context.addFilter(.shadow(color: AppTheme.aqua.opacity(0.26), radius: 14, x: 0, y: 0))
        context.stroke(
            baseCircle,
            with: .linearGradient(
                rimGradient,
                startPoint: CGPoint(x: safe * 0.2, y: safe * 0.1),
                endPoint: CGPoint(x: size.width - safe * 0.1, y: size.height - safe * 0.2)
            ),
            lineWidth: max(5.5, drawSide * 0.022)
        )
        context.addFilter(.shadow(color: .clear, radius: 0))

        // Specular highlight
        context.stroke(baseCircle, with: .color(AppTheme.paper.opacity(0.52)),
                       lineWidth: max(1.0, drawSide * 0.0048))

        // MARK: - Rim dots band (premium texture)
        drawRimDots(context: &context, center: c, radius: rimR * 0.985, time: time, energy: energy, drawSide: drawSide)

        // MARK: - Outer waveform rim (edge wave)
        let wavePath = makeRimWavePath(center: c, radius: rimR, time: time, energy: energy)

        context.addFilter(.shadow(color: AppTheme.aqua.opacity(0.30 + 0.42 * energy),
                                  radius: 12 + 18 * energy, x: 0, y: 0))
        context.stroke(
            wavePath,
            with: .linearGradient(
                Gradient(colors: [
                    AppTheme.aqua.opacity(0.98),
                    AppTheme.mint.opacity(0.90),
                    AppTheme.aqua.opacity(0.96)
                ]),
                startPoint: CGPoint(x: safe * 0.2, y: safe * 0.2),
                endPoint: CGPoint(x: size.width - safe * 0.2, y: size.height - safe * 0.25)
            ),
            lineWidth: max(3.8, drawSide * 0.016) + drawSide * 0.010 * energy
        )
        context.addFilter(.shadow(color: .clear, radius: 0))

        // MARK: - Inner Power Ring (stronger + moves inward on loud)
        drawInnerPowerRing(context: &context, center: c, baseR: baseR, time: time, energy: energy, spike: spike, drawSide: drawSide)

        // MARK: - Inner soft fill (thinner)
        let innerR = baseR * 0.72  // 👈 تحكم بالحجم هنا
        let innerRect = CGRect(x: c.x - innerR, y: c.y - innerR, width: innerR * 2, height: innerR * 2)

        context.fill(
            Path(ellipseIn: innerRect),
            with: .radialGradient(
                Gradient(colors: [
                    AppTheme.paper.opacity(0.22),
                    AppTheme.paper.opacity(0.08),
                    .clear
                ]),
                center: CGPoint(x: c.x - innerR * 0.16, y: c.y - innerR * 0.20),
                startRadius: innerR * 0.10,
                endRadius: innerR * 1.25   // 👈 يحافظ على النعومة
            )
        )

        // MARK: - Inner pulse glow (subtle “alive”)
        let pulseR = baseR * (0.58 + 0.10 * spike)
        let pulseRect = CGRect(x: c.x - pulseR, y: c.y - pulseR, width: pulseR * 2, height: pulseR * 2)

        context.fill(
            Path(ellipseIn: pulseRect),
            with: .radialGradient(
                Gradient(colors: [
                    AppTheme.aqua.opacity(0.10 + 0.18 * spike),
                    .clear
                ]),
                center: c,
                startRadius: 0,
                endRadius: pulseR
            )
        )
    }

    // MARK: - Inner Power Ring

    private func drawInnerPowerRing(
        context: inout GraphicsContext,
        center c: CGPoint,
        baseR: CGFloat,
        time: TimeInterval,
        energy: CGFloat,
        spike: CGFloat,
        drawSide: CGFloat
    ) {
        // This ring sits INSIDE. When spike rises, it “pulls inward” (radius shrinks)
        let baseRadius = baseR * 1
        let inward = baseR * 0.05 * spike            // 👈 stronger inward move
        let r = baseRadius - inward

        // More aggressive amplitude than outer ring
        let amp = r * (0.010 + 0.120 * spike)

        // Phase is slightly different so it feels layered
        let tt = CGFloat(time) + 1.35

        let steps = 240
        var path = Path()
        for i in 0...steps {
            let a = (CGFloat(i) / CGFloat(steps)) * (.pi * 2)

            let n1 = sin(a * 2.4 + tt * 1.10) * 0.62
            let n2 = sin(a * 6.2 - tt * 0.72) * 0.28
            let n3 = sin(a * 12.0 + tt * 0.50) * 0.10

            let rr = r + amp * (n1 + n2 + n3)

            let x = c.x + cos(a) * rr
            let y = c.y + sin(a) * rr

            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()

        // Stronger glow from inside
        context.addFilter(.shadow(color: AppTheme.mint.opacity(0.14 + 0.40 * spike),
                                  radius: 10 + 18 * spike, x: 0, y: 0))
        context.addFilter(.shadow(color: AppTheme.aqua.opacity(0.10 + 0.32 * spike),
                                  radius: 10 + 18 * spike, x: 0, y: 0))

        context.stroke(
            path,
            with: .linearGradient(
                Gradient(colors: [
                    AppTheme.mint.opacity(0.55 + 0.35 * spike),
                    AppTheme.aqua.opacity(0.45 + 0.40 * spike),
                    AppTheme.mint.opacity(0.40 + 0.35 * spike)
                ]),
                startPoint: CGPoint(x: c.x - r, y: c.y - r),
                endPoint: CGPoint(x: c.x + r, y: c.y + r)
            ),
            lineWidth: max(1.4, drawSide * 0.006) + drawSide * 0.006 * spike
        )

        context.addFilter(.shadow(color: .clear, radius: 0))
    }

    // MARK: - Rim Dots

    private func drawRimDots(
        context: inout GraphicsContext,
        center c: CGPoint,
        radius r: CGFloat,
        time: TimeInterval,
        energy: CGFloat,
        drawSide: CGFloat
    ) {
        let tt = CGFloat(time)

        let rings = 3
        let dotsPerRing = 90

        let dotBase = max(0.9, drawSide * 0.0065)
        let bandWidth = r * (0.08 + 0.06 * energy)

        for ring in 0..<rings {
            let v = CGFloat(ring) / CGFloat(max(1, rings - 1))
            let rr = r - v * bandWidth

            for i in 0..<dotsPerRing {
                let u = CGFloat(i) / CGFloat(dotsPerRing)
                let a = u * (.pi * 2)

                let wiggle =
                sin(a * 2.2 + tt * 0.85) * (0.010 + 0.018 * energy) +
                sin(a * 6.0 - tt * 0.60) * (0.006 + 0.010 * energy)

                let x = c.x + cos(a) * rr * (1.0 + wiggle)
                let y = c.y + sin(a) * rr * (1.0 + wiggle)

                let spec = max(0, cos(a - .pi * 0.22))
                let alpha = (0.03 + 0.12 * energy) * (0.30 + 0.70 * spec) * (0.40 + 0.60 * (1.0 - v))

                let s = dotBase * (0.70 + 0.85 * energy) * (0.70 + 0.55 * spec)
                let dotRect = CGRect(x: x - s * 0.5, y: y - s * 0.5, width: s, height: s)

                context.fill(Path(ellipseIn: dotRect), with: .color(AppTheme.aqua.opacity(alpha)))
            }
        }
    }

    // MARK: - Outer Rim Wave Path

    private func makeRimWavePath(center c: CGPoint, radius r: CGFloat, time: TimeInterval, energy: CGFloat) -> Path {
        var p = Path()
        let steps = 280
        let tt = CGFloat(time)

        let amp = r * (0.010 + 0.085 * energy)

        func bias(_ a: CGFloat) -> CGFloat {
            let d = max(0, cos(a - .pi * 0.22))
            return 0.82 + 0.18 * d
        }

        for i in 0...steps {
            let a = (CGFloat(i) / CGFloat(steps)) * (.pi * 2)

            let n1 = sin(a * 2.10 + tt * 1.05) * 0.62
            let n2 = sin(a * 5.20 - tt * 0.78) * 0.28
            let n3 = sin(a * 11.0 + tt * 0.50) * 0.10

            let mix = (n1 + n2 + n3) * bias(a)
            let rr = r + amp * mix

            let x = c.x + cos(a) * rr
            let y = c.y + sin(a) * rr

            if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
            else { p.addLine(to: CGPoint(x: x, y: y)) }
        }

        p.closeSubpath()
        return p
    }

    private func clamp(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat { max(a, min(b, x)) }
}
