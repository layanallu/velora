//
//  CustomTopicInputView.swift
//  Velora
//
//  The screen where the user types their own text to practice.
//
//  UX decisions:
//  - Info icon next to difficulty badge → always grey
//  - Info icon next to inline message → always matches badge color
//  - All messages short, warm, human — written for someone who stutters
//  - Keyboard dismisses on scroll (DragGesture — no conflict with text selection)
//  - All messages live inside the input card always
//  - Velora uses approved expressions only: gentle, smile, neutral, focused
//

import SwiftUI
import UIKit

struct CustomTopicInputView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var inputText: String = ""
    @State private var analysis: CustomTopicAnalysis? = nil
    @State private var builtTopic: Topic? = nil
    @State private var goSession: Bool = false
    @State private var debounceTask: Task<Void, Never>? = nil
    @State private var inlineMessage: InlineMessage? = nil

    // ─── REMOVE LATER (App Store) ────────────────────────────────────────────
    @State private var showGuideSheet: Bool = false
    // ─────────────────────────────────────────────────────────────────────────

    private let maxChars = 400
    private let minChars = 10

    private static let encouragements: [String] = [
        "What do you say most often?",
        "Pick something real from your day.",
        "Even one sentence is enough.",
        "Think of a moment you'd like to feel ready for.",
        "What's something you want to say with ease?",
        "Your words, your pace.",
        "Something small is a perfect start.",
        "What would feel good to say out loud?"
    ]
    @State private var encouragement: String = ""

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {

                heroSection
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                inputCard
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)

                if builtTopic != nil {
                    PrimaryButton(
                        title: "Start Practice",
                        systemImage: "play.fill"
                    ) {
                        Haptics.tap()
                        dismissKeyboard()
                        goSession = true
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 40)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { _ in dismissKeyboard() }
        )
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Say It Your Way")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goSession) {
            destinationView
        }
        // ─── REMOVE LATER (App Store) ────────────────────────────────────────
        .sheet(isPresented: $showGuideSheet) {
            guideSheet
        }
        // ─────────────────────────────────────────────────────────────────────
        .onAppear {
            encouragement = Self.encouragements.randomElement()
                ?? "What do you say most often?"
        }
        .onChange(of: inputText) { _, _ in
            scheduleAnalysis()
        }
        .animation(.easeInOut(duration: 0.22), value: builtTopic == nil)
        .animation(.easeInOut(duration: 0.22), value: inlineMessage?.text)
    }

    // MARK: - Keyboard Dismiss

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            VeloraCharacterView(
                expression: veloraExpression,
                size: 120,
                gaze: .center,
                eyeState: .open,
                motionStyle: .subtle,
                mouthMode: .curve
            )
            .animation(.easeInOut(duration: 0.35), value: veloraExpression)

            VStack(spacing: 6) {
                Text("Say It Your Way")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)

                Text(encouragement)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.ink.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Velora Expression
    // Approved: gentle, smile, neutral, focused

    private var veloraExpression: BubbleExpression {
        if builtTopic != nil              { return .smile   }
        if inlineMessage?.isError == true { return .neutral }
        guard !inputText.isEmpty          else { return .gentle  }
        guard let analysis                else { return .neutral }
        switch analysis.difficulty {
        case .easy:   return .smile
        case .medium: return .gentle
        case .hard:   return .focused
        }
    }

    // MARK: - Difficulty Color
    // Used for: badge background + inline message icon color

    private func difficultyColor(_ difficulty: CustomTopicAnalysis.Difficulty) -> Color {
        switch difficulty {
        case .easy:   return AppTheme.mint
        case .medium: return AppTheme.aqua
        case .hard:   return Color.orange.opacity(0.75)
        }
    }

    // MARK: - Input Card

    private var inputCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {

                // Header row
                HStack(alignment: .center, spacing: 8) {
                    Text("What do you want to say?")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)

                    Spacer()

                    // Difficulty badge
                    if let analysis {
                        difficultyBadge(analysis.difficulty)
                            .transition(.opacity.combined(with: .scale(scale: 0.90)))
                            .animation(.easeInOut(duration: 0.20), value: analysis.difficulty)
                    }

                    // ─── REMOVE LATER (App Store) ─────────────────────────
                    // Info icon next to badge → ALWAYS grey (no difficulty color here)
                    if builtTopic != nil {
                        Button {
                            Haptics.tap()
                            showGuideSheet = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.ink.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.18), value: builtTopic != nil)
                    }
                    // ──────────────────────────────────────────────────────
                }

                // Growing editor
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("e.g. Hi, my name is Sarah and I work at the coffee shop.")
                            .font(.system(size: 15, weight: .regular, design: .rounded))
                            .foregroundStyle(AppTheme.ink.opacity(0.28))
                            .padding(.top, 2)
                            .allowsHitTesting(false)
                    }

                    GrowingTextEditor(text: $inputText, maxChars: maxChars)
                        .frame(minHeight: 110)
                }

                // Inline message — always inside this card
                if let msg = inlineMessage {
                    Divider().opacity(0.18)

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: msg.isError
                              ? "exclamationmark.circle.fill"
                              : "info.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(
                                msg.isError
                                    // Error → orange
                                    ? Color.orange.opacity(0.80)
                                    // Info → matches badge color (difficulty color)
                                    : (analysis.map { difficultyColor($0.difficulty) }
                                       ?? AppTheme.aqua)
                            )
                            .padding(.top, 1)

                        Text(msg.text)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.ink.opacity(0.68))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.20), value: msg.text)
                }
            }
        }
    }

    // MARK: - Difficulty Badge

    private func difficultyBadge(_ difficulty: CustomTopicAnalysis.Difficulty) -> some View {
        let label: String
        switch difficulty {
        case .easy:   label = "Easy"
        case .medium: label = "Medium"
        case .hard:   label = "Tricky"
        }
        return Text(label)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.ink.opacity(0.80))
            .padding(.vertical, 3)
            .padding(.horizontal, 9)
            .background(difficultyColor(difficulty).opacity(0.35))
            .clipShape(Capsule())
    }

    // ─── REMOVE LATER (App Store) ────────────────────────────────────────────
    // MARK: - Guide Sheet
    // Delete: this var + @State showGuideSheet + .sheet modifier + info button

    private var guideSheet: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let analysis {
                            guideSection(
                                title: "Easy Onset Steps",
                                icon: "mic.fill",
                                items: analysis.easyOnsetSteps
                            )
                            Divider().opacity(0.20)
                            guideSection(
                                title: "Rhythm Chunks",
                                icon: "circle.grid.3x3.fill",
                                items: analysis.rhythmClauses
                            )
                        } else {
                            Text("Finish typing to see the breakdown.")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.ink.opacity(0.50))
                                .padding(.top, 40)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("How Velora Guides You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showGuideSheet = false }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func guideSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.aqua)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink.opacity(0.45))
                    .kerning(0.5)
            }
            ForEach(items, id: \.self) { item in
                HStack(spacing: 8) {
                    Circle()
                        .fill(LinearGradient(
                            colors: [AppTheme.mint, AppTheme.aqua],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 7, height: 7)
                    Text(item)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(0.80))
                }
            }
        }
    }
    // ─────────────────────────────────────────────────────────────────────────

    // MARK: - Navigation Destination

    @ViewBuilder
    private var destinationView: some View {
        if let topic = builtTopic {
            BreathingGateView(topic: topic, mode: .normal)
        } else {
            Text("Something went wrong. Please go back and try again.")
                .foregroundStyle(AppTheme.ink)
                .padding()
        }
    }

    // MARK: - Inline Message Model

    private struct InlineMessage: Equatable {
        let text: String
        let isError: Bool
    }

    // MARK: - Live Analysis (debounced 0.6s)

    private func scheduleAnalysis() {
        debounceTask?.cancel()

        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            withAnimation(.easeInOut(duration: 0.18)) {
                builtTopic = nil
                analysis = nil
                inlineMessage = nil
            }
            return
        }

        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { runAnalysis() }
        }
    }

    private func runAnalysis() {
        let result = CustomTopicBuilder.build(from: inputText)

        switch result {
        case .success(let topic):
            builtTopic = topic
            let preview = CustomTopicBuilder.preview(from: inputText)
            analysis = preview
            withAnimation(.easeInOut(duration: 0.22)) {
                inlineMessage = InlineMessage(
                    text: humanMessage(for: preview),
                    isError: false
                )
            }

        case .failure(let error):
            builtTopic = nil
            analysis = nil
            withAnimation(.easeInOut(duration: 0.22)) {
                inlineMessage = InlineMessage(
                    text: humanErrorMessage(for: error),
                    isError: true
                )
            }
        }
    }

    // MARK: - Human Messages
    // Short. Warm. Written for someone who stutters.
    // No "your text", no clinical language, no long sentences.

    private func humanMessage(for analysis: CustomTopicAnalysis) -> String {
        // Specific warnings take priority
        if let warning = analysis.warnings.first {
            return warning
        }

        switch analysis.difficulty {
        case .easy:
            return "Soft sounds, gentle rhythm. A lovely place to start."
        case .medium:
            return "Good choice. Velora will guide you through each part, nice and slow."
        case .hard:
            return "A few tricky sounds in here — no rush. Velora will slow it right down."
        }
    }

    // MARK: - Human Error Messages
    // One short line. Gentle. Tells them exactly what to do next.

    private func humanErrorMessage(for error: CustomTopicBuilder.BuildError) -> String {
        switch error {
        case .empty:
            return "Write something — anything you'd like to say."

        case .tooShort:
            return "Just a little more. Try at least 3 words."

        case .tooLong:
            return "A bit long — one or two sentences works best."

        case .noMeaningfulWords:
            return "English only for now. Try a sentence in English."
        }
    }
}

// MARK: - Growing Text Editor
// Expands vertically — no internal scroll.
// Keyboard dismissed by parent DragGesture (no conflict with text selection).

private struct GrowingTextEditor: UIViewRepresentable {
    @Binding var text: String
    let maxChars: Int

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = UIEdgeInsets(top: 2, left: 0, bottom: 0, right: 0)
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.returnKeyType = .default
        applyFont(to: tv)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text { uiView.text = text }
        applyFont(to: uiView)
        uiView.textColor = UIColor(AppTheme.ink)
    }

    private func applyFont(to tv: UITextView) {
        let base = UIFont.systemFont(ofSize: 15, weight: .regular)
        let descriptor = base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor
        tv.font = UIFont(descriptor: descriptor, size: 15)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let parent: GrowingTextEditor
        init(parent: GrowingTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            if textView.text.count > parent.maxChars {
                textView.text = String(textView.text.prefix(parent.maxChars))
            }
            parent.text = textView.text
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CustomTopicInputView()
    }
    .preferredColorScheme(.light)
}
