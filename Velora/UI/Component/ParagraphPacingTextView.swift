//
//  ParagraphPacingTextView.swift
//  Velora
//
//  ONE-BLOCK paragraph renderer
//  Visual rules:
//  ✅ Active clause = all speakable words are BLACK
//  ✅ ONLY current word is highlighted (Mint background)
//  ✅ No underline
//  ✅ Previous words NEVER highlighted
//
//  Created by Velora on 26/02/2026.
//  Updated by Velora on 26/02/2026.
//

import SwiftUI

struct ParagraphPacingTextView: View {

    struct Token: Hashable {
        let text: String
        let isSpeakable: Bool
        let isPunctuation: Bool
    }

    struct Clause: Hashable {
        let tokens: [Token]

        var speakableCount: Int {
            tokens.filter { $0.isSpeakable }.count
        }
    }

    let clauses: [Clause]
    let activeClauseIndex: Int
    let activeWordIndexInClause: Int

    var body: some View {
        Text(buildAttributed())
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineSpacing(8)
            .padding(.horizontal, 18)
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        clauses
            .flatMap { $0.tokens.map(\.text) }
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildAttributed() -> AttributedString {
        var result = AttributedString("")
        var didAppendAny = false

        for cIndex in clauses.indices {
            let clause = clauses[cIndex]
            var localSpeakableCursor = 0

            for token in clause.tokens {
                let needsLeadingSpace: Bool = {
                    if !didAppendAny { return false }
                    if token.isPunctuation { return false }
                    return true
                }()

                if needsLeadingSpace {
                    var space = AttributedString(" ")
                    space.foregroundColor = AppTheme.ink.opacity(0.18)
                    result += space
                }

                var chunk = AttributedString(token.text)

                if token.isPunctuation {
                    chunk.foregroundColor = AppTheme.ink.opacity(0.22)
                    result += chunk
                    didAppendAny = true
                    continue
                }

                // Clause state
                let isBeforeActive = (cIndex < activeClauseIndex)
                let isActive = (cIndex == activeClauseIndex)
                let isAfterActive = (cIndex > activeClauseIndex)

                if token.isSpeakable {
                    if isActive {
                        // ✅ All active clause words are BLACK
                        chunk.foregroundColor = AppTheme.ink.opacity(0.92)

                        // ✅ Only the current target word is highlighted
                        if localSpeakableCursor == activeWordIndexInClause {
                            chunk.backgroundColor = AppTheme.mint.opacity(0.38)
                            chunk.foregroundColor = AppTheme.ink.opacity(0.98)
                        }
                    } else if isBeforeActive {
                        // context: softer, but not highlighted
                        chunk.foregroundColor = AppTheme.ink.opacity(0.45)
                    } else if isAfterActive {
                        chunk.foregroundColor = AppTheme.ink.opacity(0.30)
                    }

                    localSpeakableCursor += 1
                } else {
                    chunk.foregroundColor = AppTheme.ink.opacity(0.28)
                }

                result += chunk
                didAppendAny = true
            }
        }

        return result.characters.isEmpty ? AttributedString("…") : result
    }
}

