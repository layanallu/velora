//
//  SpeechWordMatcher.swift
//  Velora/Core/Audio
//
//  Deterministic, offline text normalization shared by Easy Onset and Rhythm.
//  Apple Speech may format the same utterance with apostrophes, expanded
//  contractions, punctuation or digits. Formatting alone must not deny a
//  valid attempt. This is intentionally NOT a general semantic paraphraser.
//

import Foundation

enum SpeechWordMatcher {
    /// Canonical lexical units. `expected` resolves inherently ambiguous
    /// contractions such as "I'd" (I would / I had) using the target phrase.
    /// Every rule is local, predictable, and usable without a network.
    static func words(from text: String, expected: [String] = []) -> [String] {
        let clean = text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")

        let pattern = #"[a-z]+(?:'[a-z]+)?|[0-9]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = clean as NSString

        return regex.matches(in: clean, range: NSRange(location: 0, length: ns.length))
            .flatMap { match -> [String] in
                let token = ns.substring(with: match.range)
                return expanded(token, expected: expected)
            }
    }

    /// Equivalent spoken forms are compared after normalization; an ordinary
    /// different word remains different. This method does not judge onset.
    static func sameWords(_ expected: String, _ recognized: String) -> Bool {
        let target = words(from: expected)
        return !target.isEmpty && target == words(from: recognized, expected: target)
    }

    private static func expanded(_ token: String, expected: [String]) -> [String] {
        if let number = Int(token), (0...20).contains(number) {
            return numberWords[number].components(separatedBy: " ")
        }
        if token == "cannot" { return ["can", "not"] }

        let irregular: [String: [String]] = [
            "can't": ["can", "not"], "won't": ["will", "not"],
            "shan't": ["shall", "not"], "ain't": ["ain", "not"],
            "let's": ["let", "us"]
        ]
        if let expansion = irregular[token] { return expansion }

        guard let apostrophe = token.firstIndex(of: "'") else { return [token] }
        let stem = String(token[..<apostrophe])
        let ending = String(token[token.index(after: apostrophe)...])

        switch ending {
        case "m": return [stem, "am"]
        case "re": return [stem, "are"]
        case "ve": return [stem, "have"]
        case "ll": return [stem, "will"]
        case "d":
            guard ["i", "you", "he", "she", "we", "they", "it", "that", "there", "who"].contains(stem) else {
                return [token]
            }
            let auxiliary = preferredAuxiliary(stem: stem, candidates: ["would", "had"], expected: expected)
            return [stem, auxiliary]
        case "s":
            // Never reinterpret possessive nouns (e.g. "cat's") as verbs.
            guard ["he", "she", "it", "that", "there", "here", "what", "who", "where", "how"].contains(stem) else {
                return [token]
            }
            let auxiliary = preferredAuxiliary(stem: stem, candidates: ["is", "has"], expected: expected)
            return [stem, auxiliary]
        case "t":
            let stems: [String: String] = [
                "don": "do", "doesn": "does", "didn": "did",
                "isn": "is", "aren": "are", "wasn": "was", "weren": "were",
                "hasn": "has", "haven": "have", "hadn": "had",
                "couldn": "could", "wouldn": "would", "shouldn": "should",
                "mustn": "must", "needn": "need"
            ]
            if let verb = stems[stem] { return [verb, "not"] }
            return [token]
        default: return [token]
        }
    }

    private static func preferredAuxiliary(stem: String, candidates: [String], expected: [String]) -> String {
        for candidate in candidates {
            for index in expected.indices where expected[index] == stem {
                if expected.indices.contains(index + 1), expected[index + 1] == candidate {
                    return candidate
                }
            }
        }
        return candidates[0]
    }

    private static let numberWords = [
        "zero", "one", "two", "three", "four", "five", "six", "seven",
        "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen",
        "fifteen", "sixteen", "seventeen", "eighteen", "nineteen", "twenty"
    ]
}
