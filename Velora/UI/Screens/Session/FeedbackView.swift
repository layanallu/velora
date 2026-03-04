//
//  FeedbackView.swift
//  Velora
//
//  Official Feedback Screen.
//  - Clean, minimal, supportive.
//  - Tap Velora to switch into "Playback Orb" mode.
//  - In Playback mode: tap toggles play/pause.
//  - If user pauses OR audio finishes: auto-return to Velora.
//  - Layout fix: underHeroText lives inside the hero container (no weird gap).
//  - Visual fix: radial alpha mask to remove “square layer” feel around Canvas glow.
//
//  ✅ Navigation Fix (28/02/2026):
//  - Home button resets NavigationStack via AppRouter (prevents resuming old Topic).
//
//  ✅ Performance Fix (28/02/2026):
//  - Home reset is dispatched async after pausing playback & exiting orb,
//    avoiding SwiftUI render conflicts (prevents hangs).
//
//  Updated by Velora on 28/02/2026:
//  ✅ Removed "We’ll enable..." message when no recording.
//

import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    /// ✅ Provided by RootView (central router)
    @EnvironmentObject private var router: AppRouter

    let record: SessionRecord

    var onRepeat: (() -> Void)? = nil
    var onBackHome: (() -> Void)? = nil

    @State private var isPlaybackMode: Bool = false
    @StateObject private var playback = AudioPlayback()

    // Hero sizing:
    private let heroCanvasSize: CGFloat = 220
    private let heroVisualSize: CGFloat = 170

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer(minLength: 12)

                // MARK: - Hero Container
                VStack(spacing: -10) {
                    Button {
                        Haptics.tap()
                        handleHeroTap()
                    } label: {
                        ZStack {
                            if isPlaybackMode {
                                orbView
                                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                            } else {
                                VeloraCharacterView(
                                    expression: veloraExpression,
                                    size: heroVisualSize,
                                    gaze: .center,
                                    motionStyle: .subtle
                                )
                                .frame(width: heroVisualSize, height: heroVisualSize)
                                .transition(.opacity.combined(with: .scale(scale: 1.02)))
                            }
                        }
                        .frame(width: heroCanvasSize, height: heroCanvasSize)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Velora Playback")

                    // ✅ Only show the line if not empty (prevents weird gap)
                    if underHeroText.isEmpty == false {
                        Text(underHeroText)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.ink.opacity(0.60))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    }
                }
                .padding(.bottom, 6)

                GlassCard {
                    VStack(spacing: 12) {
                        Text("Feedback")
                            .font(AppTheme.titleFont)
                            .foregroundStyle(AppTheme.ink)

                        Text(record.topicTitle)
                            .font(AppTheme.subtitleFont)
                            .foregroundStyle(AppTheme.ink.opacity(0.65))
                            .multilineTextAlignment(.center)

                        VStack(spacing: 10) {
                            scoreRow(title: "Smoothness", value: record.smoothnessScore)
                            scoreRow(title: "Rhythm", value: record.rhythmScore)
                            scoreRow(title: "Confidence", value: record.confidenceScore)
                        }
                        .padding(.top, 6)

                        Text(record.suggestion)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.ink.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)

                        Divider().opacity(0.25)

                        VStack(spacing: 10) {
                            PrimaryButton(title: "Repeat", systemImage: "arrow.clockwise") {
                                Haptics.tap()
                                onRepeat?() ?? dismiss()
                            }

                            SecondaryButton(title: "Home", systemImage: "house.fill") {
                                Haptics.tap()
                                goHomeHardResetSafely()
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)

                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { preparePlaybackIfPossible() }
        .onDisappear { playback.pause() }
        .onChange(of: playback.didFinish) { finished in
            guard finished else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                isPlaybackMode = false
            }
        }
    }

    // MARK: - Safe Home Reset (prevents hangs)

    private func goHomeHardResetSafely() {
        // 1) Stop heavy things first (audio + orb)
        playback.pause()
        isPlaybackMode = false

        // 2) Reset stack safely on next runloop tick
        DispatchQueue.main.async {
            if let onBackHome {
                onBackHome()
            } else {
                router.goHome()
            }
        }
    }

    // MARK: - Orb view

    private var orbView: some View {
        WaveformMiniView(level: Float(playback.level), isActive: playback.isPlaying)
            .frame(width: heroCanvasSize, height: heroCanvasSize)
            .compositingGroup()
            .mask {
                RadialGradient(
                    colors: [
                        .black.opacity(1.0),
                        .black.opacity(1.0),
                        .black.opacity(0.35),
                        .black.opacity(0.0)
                    ],
                    center: .center,
                    startRadius: heroCanvasSize * 0.04,
                    endRadius: heroCanvasSize * 0.62
                )
                .frame(width: heroCanvasSize, height: heroCanvasSize)
            }
    }

    // MARK: - UI strings

    private var underHeroText: String {
        // ✅ If no recording, show nothing (clean)
        guard record.audioFilename != nil else { return "" }

        if isPlaybackMode {
            return playback.isPlaying ? "Playing your Rhythm…" : "Tap me to listen."
        }

        return "Tap me to listen."
    }

    private var veloraExpression: BubbleExpression {
        let avg = (record.smoothnessScore + record.rhythmScore + record.confidenceScore) / 3
        if avg >= 80 { return .smile }
        if avg >= 55 { return .neutral }
        return .focused
    }

    private func scoreRow(title: String, value: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)

            Spacer()

            Text("\(value)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.ink)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    LinearGradient(
                        colors: [AppTheme.mint, AppTheme.aqua],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
        }
    }

    // MARK: - Hero behavior

    private func handleHeroTap() {
        guard record.audioFilename != nil else { return }

        if isPlaybackMode {
            if playback.isPlaying {
                playback.pause()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.90)) {
                    isPlaybackMode = false
                }
            } else {
                playback.play()
            }
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                isPlaybackMode = true
            }
            playback.play()
        }
    }

    // MARK: - Playback wiring

    private func preparePlaybackIfPossible() {
        guard let filename = record.audioFilename else { return }
        let url = audioURL(for: filename)
        if FileManager.default.fileExists(atPath: url.path) {
            playback.load(url: url)
        }
    }

    private func audioURL(for filename: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docsURL = docs
            .appendingPathComponent("VeloraRecordings", isDirectory: true)
            .appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: docsURL.path) {
            return docsURL
        }

        let name = (filename as NSString).deletingPathExtension
        let ext  = (filename as NSString).pathExtension.isEmpty ? "caf" : (filename as NSString).pathExtension

        if let bundleURL = Bundle.main.url(forResource: name, withExtension: ext) {
            return bundleURL
        }

        return docsURL
    }
}

// MARK: - Preview
#Preview {
    let router = AppRouter()

    return NavigationStack {
        FeedbackView(
            record: SessionRecord.make(
                topicID: "demo_topic",
                topicTitle: "Ordering a coffee",
                topicCategoryRaw: "realScenarios",
                smoothness: 82,
                rhythm: 88,
                confidence: 79,
                suggestion: "That was calm and steady. Keep that gentle start.",
                audioFilename: "My Name Is.m4a"
            ),
            onRepeat: {},
            onBackHome: { router.goHome() }
        )
    }
    .environmentObject(router)
    .preferredColorScheme(.light)
}
