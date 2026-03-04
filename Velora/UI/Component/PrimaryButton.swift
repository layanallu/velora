//
//  PrimaryButton.swift
//  Velora
//
//  NOTE:
//  - PrimaryButton is an actual Button (interactive).
//  - PrimaryButtonLabel is a non-interactive label view.
//    Use PrimaryButtonLabel inside NavigationLink to avoid "Button inside Button" bugs.
//
//  Created by LAYAN  on 03/09/1447 AH.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            PrimaryButtonLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

/// ✅ Use this inside NavigationLink labels.
struct PrimaryButtonLabel: View {
    let title: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(AppTheme.buttonFont)
        .foregroundStyle(AppTheme.ink)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [AppTheme.mint, AppTheme.aqua],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
