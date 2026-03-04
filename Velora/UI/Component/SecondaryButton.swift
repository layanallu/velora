//
//  SecondaryButton.swift
//  Velora
//
//  Outlined secondary action button (Apple-style).
//  - Matches PrimaryButton sizing + typography.
//  - Uses brand gradient stroke with paper background.
//
//  Created by Velora on 26/02/2026.
//

import SwiftUI

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            SecondaryButtonLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButtonLabel: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(AppTheme.buttonFont)
        .foregroundStyle(AppTheme.ink.opacity(0.92))
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            AppTheme.paper.opacity(0.55)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [AppTheme.mint, AppTheme.aqua],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
