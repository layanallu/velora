//
//  TopicCard.swift
//  Velora
//
//  A clean Topic-based card (replaces the old ExerciseCard).
//  - No ExerciseType.
//  - Safe, short copy.
//  - Uses the app’s design system (GlassCard + Theme).
//
//  Created by LAYAN  on 03/09/1447 AH.
//

import SwiftUI

struct TopicCard: View {
    let topic: Topic

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {

                // Small Velora presence (supportive, not loud)
                VeloraCharacterView(expression: .smile, size: 56, gaze: .down)

                VStack(alignment: .leading, spacing: 6) {
                    Text(topic.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .lineLimit(2)

                    Text(topicHint)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(0.60))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.ink.opacity(0.35))
            }
        }
    }

    private var topicHint: String {
        // Keep it psychologically safe + short.
        // (You can later map hints per topic if you want.)
        return "Short phrases • gentle pace"
    }
}

