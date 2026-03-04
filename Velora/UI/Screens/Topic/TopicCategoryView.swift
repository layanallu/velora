//
//  TopicCategoryView.swift
//  Velora
//
//  Step 3: Topic Category Selection
//
//  ✅ Scroll works (removed drag gestures that block scrolling)
//  ✅ Header scrolls away (heroHeader inside ScrollView)
//  ✅ Shadowless cards (GlassCard without shadow)
//  ✅ Stable navigation with NavigationLink
//
//  Updated by Velora on 28/02/2026:
//  ✅ "Quick Preview" is now the LAST card (under the categories).
//  ✅ All cards share the exact same visual style (same GlassCard layout).
//  ✅ Added judges-only caption under Quick Preview to clarify (no mic required).
//

import SwiftUI

struct TopicCategoryView: View {
    @State private var didAppear: Bool = false

    // MARK: - Layout constants
    private let heroTopPadding: CGFloat = 26
    private let characterSize: CGFloat = 165
    private let heroSpacing: CGFloat = 10

    // ✅ Unified card style (all rows identical)
    private let cardCornerRadius: CGFloat = 22
    private let cardContentPadding: CGFloat = 10
    private let rowInnerVerticalPadding: CGFloat = 1

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {

                    heroHeader(
                        title: "Choose your path",
                        subtitle: "Start with reading, or try a real-life scenario.",
                        expression: .gentle,
                        gaze: .down
                    )

                    VStack(spacing: 10) {

                        // MARK: - Categories (first)
                        ForEach(Array(TopicCategory.allCases.enumerated()), id: \.element) { index, category in
                            NavigationLink {
                                TopicSelectionView(category: category)
                            } label: {
                                categoryRow(category)
                                    .opacity(didAppear ? 1 : 0)
                                    .offset(y: didAppear ? 0 : 10)
                                    .scaleEffect(didAppear ? 1 : 0.99)
                                    .animation(
                                        .spring(response: 0.55, dampingFraction: 0.88, blendDuration: 0)
                                            .delay(0.03 * Double(index + 1)),
                                        value: didAppear
                                    )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }

                        // MARK: - Quick Preview (Judges) — LAST (same card style)
                        VStack(spacing: 8) {
                            NavigationLink {
                                // ✅ Full flow, but simulated speech:
                                // Breathing > Ready > Easy Onset (tap mic) > Rhythm (double-tap) > Feedback
                                BreathingGateView(topic: TopicLibrary.demoPreviewTopic, mode: .demoPreview)
                            } label: {
                                quickPreviewRow()
                                    .opacity(didAppear ? 1 : 0)
                                    .offset(y: didAppear ? 0 : 10)
                                    .scaleEffect(didAppear ? 1 : 0.99)
                                    .animation(
                                        .spring(response: 0.55, dampingFraction: 0.88, blendDuration: 0)
                                            .delay(0.03 * Double(TopicCategory.allCases.count + 1)),
                                        value: didAppear
                                    )
                            }
                            .buttonStyle(PressScaleButtonStyle())

                            // ✅ Judges-only caption (clear + honest)
                            Text("Judges: this is a flow preview only. No microphone or speech recognition is required.")
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.ink.opacity(0.55))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 6)
                                .accessibilityLabel("Judges: this is a flow preview only. No microphone required.")
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                }
            }
        }
        .navigationTitle(AppStrings.topics)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { didAppear = true }
    }

    // MARK: - Header

    private func heroHeader(title: String, subtitle: String, expression: BubbleExpression, gaze: EyeGaze) -> some View {
        VStack(spacing: heroSpacing) {
            Spacer(minLength: heroTopPadding)

            VeloraCharacterView(expression: expression, size: characterSize, gaze: gaze)

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)

                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.ink.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Quick Preview Row (same shape as categories)

    private func quickPreviewRow() -> some View {
        unifiedRow(
            iconSystemName: "sparkles",
            title: "Quick Preview",
            subtitle: "See the full flow without using the mic."
        )
        .accessibilityLabel("Quick Preview")
    }

    // MARK: - Category Row

    private func categoryRow(_ category: TopicCategory) -> some View {
        unifiedRow(
            iconSystemName: category.icon,
            title: category.title,
            subtitle: category.subtitle
        )
    }

    // MARK: - Unified Row Builder (ONE source of truth)

    private func unifiedRow(iconSystemName: String, title: String, subtitle: String) -> some View {
        GlassCard(contentPadding: cardContentPadding, cornerRadius: cardCornerRadius) {
            HStack(spacing: 12) {
                Image(systemName: iconSystemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(0.6))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.ink.opacity(0.5))
            }
            .padding(.vertical, rowInnerVerticalPadding)
        }
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
    }
}

// MARK: - Shared ButtonStyle (same as TopicSelectionView)

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.992 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.92), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

// MARK: - Preview

struct TopicCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            TopicCategoryView()
        }
        .preferredColorScheme(.light)
    }
}
