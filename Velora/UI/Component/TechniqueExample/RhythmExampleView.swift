//
//  RhythmExampleView.swift
//  Velora
//
//  Compact looping example for Rhythm Pacing.
//  - Mimics the real exercise: ONE bubble = ONE word.
//  - Bubbles pop word-by-word while the highlighted word advances.
//  - Small, modal-friendly sizing.
//  - Runs max 20 loops, then shows a small Repeat button (CPU friendly).
//  - No audio button (audio is only for Easy Onset).
//
//  Updated by Velora on 27/02/2026.
//

import SwiftUI

struct RhythmExampleView: View {

    // Simple demo phrase (3 bubbles)
    private let demoWords: [String] = ["my", "name", "is"]

    @State private var popped: Int = 0
    @State private var activeWordIndex: Int = 0

    private let maxLoops: Int = 20
    @State private var loopsDone: Int = 0
    @State private var showRepeat: Bool = false
    @State private var loopTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.paper.opacity(0.60))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.ink.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 8) {

                // ✅ Smaller bubble rail
                compactBubbleRail
                    .padding(.horizontal, 10)

                // ✅ Words are ALWAYS black (no gray)
                HStack(spacing: 8) {
                    ForEach(demoWords.indices, id: \.self) { i in
                        Text(demoWords[i])
                            .font(.system(size: 16.5, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.ink.opacity(0.92)) // ✅ always black
                            .padding(.vertical, 5)
                            .padding(.horizontal, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(i == activeWordIndex ? AppTheme.mint.opacity(0.36) : Color.clear)
                            )
                            .animation(.easeInOut(duration: 0.18), value: activeWordIndex)
                    }
                }
                .padding(.horizontal, 10)

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
            .padding(.vertical, 10)
        }
        .frame(height: 102) // ✅ أصغر شوي (كان 112)
        .onAppear { startLoop() }
        .onDisappear { stopLoop() }
    }

    // MARK: - Compact rail

    private var compactBubbleRail: some View {
        HStack(spacing: 7) {
            ForEach(demoWords.indices, id: \.self) { i in
                GlossyBubbleView(
                    state: (i < popped) ? .popped : .pending,
                    size: 16.5,                 // ✅ أصغر شوي
                    animateBreath: (i == popped) // next bubble breathes
                )
            }
        }
        .padding(.vertical, 8)     // ✅ أقل
        .padding(.horizontal, 10)  // ✅ أقل
        .background(AppTheme.ink.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Loop engine (slower + calmer)

    private func startLoop() {
        showRepeat = false
        loopsDone = 0
        popped = 0
        activeWordIndex = 0

        stopLoop()

        loopTask = Task { @MainActor in
            while loopsDone < maxLoops, !Task.isCancelled {

                // Start of loop (slower settle)
                popped = 0
                activeWordIndex = 0
                try? await Task.sleep(nanoseconds: 420_000_000)

                // Pop word-by-word (calmer pacing)
                for i in demoWords.indices {
                    if Task.isCancelled { break }

                    activeWordIndex = i

                    // linger so user can "feel" the beat
                    try? await Task.sleep(nanoseconds: 420_000_000)

                    popped = i + 1
                    Haptics.tap()

                    // calm spacing between words
                    try? await Task.sleep(nanoseconds: 380_000_000)
                }

                // end pause (slower)
                try? await Task.sleep(nanoseconds: 650_000_000)
                loopsDone += 1
            }

            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.20)) {
                    showRepeat = true
                }
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }

    private func restart() {
        stopLoop()
        withAnimation(.easeInOut(duration: 0.16)) {
            showRepeat = false
        }
        startLoop()
    }
}

// MARK: - Preview

struct RhythmExampleView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Rhythm Example")
                    .font(AppTheme.titleFont)

                RhythmExampleView()
                    .padding(.horizontal, 18)
            }
        }
        .preferredColorScheme(.light)
    }
}
