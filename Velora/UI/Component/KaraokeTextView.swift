//
//  KaraokeTextView.swift
//  Velora
//
//  - KaraokeTextView: Rhythm segment highlighting.
//  - EasyOnsetKaraokeTextView: Guided character highlight for Easy Onset.
//
//  ✅ Guided Karaoke (Easy Onset):
//  - Tutorial: auto-plays.
//  - Practice: replays the same guide animation, starting when user begins speaking.
//  - Onset cluster (first group of letters) is intentionally slowed so user learns where to linger.
//
//  Updated by Velora on 26/02/2026.
//

import SwiftUI

// MARK: - Rhythm Karaoke (kept)

enum SegmentVisualState: Equatable {
    case upcoming
    case current
    case done
    case skipped
}

struct KaraokeTextView: View {
    let timing: WordTiming
    let currentGlobalSpeakSegment: Int
    let states: [SegmentVisualState]

    var body: some View {
        Text(attributedPhrase())
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineSpacing(8)
            .padding(.horizontal, 18)
            .accessibilityLabel(timing.phrase)
    }

    private func attributedPhrase() -> AttributedString {
        var result = AttributedString("")
        var speakCursor = 0

        for idx in timing.parts.indices {
            let part = timing.parts[idx]
            let nextPart: PhrasePart? = (idx + 1 < timing.parts.count) ? timing.parts[idx + 1] : nil

            switch part {
            case .punctuation(let p):
                var pAttr = AttributedString(p.text)
                pAttr.foregroundColor = AppTheme.ink.opacity(0.20)
                result += pAttr

                if case .word = nextPart {
                    var space = AttributedString(" ")
                    space.foregroundColor = AppTheme.ink.opacity(0.15)
                    result += space
                }

            case .word(let w):
                for sIndex in 0..<w.segments.count {
                    let segText = w.segments[sIndex].text
                    var segAttr = AttributedString(segText)

                    let state: SegmentVisualState = {
                        if speakCursor == currentGlobalSpeakSegment { return .current }
                        if speakCursor < currentGlobalSpeakSegment { return states[safe: speakCursor] ?? .done }
                        return states[safe: speakCursor] ?? .upcoming
                    }()

                    applyStyle(&segAttr, state: state)
                    result += segAttr
                    speakCursor += 1
                }

                if case .word = nextPart {
                    var space = AttributedString(" ")
                    space.foregroundColor = AppTheme.ink.opacity(0.15)
                    result += space
                }
            }
        }

        return result
    }

