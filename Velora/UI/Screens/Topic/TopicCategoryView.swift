//
//  TopicCategoryView.swift
//  Velora
//
//  Step 3: Topic Category Selection
//
//  Updated: Custom Topic + Demo hidden
//  ✅ "Say It Your Way" added as last row in the list (same style as categories).
//  ✅ Demo hidden behind TopicLibrary.isDemoEnabled flag (code fully preserved).
//

//
//  TopicCategoryView.swift
//  Velora
//
//  Step 3: Topic Category Selection
//
//  Updated: Custom Topic + Demo hidden
//  ✅ "Say It Your Way" added as last row in the list (same style as categories).
//  ✅ Demo hidden behind TopicLibrary.isDemoEnabled flag (code fully preserved).
//
//  ─── PRESENTER ONLY ──────────────────────────────────────────────────────────
//  Triple-tap on Velora character = hidden demo shortcut (presentations only).
//  To remove: delete @State goDemoPreview + .onTapGesture(count:3) + .navigationDestination block.
//  ─────────────────────────────────────────────────────────────────────────────
//

import SwiftUI

struct TopicCategoryView: View {
    @State private var didAppear: Bool = false

    // ─── PRESENTER ONLY ──────────────────────────────────────────────────────
    @State private var goDemoPreview: Bool = false
    // ─────────────────────────────────────────────────────────────────────────

    private let heroTopPadding: CGFloat = 26
    private let characterSize: CGFloat = 165
    private let heroSpacing: CGFloat = 10
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

                        // MARK: - Built-in categories
                        ForEach(
                            Array(TopicCategory.allCases.enumerated()),
                            id: \.element
                        ) { index, category in
                            NavigationLink {
                                TopicSelectionView(category: category)
                            } label: {
                                categoryRow(category)
                                    .opacity(didAppear ? 1 : 0)
                                    .offset(y: didAppear ? 0 : 10)
                                    .scaleEffect(didAppear ? 1 : 0.99)
                                    .animation(
                                        .spring(response: 0.55, dampingFraction: 0.88)
                                            .delay(0.03 * Double(index + 1)),
                                        value: didAppear
                                    )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }

                        // MARK: - Soft divider before custom option
                        HStack {
                            Rectangle()
                                .fill(AppTheme.ink.opacity(0.08))
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                        .opacity(didAppear ? 1 : 0)
                        .animation(
                            .easeInOut(duration: 0.35)
                                .delay(0.03 * Double(TopicCategory.allCases.count + 1)),
                            value: didAppear
                        )

                        // MARK: - Say It Your Way (same row style, last in list)
                        NavigationLink {
                            CustomTopicInputView()
                        } label: {
                            unifiedRow(
                                iconSystemName: "pencil.and.outline",
                                title: "Say It Your Way",
                                subtitle: "Practice with your own words."
                            )
                            .opacity(didAppear ? 1 : 0)
                            .offset(y: didAppear ? 0 : 10)
                            .scaleEffect(didAppear ? 1 : 0.99)
                            .animation(
                                .spring(response: 0.55, dampingFraction: 0.88)
                                    .delay(0.03 * Double(TopicCategory.allCases.count + 2)),
                                value: didAppear
                            )
                        }
                        .buttonStyle(PressScaleButtonStyle())

                        // MARK: - Demo (hidden — set isDemoEnabled = true to restore)
                        if TopicLibrary.isDemoEnabled {
                            VStack(spacing: 8) {
                                NavigationLink {
                                    BreathingGateView(
                                        topic: TopicLibrary.demoPreviewTopic,
                                        mode: .demoPreview
                                    )
                                } label: {
                                    unifiedRow(
                                        iconSystemName: "sparkles",
                                        title: "Quick Preview",
                                        subtitle: "See the full flow without using the mic."
                                    )
                                }
                                .buttonStyle(PressScaleButtonStyle())

                                Text("Judges: flow preview only. No microphone required.")
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppTheme.ink.opacity(0.55))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 6)
                            }
                            .padding(.top, 6)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationTitle(AppStrings.topics)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { didAppear = true }
        // ─── PRESENTER ONLY ──────────────────────────────────────────────────
        .navigationDestination(isPresented: $goDemoPreview) {
            BreathingGateView(
                topic: TopicLibrary.demoPreviewTopic,
                mode: .demoPreview
            )
        }
        // ─────────────────────────────────────────────────────────────────────
    }

    // MARK: - Header
    // ─── PRESENTER ONLY: triple-tap on Velora triggers demo ──────────────────

    private func heroHeader(
        title: String,
        subtitle: String,
        expression: BubbleExpression,
        gaze: EyeGaze
    ) -> some View {
        VStack(spacing: heroSpacing) {
            Spacer(minLength: heroTopPadding)

            VeloraCharacterView(expression: expression, size: characterSize, gaze: gaze)
                .onTapGesture(count: 3) {
                    Haptics.tap()
                    goDemoPreview = true
                }

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
    // ─────────────────────────────────────────────────────────────────────────

    // MARK: - Row Builders

    private func categoryRow(_ category: TopicCategory) -> some View {
        unifiedRow(
            iconSystemName: category.icon,
            title: category.title,
            subtitle: category.subtitle
        )
    }

    private func unifiedRow(
        iconSystemName: String,
        title: String,
        subtitle: String
    ) -> some View {
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
                        .lineLimit(1)
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

// MARK: - Button Style

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
