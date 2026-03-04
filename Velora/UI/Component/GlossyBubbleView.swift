//
//  GlossyBubbleView.swift
//  Velora
//
//  Real glossy bubble (no assets):
//  - Gradient body
//  - Specular highlight
//  - Soft glow
//  - Pop animation + splash droplets
//
//  Created by Velora.
//

import SwiftUI

struct GlossyBubbleView: View {
    enum BubbleState {
        case pending
        case popped
    }

    let state: BubbleState
    let size: CGFloat
    let animateBreath: Bool

    // Expose initializer for use outside this file (within module)
    init(state: BubbleState, size: CGFloat, animateBreath: Bool) {
        self.state = state
        self.size = size
        self.animateBreath = animateBreath
    }

    @State private var breath: Bool = false
    @State private var didPop: Bool = false

    var body: some View {
        ZStack {
            if state == .popped {
                // Pop splash
                PopSplashView(size: size * 1.15, isActive: didPop)
                    .onAppear { didPop = true }
            } else {
                bubbleBody
                    .scaleEffect(breath && animateBreath ? 1.06 : 1.0)
                    .animation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true),
                               value: breath)
                    .onAppear { breath = true }
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: state)
    }

    private var bubbleBody: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.mint.opacity(0.28),
                            AppTheme.aqua.opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.7
                    )
                )
                .blur(radius: 6)

            // Main bubble
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppTheme.aqua.opacity(0.55),
                            AppTheme.mint.opacity(0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Inner shading
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.10),
                                    AppTheme.ink.opacity(0.08),
                                    Color.clear
                                ],
                                center: .bottomTrailing,
                                startRadius: 1,
                                endRadius: size * 0.65
                            )
                        )
                )
                .overlay(
                    // Rim highlight
                    Circle()
                        .stroke(Color.white.opacity(0.38), lineWidth: 1.2)
                        .blur(radius: 0.2)
                )
                .shadow(color: AppTheme.shadow.opacity(0.75), radius: 8, x: 0, y: 6)

            // Specular highlight (top-left)
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: size * 0.35, height: size * 0.23)
                .offset(x: -size * 0.18, y: -size * 0.22)
                .blur(radius: 0.5)

            // Tiny sparkle dot
            Circle()
                .fill(Color.white.opacity(0.22))
                .frame(width: size * 0.07, height: size * 0.07)
                .offset(x: -size * 0.05, y: -size * 0.05)
        }
    }
}

private struct PopSplashView: View {
    let size: CGFloat
    let isActive: Bool

    @State private var expand: Bool = false
    @State private var fade: Bool = false

    var body: some View {
        ZStack {
            // Core ring
            Circle()
                .stroke(Color.white.opacity(0.45), lineWidth: 2)
                .frame(width: size * (expand ? 1.0 : 0.25),
                       height: size * (expand ? 1.0 : 0.25))
                .opacity(fade ? 0 : 1)
                .blur(radius: 0.3)

            // Droplets (8)
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * (Double.pi * 2 / 8)
                let dx = cos(angle) * (expand ? size * 0.45 : size * 0.10)
                let dy = sin(angle) * (expand ? size * 0.45 : size * 0.10)

                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: size * 0.10, height: size * 0.10)
                    .offset(x: dx, y: dy)
                    .opacity(fade ? 0 : 1)
                    .blur(radius: 0.2)
            }
        }
        .onAppear {
            guard isActive else { return }
            withAnimation(.easeOut(duration: 0.22)) { expand = true }
            withAnimation(.easeOut(duration: 0.28).delay(0.10)) { fade = true }
        }
    }
}
