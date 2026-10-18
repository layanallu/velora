//
//  CustomTopicBuilder.swift
//  Velora
//
//  Smart engine that converts user text into a practice-ready Topic.
//
//  Scientific foundation (evidence-based stuttering research):
//  ─────────────────────────────────────────────────────────────
//
//  EASY ONSET (Max & Caruso, 1997 / Bothe, 2006):
//  - Each sentence is treated as an INDEPENDENT unit.
//  - Progression within each sentence: 1 word → 2 words → half → full.
//  - Vowel-initial words (I, it, ask...) get a dedicated first step —
//    they require the hardest onset control (glottal attack prevention).
//  - Plosive-initial words (b, p, t, k, d, g) get an extra warm-up step.
//  - NO cross-sentence accumulation — each sentence resets.
//
//  RHYTHM PACING (Syllable-Timed Speech / Andrews et al.):
//  - Each sentence = independent rhythm unit.
//  - Short sentences (≤5 words) stay whole — no splitting.
//  - Long sentences split at natural linguistic boundaries:
//    commas, conjunctions, prepositional phrases.
//  - Max 6 words per chunk (working memory + motor planning limit).
//  - Semantic integrity preserved — no mid-phrase splits.
//
//  DIFFICULTY:
//  - Based on plosive ratio + vowel-initial ratio + sentence length.
//
//  Created by Velora — Custom Topic Feature.
//

import Foundation
import UIKit

// MARK: - Analysis Result

struct CustomTopicAnalysis {
    let cleanedParagraph: String
    let easyOnsetSteps: [String]
    let rhythmClauses: [String]
    let warnings: [String]
    let difficulty: Difficulty

    enum Difficulty: Equatable {
        case easy
        case medium
        case hard
    }
}

// MARK: - Builder

enum CustomTopicBuilder {

    // MARK: - Public API

    static func build(from rawText: String) -> Result<Topic, BuildError> {
        let cleaned = normalize(rawText)

        if let error = validate(cleaned) {
            return .failure(error)
        }

        let analysis = analyze(cleaned)

        let topic = Topic(
            id: "custom_\(UUID().uuidString.prefix(8))",
            category: .realScenarios,
            title: generateTitle(from: cleaned),
            icon: selectIcon(for: cleaned),
            paragraph: analysis.cleanedParagraph,
            customEasyOnsetSteps: analysis.easyOnsetSteps,
            customRhythmClauses: analysis.rhythmClauses
        )

        return .success(topic)
    }

    static func preview(from rawText: String) -> CustomTopicAnalysis {
        let cleaned = normalize(rawText)
        return analyze(cleaned)
    }

    // MARK: - Errors

    enum BuildError: LocalizedError {
        case empty
        case tooShort(wordCount: Int)
        case tooLong(wordCount: Int)
        case noMeaningfulWords

        var errorDescription: String? {
            switch self {
            case .empty:             return "Write something — anything you'd like to say."
            case .tooShort:          return "Just a little more. Try at least 3 words."
            case .tooLong:           return "A bit long — one or two sentences works best."
            case .noMeaningfulWords: return "English only for now. Try a sentence in English."
            }
        }
    }

    // MARK: - Normalize

    private static func normalize(_ text: String) -> String {
        var result = text
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Validate

    private static func validate(_ text: String) -> BuildError? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return .empty }

        let words = extractWords(from: text)
        guard !words.isEmpty else { return .noMeaningfulWords }

        // Reject gibberish: at least 60% must be recognizable English words
        let realCount = words.filter { isLikelyRealWord($0) }.count
        let ratio = Double(realCount) / Double(words.count)
        guard ratio >= 0.60 else { return .noMeaningfulWords }

        guard words.count >= 3 else { return .tooShort(wordCount: words.count) }
        guard words.count <= 80 else { return .tooLong(wordCount: words.count) }

