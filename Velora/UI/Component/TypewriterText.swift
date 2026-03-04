//
//  TypewriterText.swift
//  Velora
//
//  Reusable "typewriter" text animation.
//  - Writes characters progressively.
//  - Tap to instantly reveal full text.
//  - Calls onFinished when completed.
//  - Supports centered/leading alignment.
//
//  Created by Velora on 27/02/2026.
//

import SwiftUI

struct TypewriterText: View {
    let text: String

    var characterInterval: TimeInterval = 0.022
    var startDelay: TimeInterval = 0.10
    var allowsTapToReveal: Bool = true

    /// Align non-bullet copy nicely (center for Velora).
    var multilineAlignment: TextAlignment = .leading

    var onFinished: (() -> Void)? = nil

    @State private var visibleCount: Int = 0
    @State private var hasRevealedAll: Bool = false
    @State private var didFireFinished: Bool = false

    var body: some View {
        Text(visibleText)
            .multilineTextAlignment(multilineAlignment)
            .frame(maxWidth: .infinity, alignment: multilineAlignment == .center ? .center : .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                guard allowsTapToReveal else { return }
                revealAll()
            }
            .onAppear { resetAndStart() }
            .onChange(of: hasRevealedAll) { _, newValue in
                guard newValue else { return }
                fireFinishedIfNeeded()
            }
            .accessibilityLabel(Text(text))
    }

    private var visibleText: String {
        if hasRevealedAll { return text }
        let count = max(0, min(visibleCount, text.count))
        return String(text.prefix(count))
    }

    private func resetAndStart() {
        visibleCount = 0
        hasRevealedAll = false
        didFireFinished = false

        guard !text.isEmpty else {
            hasRevealedAll = true
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
            tick()
        }
    }

    private func tick() {
        guard !hasRevealedAll else { return }

        if visibleCount < text.count {
            visibleCount += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + characterInterval) {
                tick()
            }
        } else {
            hasRevealedAll = true
        }
    }

    private func revealAll() {
        hasRevealedAll = true
        visibleCount = text.count
        fireFinishedIfNeeded()
    }

    private func fireFinishedIfNeeded() {
        guard !didFireFinished else { return }
        didFireFinished = true
        onFinished?()
    }
}

// MARK: - Preview

struct TypewriterText_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                Text("Title")
                    .font(AppTheme.titleFont)

                TypewriterText(
                    text: "Centered non-bullet text\nshould feel calm and clear",
                    characterInterval: 0.02,
                    startDelay: 0.10,
                    multilineAlignment: .center
                )
                .font(AppTheme.subtitleFont)
                .foregroundStyle(AppTheme.ink.opacity(0.78))
            }
            .padding(18)
            .background(AppTheme.paper.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
            .padding(20)
        }
        .preferredColorScheme(.light)
    }
}