    private func applyStyle(_ attr: inout AttributedString, state: SegmentVisualState) {
        switch state {
        case .upcoming:
            attr.foregroundColor = AppTheme.ink.opacity(0.30)
        case .current:
            attr.foregroundColor = AppTheme.ink.opacity(0.98)
            attr.backgroundColor = AppTheme.mint.opacity(0.38)
        case .done:
            attr.foregroundColor = AppTheme.ink.opacity(0.70)
            attr.backgroundColor = AppTheme.mint.opacity(0.16)
        case .skipped:
            attr.foregroundColor = AppTheme.ink.opacity(0.58)
            attr.backgroundColor = AppTheme.aqua.opacity(0.18)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

// MARK: - Easy Onset Karaoke (GUIDED)

struct EasyOnsetKaraokeTextView: View {

    enum Mode: Equatable {
        case tutorial(phrase: String, totalDuration: Double)
        case guidedPractice(
            phrase: String,
            isActive: Bool,
            startToken: UUID,
            mismatch: Bool,
            totalDuration: Double
        )
    }

    let mode: Mode

    @State private var progress01: CGFloat = 0
    @State private var lastStartToken: UUID = UUID()
    @State private var isAnimatingNow: Bool = false

    var body: some View {
        Text(buildAttributed())
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineSpacing(8)
            .padding(.horizontal, 18)
            .onAppear { syncAnimationState() }
            .onChange(of: mode) { _ in syncAnimationState() }
            .accessibilityLabel(accessibilityPhrase)
    }

    private var accessibilityPhrase: String {
        switch mode {
        case let .tutorial(phrase, _): return phrase
        case let .guidedPractice(phrase, _, _, _, _): return phrase
        }
    }

    private func syncAnimationState() {
        switch mode {
        case .tutorial:
            startAnimation(forceRestart: true)

        case let .guidedPractice(_, isActive, startToken, _, _):
            // Restart only when:
            // - user started speaking (isActive)
            // - AND the attempt token changed (new attempt or first start)
            if isActive {
                let shouldRestart = (startToken != lastStartToken) || (isAnimatingNow == false)
                startAnimation(forceRestart: shouldRestart, newToken: startToken)
            } else {
                // idle state (no movement)
                isAnimatingNow = false
                progress01 = 0
            }
        }
    }

    private func startAnimation(forceRestart: Bool, newToken: UUID? = nil) {
        if let t = newToken { lastStartToken = t }

        guard forceRestart else { return }

        isAnimatingNow = true
        progress01 = 0

        let total: Double = {
            switch mode {
            case let .tutorial(_, totalDuration): return totalDuration
            case let .guidedPractice(_, _, _, _, totalDuration): return totalDuration
            }
        }()

        withAnimation(.linear(duration: max(total, 0.25))) {
            progress01 = 1
        }
    }

    private func buildAttributed() -> AttributedString {
        switch mode {

        case let .tutorial(phrase, total):
            return attributedGuided(
                phrase: phrase,
                progress01: progress01,
                mismatch: false,
                totalSeconds: total
            )

        case let .guidedPractice(phrase, isActive, _, mismatch, total):
            if mismatch {
                var a = AttributedString(phrase)
                a.foregroundColor = AppTheme.ink.opacity(0.92)
                a.backgroundColor = AppTheme.aqua.opacity(0.18)
                return a
            }

            guard isActive else {
                var a = AttributedString(phrase)
                a.foregroundColor = AppTheme.ink.opacity(0.92)
                return a
            }

            return attributedGuided(
                phrase: phrase,
                progress01: progress01,
                mismatch: false,
                totalSeconds: total
            )
        }
    }

    private func attributedGuided(
        phrase: String,
        progress01: CGFloat,
        mismatch: Bool,
        totalSeconds _: Double
    ) -> AttributedString {

        var a = AttributedString(phrase)
        a.foregroundColor = AppTheme.ink.opacity(0.92)

        if mismatch {
            a.backgroundColor = AppTheme.aqua.opacity(0.18)
            return a
        }

        let p = min(max(progress01, 0), 1)
        let chars = Array(phrase)
        guard chars.isEmpty == false else { return AttributedString("…") }

        let weights = characterWeights(for: phrase)
        let totalWeight = max(weights.reduce(0, +), 0.001)
        let target = p * totalWeight

        var acc: CGFloat = 0
        var highlightCount: Int = 0

        for i in 0..<weights.count {
            acc += weights[i]
            highlightCount = i + 1
            if acc >= target { break }
        }

        let endCount = min(max(highlightCount, 0), chars.count)
        guard endCount > 0 else { return a }

        let end = a.index(a.startIndex, offsetByCharacters: endCount)
        let r = a.startIndex..<end

        a[r].backgroundColor = AppTheme.mint.opacity(0.34)
        a[r].foregroundColor = AppTheme.ink.opacity(0.98)

        return a
    }

    // MARK: - Weighting

    private func characterWeights(for phrase: String) -> [CGFloat] {
        let vowels = Set(["a","e","i","o","u"])
        let chars = Array(phrase)

        let onsetCount = onsetClusterCount(in: phrase)

        var weights: [CGFloat] = []
        weights.reserveCapacity(chars.count)

        for i in chars.indices {
            let s = String(chars[i]).lowercased()

            if s == " " {
                weights.append(0.55)
                continue
            }

            let isLetter = s.range(of: "[a-z']", options: .regularExpression) != nil
            if !isLetter {
                weights.append(0.40)
                continue
            }

            let isVowel = vowels.contains(s)

            let isLastOfWord: Bool = {
                let nextIsBoundary = (i == chars.count - 1) || (String(chars[i + 1]) == " ")
                return nextIsBoundary
            }()

            // base human weights
            var w: CGFloat = 1.00
            if isVowel { w = 1.22 }
            if isVowel && isLastOfWord { w = 1.38 }

            // onset cluster slow-down
            if i < onsetCount {
                w *= 2.45
            }

            weights.append(w)
        }

        if weights.allSatisfy({ $0 <= 0.001 }) {
            return Array(repeating: 1.0, count: max(chars.count, 1))
        }

        return weights
    }

    /// Onset cluster heuristic (first word only):
    /// - If starts with vowel -> 1
    /// - Else consonant cluster up to first vowel (inclusive), capped to 3
    private func onsetClusterCount(in phrase: String) -> Int {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return 1 }

        let firstWord = trimmed.split(separator: " ").first.map(String.init) ?? trimmed
        let letters = Array(firstWord.lowercased())
        guard letters.isEmpty == false else { return 1 }

        let vowelSet = Set(["a","e","i","o","u"])

        if vowelSet.contains(String(letters[0])) { return 1 }

        var firstVowelIndex: Int? = nil
        for i in 0..<letters.count {
            if vowelSet.contains(String(letters[i])) {
                firstVowelIndex = i
                break
            }
        }

        if let v = firstVowelIndex {
            return min(v + 1, 3)
        } else {
            return min(2, max(1, letters.count))
        }
    }
}
