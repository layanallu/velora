//
//  EasyOnsetExampleView.swift
//  Velora
//
//  Compact looping example for Easy Onset.
//  - "my name is ___"
//  - Continuous (connected) karaoke highlight, char-by-char.
//  - Past characters remain highlighted.
//  - Extra linger on the FIRST "m" only.
//  - Headphones icon INSIDE the gray example box.
//  - Runs max N loops, then shows a small Repeat button (CPU friendly).
//  - Tapping headphones restarts the karaoke from the beginning + plays sample audio.
//
//  Created by Velora on 27/02/2026.
//  Updated by Velora on 28/02/2026:
//  ✅ Plays bundled audio sample: "My Name Is.m4a"
//  ✅ Karaoke speed control via totalLoopDuration (default = 11s)
//

import SwiftUI

struct EasyOnsetExampleView: View {
    let onTapAudio: () -> Void

    // MARK: - Audio sample (bundle)
    var sampleFileName: String = "My Name Is"
    var sampleFileExtension: String = "m4a"

    // MARK: - Karaoke timing control
    /// Total duration for ONE full karaoke loop (start → end + holds). 
    var totalLoopDuration: TimeInterval = 6.0

    /// Portion of total duration reserved for the FIRST character linger (m).
    /// Keep it noticeable but not extreme.
    var firstCharHoldRatio: Double = 0.3

    /// Portion reserved for end hold after reaching last character.
    var endHoldRatio: Double = 0.12

    private let text: String = "my name is ___"

    @State private var idx: Int = 0
    @State private var isRunning: Bool = false

    private let maxLoops: Int = 20
    @State private var loopsDone: Int = 0
    @State private var showRepeat: Bool = false

    @State private var loopTask: Task<Void, Never>? = nil
    @StateObject private var playback = AudioPlayback()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.paper.opacity(0.60))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.ink.opacity(0.08), lineWidth: 1)
                )

            VStack(spacing: 10) {

                // ✅ Example box contains BOTH text + headphones
                HStack(spacing: 10) {
                    connectedHighlightedText
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: {
                        Haptics.tap()

                        // 🔊 Play sample audio (offline, bundled)
                        playback.playBundled(named: sampleFileName, ext: sampleFileExtension)

                        // Keep hook for any extra behavior (analytics not allowed, but you might trigger UI sync)
                        onTapAudio()

                        // Restart karaoke so it syncs with audio start
                        restartTutorial()
                    }) {
                        Image(systemName: "headphones")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.ink.opacity(0.70))
                            .frame(width: 30, height: 30)
                            .background(AppTheme.paper.opacity(0.65))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(AppTheme.ink.opacity(0.10), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Listen"))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.ink.opacity(0.04))
                )
                .padding(.horizontal, 10)

                if showRepeat {
                    Button(action: {
                        Haptics.tap()
                        restartTutorial()
                    }) {
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
        .frame(height: 96)
        .onAppear {
            guard !isRunning else { return }
            isRunning = true
            startLoop()
        }
        .onDisappear {
            stopLoop()
        }
    }

    // MARK: - Connected highlight (continuous)

    private var connectedHighlightedText: some View {
        Text(attributedConnectedHighlight())
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.ink.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .accessibilityLabel(Text(text))
    }

    private func attributedConnectedHighlight() -> AttributedString {
        var a = AttributedString(text)
        a.foregroundColor = AppTheme.ink.opacity(0.34)

        let count = max(0, text.count)
        guard count > 0 else { return a }

        let safeIdx = max(0, min(idx, count - 1))
        let highlightCount = safeIdx + 1

        let end = a.index(a.startIndex, offsetByCharacters: highlightCount)
        let range = a.startIndex..<end

        // ✅ Connected highlight from start → current
        a[range].foregroundColor = AppTheme.ink.opacity(0.92)
        a[range].backgroundColor = AppTheme.mint.opacity(0.24)

        // ✅ Current character gets stronger tint (still connected)
        let currentStart = a.index(a.startIndex, offsetByCharacters: safeIdx)
        let currentEnd = a.index(a.startIndex, offsetByCharacters: safeIdx + 1)
        let currentRange = currentStart..<currentEnd
        a[currentRange].backgroundColor = AppTheme.mint.opacity(0.42)
        a[currentRange].foregroundColor = AppTheme.ink.opacity(0.98)

        return a
    }

    // MARK: - Loop engine (max 20 loops)

    private func startLoop() {
        showRepeat = false
        loopsDone = 0
        idx = 0

        stopLoop()

        loopTask = Task { @MainActor in
            while loopsDone < maxLoops, !Task.isCancelled {

                idx = 0

                let timings = computeTimings()
                let firstHoldNs = UInt64(max(0.10, timings.firstHold) * 1_000_000_000)
                let stepNs = UInt64(max(0.03, timings.stepDelay) * 1_000_000_000)
                let endHoldNs = UInt64(max(0.10, timings.endHold) * 1_000_000_000)

                // ✅ linger on FIRST letter (m)
                try? await Task.sleep(nanoseconds: firstHoldNs)

                // Move through remaining characters
                while idx < max(0, text.count - 1), !Task.isCancelled {
                    idx += 1
                    try? await Task.sleep(nanoseconds: stepNs)
                }

                // Hold at the end to let the user "feel" completion
                try? await Task.sleep(nanoseconds: endHoldNs)

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

    private func restartTutorial() {
        stopLoop()
        withAnimation(.easeInOut(duration: 0.16)) {
            showRepeat = false
        }
        startLoop()
    }

    // MARK: - Timing math (Total duration = 11s default)

    private func computeTimings() -> (firstHold: TimeInterval, stepDelay: TimeInterval, endHold: TimeInterval) {
        let total = max(1.0, totalLoopDuration)
        let firstHold = total * max(0.0, min(0.60, firstCharHoldRatio))
        let endHold = total * max(0.0, min(0.60, endHoldRatio))

        let steps = max(1, text.count - 1) // number of moves (0 -> last)
        let remaining = max(0.1, total - firstHold - endHold)
        let stepDelay = remaining / Double(steps)

        return (firstHold, stepDelay, endHold)
    }
}

// MARK: - Preview

struct EasyOnsetExampleView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 14) {
                Text("Easy Onset Example")
                    .font(AppTheme.titleFont)

                EasyOnsetExampleView(onTapAudio: {})
                    .padding(.horizontal, 18)
            }
        }
        .preferredColorScheme(.light)
    }
}