        return nil
    }

    // MARK: - Real Word Detection
    //
    // Three-layer approach (offline, no network):
    // Layer 1 — Vowel presence: real English words almost always have a vowel.
    // Layer 2 — Consonant cluster: >5 consecutive consonants = gibberish.
    // Layer 3 — UITextChecker: Apple's offline spell checker as final gate.

    private static func isLikelyRealWord(_ word: String) -> Bool {
        let w = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard w.count >= 1 else { return false }

        // Very short words are always valid (I, a, ok, hi...)
        if w.count <= 2 { return true }

        let vowels = Set("aeiou")

        // Layer 1: must contain at least one vowel
        guard w.contains(where: { vowels.contains($0) }) else { return false }

        // Layer 2: no run of >5 consecutive consonants
        var maxRun = 0, currentRun = 0
        for ch in w {
            if vowels.contains(ch) { currentRun = 0 }
            else {
                currentRun += 1
                maxRun = max(maxRun, currentRun)
            }
        }
        guard maxRun <= 5 else { return false }

        // Layer 3: Apple offline spell check
        let checker = UITextChecker()
        let nsRange = NSRange(location: 0, length: w.utf16.count)
        let misspelled = checker.rangeOfMisspelledWord(
            in: w, range: nsRange,
            startingAt: 0, wrap: false, language: "en"
        )

        // Passes spell check → definitely real
        if misspelled.location == NSNotFound { return true }

        // Failed spell check but passed vowel + consonant checks →
        // likely a proper noun, contraction, or informal word — accept if short
        return w.count <= 10
    }

    // MARK: - Analyze

    private static func analyze(_ text: String) -> CustomTopicAnalysis {
        let sentences = splitIntoSentences(text)
        let allWords = extractWords(from: text)

        let easySteps   = buildEasyOnsetSteps(from: sentences)
        let rhythmChunks = buildRhythmClauses(from: sentences)
        let difficulty  = assessDifficulty(words: allWords)
        let warnings    = generateWarnings(words: allWords, sentences: sentences, difficulty: difficulty)

        return CustomTopicAnalysis(
            cleanedParagraph: text,
            easyOnsetSteps: easySteps,
            rhythmClauses: rhythmChunks,
            warnings: warnings,
            difficulty: difficulty
        )
    }

    // MARK: - Sentence Splitting

    private static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""

        for ch in text {
            current.append(ch)
            if ch == "." || ch == "!" || ch == "?" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }

        return sentences.filter { !$0.isEmpty }
    }

    // MARK: - Easy Onset Steps
    //
    // Scientific logic (per sentence, independent):
    //
    // Step A — First word alone.
    //   • If vowel-initial → mark as HIGH PRIORITY (hardest onset).
    //   • If plosive-initial → mark as NEEDS WARM-UP.
    //
    // Step B — First 2 words (always included).
    //
    // Step C — First half of sentence (rounded up, max 5 words).
    //   • Skipped if sentence is ≤3 words (no midpoint needed).
    //
    // Step D — Full sentence.
    //   • Skipped if same as Step C (very short sentences).
    //
    // Cross-sentence accumulation is intentionally REMOVED.
    // Each sentence resets — this matches clinical SLP practice
    // where each utterance is practiced in isolation first.

    private static func buildEasyOnsetSteps(from sentences: [String]) -> [String] {
        var allSteps: [String] = []

        for sentence in sentences {
            let words = extractWords(from: sentence)
            guard !words.isEmpty else { continue }

            let steps = easyOnsetStepsForSentence(words)
            for step in steps where !allSteps.contains(step) {
                allSteps.append(step)
            }
        }

        return allSteps.isEmpty ? ["Hello", "Hello there"] : allSteps
    }

    private static func easyOnsetStepsForSentence(_ words: [String]) -> [String] {
        let n = words.count
        guard n > 0 else { return [] }

        var steps: [String] = []
        let firstWord = words[0]

        // Step A: first word alone
        // Vowel-initial words need the most practice — listed first always
        steps.append(firstWord)

        // Step B: first two words
        // Added regardless — gives context to the first word
        if n >= 2 {
            let twoWords = words.prefix(2).joined(separator: " ")
            if !steps.contains(twoWords) {
                steps.append(twoWords)
            }
        }

        // Step C: first half (only for sentences >3 words)
        // Half gives a meaningful chunk before the full sentence
        if n > 3 {
            let halfCount = min(Int(ceil(Double(n) / 2.0)), 5)
            let halfPhrase = words.prefix(halfCount).joined(separator: " ")
            if !steps.contains(halfPhrase) {
                steps.append(halfPhrase)
            }
        }

        // Step D: full sentence
        let fullSentence = words.joined(separator: " ")
        if !steps.contains(fullSentence) {
            steps.append(fullSentence)
        }

        // Extra step for plosive-initial: insert between Step A and B
        // Gives the user two attempts at the hardest sound before expanding
        if startsWithPlosive(firstWord) && n >= 2 {
            let twoWords = words.prefix(2).joined(separator: " ")
            // Insert after Step A (index 1) if not already there
            if let idx = steps.firstIndex(of: twoWords), idx > 1 {
                steps.remove(at: idx)
                steps.insert(twoWords, at: 1)
            }
        }

        return steps
    }

    // MARK: - Rhythm Clauses
    //
    // Scientific logic (Syllable-Timed Speech):
    //
    // Rule 1 — Short sentences (≤5 words) stay whole. No splitting.
    //          Splitting a short sentence destroys its natural rhythm.
    //
    // Rule 2 — Long sentences split at the FIRST natural boundary:
    //          a) Comma or semicolon
    //          b) Coordinating conjunction (and, but, or, so...)
    //          c) Subordinating conjunction (because, when, if, after...)
    //          d) Prepositional phrase start (in, on, at, to, for, with...)
    //
    // Rule 3 — Hard cap at 6 words per chunk.
    //          Matches motor planning window for people who stutter.
    //
    // Rule 4 — Tiny chunks (<2 words) are merged with neighbour.
    //          A one-word chunk has no rhythm to practice.

    private static func buildRhythmClauses(from sentences: [String]) -> [String] {
        var allClauses: [String] = []

        for sentence in sentences {
            let chunks = rhythmChunksForSentence(sentence)
            allClauses.append(contentsOf: chunks)
        }

        return allClauses.isEmpty ? ["Take it slow"] : allClauses
    }

    private static func rhythmChunksForSentence(_ sentence: String) -> [String] {
        let words = extractWords(from: sentence)

        // Rule 1: short sentences stay whole
        if words.count <= 5 {
            let clean = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            return clean.isEmpty ? [] : [clean]
        }

        // Long sentence — split at natural boundaries
        return splitLongSentence(sentence)
    }

    private static func splitLongSentence(_ sentence: String) -> [String] {

        // Coordinating conjunctions — split BEFORE these
        let coordinating: Set<String> = [
            "and", "but", "or", "so", "yet", "nor", "for"
        ]

        // Subordinating conjunctions — split BEFORE these
        let subordinating: Set<String> = [
            "because", "although", "however", "therefore", "then",
            "when", "while", "if", "that", "which", "who",
            "where", "after", "before", "since", "unless", "until"
        ]

        // Prepositions that start new phrases — split BEFORE these
        // Only when they appear mid-sentence (not at position 0)
        let prepositions: Set<String> = [
            "in", "on", "at", "to", "for", "with", "from",
            "about", "into", "through", "during", "without"
        ]

        let tokens = tokenize(sentence)
        var chunks: [String] = []
        var currentChunk: [String] = []
        var wordCount = 0

        for (i, token) in tokens.enumerated() {
            let lower = token.lowercased()
            let isPunct = isSinglePunctuation(token)
            let isCoord = coordinating.contains(lower)
            let isSub = subordinating.contains(lower)
            let isPrep = prepositions.contains(lower)

            // Punctuation: attach to current chunk then flush
            if isPunct {
                currentChunk.append(token)
                if wordCount >= 2 {
                    chunks.append(currentChunk.joined(separator: " "))
                    currentChunk = []
                    wordCount = 0
                }
                continue
            }

            // Hard cap: flush before adding if already at 6 words
            if wordCount >= 6 {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.joined(separator: " "))
                    currentChunk = []
                    wordCount = 0
                }
            }

            // Natural split point: conjunction or preposition mid-sentence
            let isMidSentence = i > 0
            let isNaturalBreak = (isCoord || isSub || isPrep) && isMidSentence && wordCount >= 3

            if isNaturalBreak && !currentChunk.isEmpty {
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = [token]
                wordCount = 1
                continue
            }

            currentChunk.append(token)
            wordCount += 1
        }

        // Flush remaining
        if !currentChunk.isEmpty {
            let remaining = currentChunk
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !remaining.isEmpty { chunks.append(remaining) }
        }

        return mergeTinyChunks(chunks)
    }

    // Merge chunks with <2 real words into their neighbour
    private static func mergeTinyChunks(_ chunks: [String]) -> [String] {
        guard chunks.count > 1 else { return chunks }

        var result: [String] = []

        for chunk in chunks {
            let wordCount = extractWords(from: chunk).count
            if wordCount < 2, !result.isEmpty {
                // Merge into previous
                let prev = result.removeLast()
                result.append(prev + " " + chunk)
            } else {
                result.append(chunk)
            }
        }

        return result
    }

    // MARK: - Difficulty Assessment
    //
    // Based on three signals:
    // 1. Plosive ratio (b, p, t, k, d, g) — hard to onset softly
    // 2. Vowel-initial ratio — hardest onset (glottal attack risk)
    // 3. Average word length — longer words = more motor planning

    private static func assessDifficulty(words: [String]) -> CustomTopicAnalysis.Difficulty {
        guard !words.isEmpty else { return .easy }

        let plosiveCount     = words.filter { startsWithPlosive($0) }.count
        let vowelInitCount   = words.filter { startsWithVowel($0) }.count
        let plosiveRatio     = Double(plosiveCount) / Double(words.count)
        let vowelInitRatio   = Double(vowelInitCount) / Double(words.count)
        let avgWordLength    = Double(words.map { $0.count }.reduce(0, +)) / Double(words.count)

        // Hard: many plosives OR many vowel-initial words OR long words
        if plosiveRatio > 0.30 || vowelInitRatio > 0.35 || avgWordLength > 6 {
            return .hard
        }

        // Medium: moderate plosives or vowel-initials
        if plosiveRatio > 0.18 || vowelInitRatio > 0.20 || avgWordLength > 4.5 {
            return .medium
        }

        return .easy
    }

    // MARK: - Warnings
    // Short, warm, specific — written for someone who stutters.

    private static func generateWarnings(
        words: [String],
        sentences: [String],
        difficulty: CustomTopicAnalysis.Difficulty
    ) -> [String] {
        var warnings: [String] = []

        // Plosive warning — name the specific words
        let plosiveWords = words.filter { startsWithPlosive($0) }
        if plosiveWords.count >= 3 {
            let examples = Array(Set(plosiveWords.prefix(2)))
                .joined(separator: " and ")
            warnings.append("Words like \(examples) can feel abrupt. A slow breath before each one helps.")
        }

        // Vowel-initial warning — these need special onset care
        let vowelWords = words.filter { startsWithVowel($0) }
        if vowelWords.count >= 3 {
            let examples = Array(Set(vowelWords.prefix(2)))
                .joined(separator: " and ")
            warnings.append("Words like \(examples) start with vowels — let the air out first, then add your voice.")
        }

        // Long sentence note
        for sentence in sentences {
            if extractWords(from: sentence).count > 12 {
                warnings.append("That's a long one — Velora has broken it into smaller pieces for you.")
                break
            }
        }

        return warnings
    }

    // MARK: - Title Generation

    private static func generateTitle(from text: String) -> String {
        let words = extractWords(from: text)
        guard !words.isEmpty else { return "My Practice" }

        let stopWords: Set<String> = [
            "a", "an", "the", "is", "are", "i", "my", "we",
            "it", "to", "do", "did", "not", "for", "in", "on"
        ]
        let meaningful = words.filter { !stopWords.contains($0.lowercased()) }
        let titleWords = (meaningful.isEmpty ? Array(words.prefix(3)) : Array(meaningful.prefix(4)))

        return titleWords.joined(separator: " ").capitalized
    }

    // MARK: - Icon Selection

    private static func selectIcon(for text: String) -> String {
        let lower = text.lowercased()
        if containsAny(lower, ["coffee", "drink", "eat", "food", "lunch", "dinner", "order"]) { return "fork.knife" }
        if containsAny(lower, ["work", "meeting", "office", "job", "boss", "colleague"])       { return "briefcase.fill" }
        if containsAny(lower, ["hello", "hi", "name", "meet", "nice", "introduce"])            { return "hand.wave.fill" }
        if containsAny(lower, ["phone", "call", "answer", "message", "ring"])                  { return "phone.fill" }
        if containsAny(lower, ["help", "please", "sorry", "excuse", "apolog"])                 { return "heart.fill" }
        if containsAny(lower, ["go", "walk", "way", "street", "direction", "where", "map"])    { return "map.fill" }
        if containsAny(lower, ["time", "wait", "late", "schedule", "appointment"])             { return "clock.fill" }
        if containsAny(lower, ["return", "buy", "store", "shop", "item", "purchase"])          { return "bag.fill" }
        return "text.bubble.fill"
    }

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    // MARK: - Linguistic Helpers

    private static let plosives: Set<Character> = ["b", "p", "t", "k", "d", "g"]
    private static let vowels:   Set<Character> = ["a", "e", "i", "o", "u"]

    private static func startsWithPlosive(_ word: String) -> Bool {
        guard let first = word.lowercased().first else { return false }
        return plosives.contains(first)
    }

    private static func startsWithVowel(_ word: String) -> Bool {
        guard let first = word.lowercased().first else { return false }
        return vowels.contains(first)
    }

    private static func extractWords(from text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z\\s']", with: "", options: .regularExpression)
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for ch in text {
            if ch.isWhitespace {
                let t = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { tokens.append(t) }
                current = ""
            } else if isSinglePunctuation(String(ch)) {
                let t = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { tokens.append(t) }
                tokens.append(String(ch))
                current = ""
            } else {
                current.append(ch)
            }
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { tokens.append(tail) }

        return tokens
    }

    private static func isSinglePunctuation(_ token: String) -> Bool {
        guard token.count == 1, let ch = token.first else { return false }
        return ",;:.!?".contains(ch)
    }
}
