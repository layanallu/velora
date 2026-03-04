//
//  GlassCard.swift
//  Velora
//
//  Glass card container (reusable).
//  ✅ Updated: supports "compact" style without duplicating components.
//  ✅ Default values preserve existing UI unless you opt-in.
//
//  Created by LAYAN  on 03/09/1447 AH.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    private let content: Content

    private let contentPadding: CGFloat
    private let cornerRadius: CGFloat
    private let shadowRadius: CGFloat
    private let shadowX: CGFloat
    private let shadowY: CGFloat

    init(
        contentPadding: CGFloat = 16,
        cornerRadius: CGFloat = 22,
        shadowRadius: CGFloat = 18,
        shadowX: CGFloat = 0,
        shadowY: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.contentPadding = contentPadding
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowX = shadowX
        self.shadowY = shadowY
    }

    var body: some View {
        content
            .padding(contentPadding)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: AppTheme.shadow, radius: shadowRadius, x: shadowX, y: shadowY)
    }
}
