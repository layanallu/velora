//
//  TechniqueIntroOverlay.swift
//  Velora
//
//  Center modal technique intro overlay (bigger + Apple-style spacing).
//
//  Updated by Velora on 27/02/2026.
//  Updated by Velora on 28/02/2026:
//  ✅ Easy Onset gets a narrower card width only (others unchanged).
//

import SwiftUI

struct TechniqueIntroOverlay: View {
    let technique: TechniqueKind
    let onDismiss: () -> Void
    var onTapAudioSample: () -> Void = {}

    // ✅ Base sizing (THIS stays the same for Breathing + Rhythm)
    var maxCardWidth: CGFloat = 440
    var maxCardHeight: CGFloat = 740
    var cardWidthFactor: CGFloat = 0.90
    var cardHeightFactor: CGFloat = 0.86

    private enum Stage: Int {
        case intro = 0
        case bullets
        case exampleLabel
        case example
        case closing
    }

    @State private var stage: Stage = .intro
    @State private var runID: UUID = UUID()

    private let cornerRadius: CGFloat = 28

    // Reserved slots (no jumping)
    private let introSlot: CGFloat = 60
    private let bulletsSlot: CGFloat = 98
    private let exampleLabelSlot: CGFloat = 18
    private let exampleSlot: CGFloat = 78
    private let closingSlot: CGFloat = 52

    private let ctaHeight: CGFloat = 56

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .overlay(AppTheme.ink.opacity(0.18).ignoresSafeArea())

            GeometryReader { geo in
                let screenH = geo.size.height
                let screenW = geo.size.width

                // ✅ Default (unchanged) sizing
                let defaultW = min(maxCardWidth, screenW * cardWidthFactor)
                let defaultH = min(maxCardHeight, screenH * cardHeightFactor)

                // ✅ Easy Onset ONLY:
                // Make it narrower + clamp to safe width to prevent side clipping.
                let insets = geo.safeAreaInsets
                let safeW = max(0, screenW - insets.leading - insets.trailing)

                let easyOnsetWidthFactor: CGFloat = 0.60         // 👈 narrower ONLY here
                let easyOnsetMaxWidth: CGFloat = 370              // 👈 extra clamp ONLY here
                let easyW = min(easyOnsetMaxWidth, safeW * easyOnsetWidthFactor)

                let cardW: CGFloat = (technique == .easyOnset) ? easyW : defaultW
                let cardH: CGFloat = defaultH // ✅ keep height SAME for all techniques

                card(width: cardW, height: cardH)
                    .frame(width: cardW, height: cardH)
                    .position(x: screenW / 2, y: screenH / 2)
            }
        }
        .accessibilityAddTraits(.isModal)
        .onAppear { resetSequence() }
    }

    // MARK: - Card

    private func card(width: CGFloat, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return ZStack(alignment: .topTrailing) {
            shape
                .fill(AppTheme.paper.opacity(0.92))
                .overlay(shape.stroke(AppTheme.ink.opacity(0.08), lineWidth: 1))
                .shadow(color: AppTheme.shadow, radius: 16, x: 0, y: 12)

            closeButton
                .padding(14)

            VStack(spacing: 0) {
                Spacer(minLength: 18)

                VeloraCharacterView(
                    expression: .gentle,
                    size: 100,
                    gaze: .center,
                    eyeState: .open,
                    motionStyle: .subtle,
                    mouthMode: .curve
                )
                .padding(.bottom, 14)

                Text(technique.title)
                    .font(AppTheme.titleFont)
                    .foregroundStyle(AppTheme.ink)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 14)

                ZStack {
                    Color.clear.frame(height: introSlot)

                    if stage.rawValue >= Stage.intro.rawValue {
                        TypewriterText(
                            text: technique.intro,
                            characterInterval: 0.020,
                            startDelay: 0.06,
                            allowsTapToReveal: true,
                            multilineAlignment: .center,
                            onFinished: { advance(to: .bullets) }
                        )
                        .id("intro-\(runID)")
                        .font(AppTheme.subtitleFont)
                        .foregroundStyle(AppTheme.ink.opacity(0.78))
                        .padding(.horizontal, 22)
                    }
                }
                .padding(.bottom, 12)

                ZStack(alignment: .topLeading) {
                    Color.clear.frame(height: bulletsSlot)

                    if stage.rawValue >= Stage.bullets.rawValue {
                        TypewriterBulletList(
                            bullets: technique.bullets,
                            characterInterval: 0.017,
                            firstDelay: 0.03,
                            gapBetweenBullets: 0.07,
                            onFinished: { advance(to: .exampleLabel) }
                        )
                        .id("bullets-\(runID)")
                        .padding(.horizontal, 22)
                    }
                }
                .padding(.bottom, 14)

                ZStack(alignment: .leading) {
                    Color.clear.frame(height: exampleLabelSlot)

                    if stage.rawValue >= Stage.exampleLabel.rawValue {
                        TypewriterText(
                            text: "EXAMPLE",
                            characterInterval: 0.024,
                            startDelay: 0.05,
                            allowsTapToReveal: true,
                            multilineAlignment: .leading,
                            onFinished: { advance(to: .example) }
                        )
                        .id("exampleLabel-\(runID)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.ink.opacity(0.55))
                        .kerning(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                    }
                }
                .padding(.bottom, 10)

                ZStack {
                    Color.clear.frame(height: exampleSlot)

                    if stage.rawValue >= Stage.example.rawValue {
                        technique.exampleView(audioTap: onTapAudioSample)
                            .padding(.horizontal, 22)
                            .transition(.opacity)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                                    advance(to: .closing)
                                }
                            }
                    }
                }
                .padding(.bottom, 16)

                ZStack {
                    Color.clear.frame(height: closingSlot)

                    if stage.rawValue >= Stage.closing.rawValue {
                        TypewriterText(
                            text: technique.closing,
                            characterInterval: 0.020,
                            startDelay: 0.05,
                            allowsTapToReveal: true,
                            multilineAlignment: .center,
                            onFinished: nil
                        )
                        .id("closing-\(runID)")
                        .font(AppTheme.subtitleFont)
                        .foregroundStyle(AppTheme.ink.opacity(0.78))
                        .padding(.horizontal, 22)
                    }
                }

                Spacer(minLength: 16)

                Button(action: onDismiss) {
                    Text("Got it")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.mint.opacity(0.95), AppTheme.aqua.opacity(0.95)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .frame(height: ctaHeight)
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
            .frame(width: width, height: height)
        }
        .clipShape(shape)
        .clipped()
    }

    private var closeButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.ink.opacity(0.55))
                .frame(width: 36, height: 36)
                .background(AppTheme.paper.opacity(0.78))
                .clipShape(Circle())
                .overlay(Circle().stroke(AppTheme.ink.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Close"))
    }

    // MARK: - Sequence

    private func resetSequence() {
        stage = .intro
        runID = UUID()
    }

    private func advance(to next: Stage) {
        guard next.rawValue > stage.rawValue else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            stage = next
        }
    }
}
