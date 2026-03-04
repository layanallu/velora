//
//  TypewriterBulletList.swift
//  Velora
//
//  Bullet list where each bullet types in sequence.
//
//  Created by Velora on 27/02/2026.
//

import SwiftUI

struct TypewriterBulletList: View {
    let bullets: [String]

    var characterInterval: TimeInterval = 0.018
    var firstDelay: TimeInterval = 0.05
    var gapBetweenBullets: TimeInterval = 0.10
    var onFinished: (() -> Void)? = nil

    @State private var revealedCount: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(0..<min(revealedCount, bullets.count), id: \.self) { i in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    bulletDot
                    TypewriterText(
                        text: bullets[i],
                        characterInterval: characterInterval,
                        startDelay: i == 0 ? firstDelay : 0,
                        allowsTapToReveal: true,
                        multilineAlignment: .leading,
                        onFinished: { advanceIfNeeded(from: i) }
                    )
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.ink.opacity(0.82))
                }
            }
        }
        .onAppear {
            if revealedCount == 0 {
                revealedCount = min(1, bullets.count)
                if bullets.isEmpty { onFinished?() }
            }
        }
    }

    private var bulletDot: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [AppTheme.mint, AppTheme.aqua],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 10, height: 10)
            .shadow(color: AppTheme.shadow.opacity(0.45), radius: 4, x: 0, y: 2)
            .padding(.top, 2)
    }

    private func advanceIfNeeded(from index: Int) {
        guard index == revealedCount - 1 else { return }

        if revealedCount < bullets.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + gapBetweenBullets) {
                revealedCount += 1
            }
        } else {
            onFinished?()
        }
    }
}
