//
//  TopicSelectionView.swift
//  Velora
//
//  Step 3B: Topics (per category)
//
//  ✅ Scroll works (removed drag gestures that block scrolling)
//  ✅ Header scrolls away (moved heroHeader inside ScrollView)
//  ✅ Keeps shadowless cards + stable navigation to BreathingGateView
//

import SwiftUI

struct TopicSelectionView: View {
    let category: TopicCategory

    @State private var selectedTopic: Topic? = nil
    @State private var goBreathing: Bool = false
    @State private var didAppear: Bool = false

    // MARK: - Layout constants
    private let heroTopPadding: CGFloat = 26
    private let characterSize: CGFloat = 165
    private let heroSpacing: CGFloat = 10

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var topics: [Topic] {
        TopicLibrary.topics(for: category)
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            // ✅ Header now scrolls away (inside ScrollView)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {

                    heroHeader(
                        title: category.title,
                        subtitle: "Choose a topic.",
                        expression: .gentle,
                        gaze: .down
                    )

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                            Button {
                                selectedTopic = topic
                                Haptics.tap()
                                goBreathing = true
                            } label: {
                                topicCard(topic)
                                    .opacity(didAppear ? 1 : 0)
                                    .offset(y: didAppear ? 0 : 10)
                                    .scaleEffect(didAppear ? 1 : 0.99)
                                    .animation(
                                        .spring(response: 0.55, dampingFraction: 0.88, blendDuration: 0)
                                            .delay(0.02 * Double(index)),
                                        value: didAppear
                                    )
                            }
                            .buttonStyle(PressScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 18)
                }
            }
        }
        .navigationTitle(AppStrings.topics)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goBreathing) {
            destinationView
        }
        .onAppear {
            didAppear = true
            selectedTopic = nil
        }
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

    // MARK: - Topic card

    private func topicCard(_ topic: Topic) -> some View {
        GlassCard(contentPadding: 12, cornerRadius: 22) {
            VStack(spacing: 10) {
                Image(systemName: topic.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.ink)

                Text(topic.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var destinationView: some View {
        if let selectedTopic {
            BreathingGateView(topic: selectedTopic)
        } else {
            Text("No topics available.")
                .foregroundStyle(AppTheme.ink)
        }
    }
}

// MARK: - ButtonStyle (Press feedback WITHOUT blocking ScrollView)

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.992 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.92), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}
