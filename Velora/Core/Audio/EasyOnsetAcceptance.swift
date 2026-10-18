//
//  EasyOnsetAcceptance.swift
//  Velora/Core/Audio
//
//  The decision is about the initial acoustic onset, never transcript length.
//  It does not claim to be a clinical diagnosis. Low-quality measurements are
//  inconclusive rather than "bad speech", and never become automatic passes.
//
import Foundation

enum EasyOnsetAcceptance {
    enum Decision: Equatable {
        case accepted
        case retryGentler
        case uncertain
    }

    static func classify(
        verdict: OnsetMetrics.Verdict,
        kind: OnsetMetrics.Kind,
        confidence: Float,
        score: Int,
        expectedWords: [String]
    ) -> Decision {
        guard !expectedWords.isEmpty else { return .uncertain }
        guard confidence >= 0.55 else { return .uncertain }

        switch verdict {
        case .great, .good:
            // Keep the earlier brief-word, vowel and plosive accommodations.
            // They refine evidence in an otherwise valid onset verdict; they
            // cannot turn an explicitly problematic verdict into success.
            return score >= adaptiveThreshold(for: expectedWords) - 6
                ? .accepted : .uncertain

        case .tryAgain:
            // A noisy or low-confidence onset cannot be called a hard start.
            return kind == .hard && confidence >= 0.80
                ? .retryGentler : .uncertain

        case .notDetected:
            return .uncertain
        }
    }

    private static func adaptiveThreshold(for words: [String]) -> Int {
        let first = words.first ?? ""
        let characters = words.joined(separator: " ").count
        var threshold = 50

        if words.count <= 1 && characters <= 4 { threshold -= 12 }
        else if words.count <= 2 && characters <= 10 { threshold -= 9 }

        // The adaptations present in the previous release are deliberately
        // preserved. Unlike before, a long phrase earns no automatic discount.
        if let letter = first.lowercased().first {
            if "ptkbdg".contains(letter) { threshold -= 10 }
            if "aeiou".contains(letter) { threshold += 2 }
        }
        return max(36, min(66, threshold))
    }
}
