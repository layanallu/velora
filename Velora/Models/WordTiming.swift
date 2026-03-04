//
//  WordTiming.swift
//  Velora
//
//  Offline-friendly segmentation for Karaoke + Rhythm.
//  Key UX rules implemented here:
//  ✅ Punctuation is NOT spoken and is NOT counted in timing segments.
//  ✅ Words are segmented into syllable-like chunks using a vowel-cluster heuristic.
//  ✅ Stable mapping from global "speak segment index" -> visual part/segment.
//
//  Created by Velora on 24/02/2026.
//

import Foundation

// MARK: - Parts

/// A segment inside a word (syllable-like chunk, offline heuristic).
struct SpeechSegment: Identifiable, Hashable, Codable {
    let id: String
    let text: String
}

/// Visual parts in the phrase: either a word (segmented) or punctuation (not spoken).
enum PhrasePart: Identifiable, Hashable, Codable {
    case word(WordUnit)
    case punctuation(PunctuationUnit)

    var id: String {
        switch self {
        case .word(let w): return w.id
        case .punctuation(let p): return p.id
        }
    }

    var rawText: String {
        switch self {
        case .word(let w): return w.raw
        case .punctuation(let p): return p.text
        }
    }
}

struct PunctuationUnit: Identifiable, Hashable, Codable {
    let id: String
    let text: String
}

struct WordUnit: Identifiable, Hashable, Codable {
    let id: String
    let raw: String
    let segments: [SpeechSegment]
}

// MARK: - WordTiming

struct WordTiming: Hashable, Codable {
    let phrase: String
    let parts: [PhrasePart]

    /// Total *spoken* segments (punctuation excluded).
    var totalSpeakSegments: Int {
        parts.reduce(0) { acc, part in
            switch part {
            case .word(let w): return acc + w.segments.count
            case .punctuation: return acc
            }
        }
    }

    /// Maps a global spoken segment index -> (partIndex, segmentIndexInsideWord)
    func speakPosition(for globalSpeakIndex: Int) -> (partIndex: Int, segmentIndex: Int)? {
        guard globalSpeakIndex >= 0 else { return nil }
        var cursor = 0

        for (pIndex, part) in parts.enumerated() {
            switch part {
            case .punctuation:
                continue
            case .word(let w):
                for sIndex in 0..<w.segments.count {
                    if cursor == globalSpeakIndex { return (pIndex, sIndex) }
                    cursor += 1
                }
            }
        }

        return nil
    }

    // MARK: Builder

    static func make(from phrase: String) -> WordTiming {
        let tokens = tokenizeWithPunctuation(phrase)

        var builtParts: [PhrasePart] = []
        builtParts.reserveCapacity(tokens.count)

        var wordCounter = 0
        var punctCounter = 0

        for token in tokens {
            if isPunctuation(token) {
                let p = PunctuationUnit(
                    id: "p\(punctCounter)_\(UUID().uuidString.prefix(6))",
                    text: token
                )
                builtParts.append(.punctuation(p))
                punctCounter += 1
            } else {
                let segs = segmentWord(token)
                let w = WordUnit(
                    id: "w\(wordCounter)_\(UUID().uuidString.prefix(6))",
                    raw: token,
                    segments: segs.enumerated().map { sIdx, seg in
                        SpeechSegment(
                            id: "s\(wordCounter)_\(sIdx)_\(UUID().uuidString.prefix(6))",
                            text: seg
                        )
                    }
                )
                builtParts.append(.word(w))
                wordCounter += 1
            }
        }

        return WordTiming(phrase: phrase, parts: builtParts)
    }

    // MARK: Tokenization (words + punctuation)

    /// Splits a phrase into tokens, keeping punctuation as its own token.
    /// Example: "One coffee, please." -> ["One", "coffee", ",", "please", "."]
    private static func tokenizeWithPunctuation(_ phrase: String) -> [String] {
        let chars = Array(phrase)
        var tokens: [String] = []
        var current = ""

        func flushWord() {
            let t = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { tokens.append(t) }
            current = ""
        }

        for ch in chars {
            if ch.isWhitespace {
                flushWord()
                continue
            }

            // If punctuation, flush current word then add punctuation token.
            if isPunctuationChar(ch) {
                flushWord()
                tokens.append(String(ch))
                continue
            }

            // Otherwise, keep building the word token.
            current.append(ch)
        }

        flushWord()
        return tokens
    }

    private static func isPunctuation(_ token: String) -> Bool {
        guard token.count == 1, let ch = token.first else { return false }
        return isPunctuationChar(ch)
    }

    private static func isPunctuationChar(_ ch: Character) -> Bool {
        // Keep it strict + predictable for English practice.
        return ch == "," || ch == "." || ch == "!" || ch == "?" || ch == ";" || ch == ":"
    }

    // MARK: Word Segmentation (offline heuristic)

    /// Offline heuristic:
    /// - Split at vowel-cluster boundaries (a, e, i, o, u, y)
    /// - Stable and lightweight (no network / no dictionary).
    private static func segmentWord(_ word: String) -> [String] {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [""] }

        let letters = Array(trimmed)
        let vowels = Set("aeiouyAEIOUY")

        // Keep very short words as-is for naturalness.
        if letters.count <= 3 { return [trimmed] }

        var segments: [String] = []
        var current = ""

        func flush() {
            let t = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { segments.append(t) }
            current = ""
        }

        var i = 0
        while i < letters.count {
            let ch = letters[i]
            current.append(ch)

            let isVowel = vowels.contains(ch)
            let nextIsVowel: Bool = {
                guard i + 1 < letters.count else { return false }
                return vowels.contains(letters[i + 1])
            }()

            // Break after vowel cluster ends, but not on last char.
            if isVowel && !nextIsVowel && i < letters.count - 1 {
                flush()
            }

            i += 1
        }

        flush()
        return segments.isEmpty ? [trimmed] : segments
    }
}
