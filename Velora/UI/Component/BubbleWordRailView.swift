//
//  BubbleWordRailView.swift
//  Velora
//
//  Bubble rail for the current clause:
//  - total = number of words in current clause
//  - progress = how many popped
//
//  Created by Velora.
//

import SwiftUI

struct BubbleWordRailView: View {
    let total: Int
    let progress: Int
    let isActive: Bool

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<max(total, 0), id: \.self) { i in
                GlossyBubbleView(
                    state: (i < progress) ? .popped : .pending,
                    size: bubbleSize,
                    animateBreath: isActive && i == progress // only the next bubble "breathes"
                )
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(AppTheme.paper.opacity(0.55))
        .clipShape(Capsule())
        .shadow(color: AppTheme.shadow, radius: 10, x: 0, y: 6)
    }

    private var bubbleSize: CGFloat {
        // Safe size on small phones.
        total >= 8 ? 18 : 22
    }
}
