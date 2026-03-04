//
//  TopicLibrary.swift
//  Velora
//
//  Central content source for Topics (Offline).
//  - English only
//  - Short, psychologically safe phrases
//  - Structured for Easy Onset + Rhythm (sentence split: . ! ?)
//
//  Created by LAYAN on 03/09/1447 AH.
//  Updated by Velora on 28/02/2026:
//  ✅ Reading passages are "actual reading" (fun + vivid), not "I, I, I".
//  ✅ Real scenarios are realistic and common.
//  ✅ No topics contain names or blank placeholders.
//  ✅ Removed comma-before "please" everywhere.
//
//  Updated by Velora on 28/02/2026 (ordering + SR robustness):
//  ✅ Topics are ordered (easiest -> hardest) for people who stutter.
//  ✅ Topics likely to confuse Speech Recognition are pushed to the end.
//  ✅ Replaced smart apostrophes (’ / I’m) with plain ASCII (').
//

import Foundation

// MARK: - Category

enum TopicCategory: String, CaseIterable, Identifiable, Codable {
    case readingPassages
    case realScenarios

    var id: String { rawValue }

    var title: String {
        switch self {
        case .readingPassages: return AppStrings.readingPassages
        case .realScenarios: return AppStrings.realScenarios
        }
    }

    var subtitle: String {
        switch self {
        case .readingPassages: return "Structured text, gentle progression."
        case .realScenarios: return "Speaking practice in safe situations."
        }
    }

    var icon: String {
        switch self {
        case .readingPassages: return "book.closed.fill"
        case .realScenarios: return "person.2.fill"
        }
    }
}

// MARK: - Topic

struct Topic: Identifiable, Hashable, Codable {
    let id: String
    let category: TopicCategory
    let title: String
    let icon: String

    /// Single source of truth (used to generate Easy Onset + Rhythm).
    /// Important: Sentence splitting relies on . ! ?
    let paragraph: String

    /// Legacy short phrases (kept for compatibility).
    let phrases: [String]

    /// Easy Onset steps (cumulative expansion).
    let easyOnsetSteps: [String]

    /// Rhythm sentence (first 1–2 sentences merged).
    let rhythmSentence: String

    init(
        id: String,
        category: TopicCategory,
        title: String,
        icon: String,
        paragraph: String
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.icon = icon

        // ✅ Normalize whitespace + SR-safe apostrophes
        let cleaned = TopicText.cleanWhitespace(paragraph)
        self.paragraph = TopicText.makeSRSafer(cleaned)

        let sentences = TopicText.splitIntoSentences(self.paragraph)

        self.phrases = sentences.map { TopicText.trimPunctuation($0) }
        self.rhythmSentence = TopicText.makeRhythmSentence(from: sentences)
        self.easyOnsetSteps = TopicText.makeEasyOnsetSteps(from: sentences)
    }
}

// MARK: - TopicLibrary

enum TopicLibrary {

    // MARK: - Guided Demo (Judges Preview)

    /// A tiny, safe topic used ONLY for "Quick Preview" mode.
    /// It is not part of the public library list and does not affect sorting/ranking.
    static let demoPreviewTopic: Topic = Topic(
        id: "demo_preview",
        category: .readingPassages,
        title: "Quick Preview",
        icon: "sparkles",
        paragraph: "Welcome to Velora."
    )


    static let all: [Topic] = [

        // ----------------------------
        // Reading Passages (fun, vivid, short)
        // ----------------------------

        Topic(
            id: "reading_moonlight_walk",
            category: .readingPassages,
            title: "Moonlight Walk",
            icon: "moon.stars.fill",
            paragraph: """
            A quiet street shines after the rain. Small lights ripple on the road. Slow steps feel safe.
            """
        ),


        Topic(
            id: "reading_library_cat",
            category: .readingPassages,
            title: "Library Cat",
            icon: "books.vertical.fill",
            paragraph: """
            A sleepy cat rests by a warm window. Pages turn with a gentle sound. The room stays still.
            """
        ),

        Topic(
            id: "reading_market_morning",
            category: .readingPassages,
            title: "Morning Market",
            icon: "basket.fill",
            paragraph: """
            Fresh fruit fills the air with a sweet smell. Friendly voices rise and fall. A small smile slips in.
            """
        ),

        Topic(
            id: "reading_space_postcard",
            category: .readingPassages,
            title: "Postcard from Space",
            icon: "sparkles",
            paragraph: """
            A silver ship floats past silent stars. A blue planet turns below. Everything moves softly.
            """
        ),

        Topic(
            id: "reading_small_recipe",
            category: .readingPassages,
            title: "Simple Recipe",
            icon: "fork.knife",
            paragraph: """
            Warm toast meets soft butter. Honey melts and shines. One bite feels slow and sweet.
            """
        ),
        Topic(
            id: "reading_ocean_glass",
            category: .readingPassages,
            title: "Sea Glass",
            icon: "water.waves",
            paragraph: """
            Soft waves rollin and fade out. Sea glass glows in the sand. A calm breeze moves on.
            """
        ),

        // ✅ Added (Reading) — 4 more

        Topic(
            id: "reading_train_window",
            category: .readingPassages,
            title: "Train Window",
            icon: "tram.fill",
            paragraph: """
            Train glides along a smooth track. Window light slides across quiet seats. The ride feels steady.
            """
        ),

        Topic(
            id: "reading_garden_path",
            category: .readingPassages,
            title: "Garden Path",
            icon: "leaf.fill",
            paragraph: """
            Small flowers line a narrow path. Soft shade rests under tall trees. A slow walk feels easy.
            """
        ),

        Topic(
            id: "reading_snowy_morning",
            category: .readingPassages,
            title: "Snowy Morning",
            icon: "snowflake",
            paragraph: """
            Soft snow falls with no sound. Street lights glow in the mist. Warm hands hold a cup.
            """
        ),

        Topic(
            id: "reading_river_stones",
            category: .readingPassages,
            title: "River Stones",
            icon: "drop.fill",
            paragraph: """
            Clear water runs over smooth stones. Small ripples shimmer and fade. A calm moment stays.
            """
        ),

        // ----------------------------
        // Real Scenarios (realistic + common + safe)
        // ----------------------------

        Topic(
            id: "scenario_apology_late",
            category: .realScenarios,
            title: "Sorry I'm Late",
            icon: "clock.fill",
            paragraph: """
            Hi. Sorry I am late. Traffic was slow. Thank you for waiting.
            """
        ),

        Topic(
            id: "scenario_answer_phone",
            category: .realScenarios,
            title: "Answer a Call",
            icon: "phone.fill",
            paragraph: """
            Hello. Yes this is a good time. How can I help?
            """
        ),

        Topic(
            id: "scenario_repeat_please",
            category: .realScenarios,
            title: "Say That Again",
            icon: "ear.fill",
            paragraph: """
            Sorry. Could you say that again? A little slower please. Thank you.
            """
        ),

        Topic(
            id: "scenario_schedule_time",
            category: .realScenarios,
            title: "Schedule a Time",
            icon: "calendar.badge.clock",
            paragraph: """
            Hi. Can we meet today? What time works for you? I can be flexible.
            """
        ),

        Topic(
            id: "scenario_small_problem",
            category: .realScenarios,
            title: "Quick Fix",
            icon: "wrench.and.screwdriver.fill",
            paragraph: """
            Excuse me. Something is not working. Can you check it please? Thank you.
            """
        ),

        Topic(
            id: "scenario_order_food",
            category: .realScenarios,
            title: "Order Food",
            icon: "takeoutbag.and.cup.and.straw.fill",
            paragraph: """
            Hi. One sandwich please. No spice please. That's all thank you.
            """
        ),

        Topic(
            id: "scenario_directions",
            category: .realScenarios,
            title: "Ask for Directions",
            icon: "map.fill",
            paragraph: """
            Excuse me. Where is the exit? Is it this way? Thank you.
            """
        ),

        Topic(
            id: "scenario_follow_up_message",
            category: .realScenarios,
            title: "Follow Up",
            icon: "paperplane.fill",
            paragraph: """
            Hi. Just checking in. Did you see my message? Thank you.
            """
        ),

        Topic(
            id: "scenario_cancel_politely",
            category: .realScenarios,
            title: "Cancel Politely",
            icon: "xmark.circle.fill",
            paragraph: """
            Hi. I need to cancel today. I'm sorry about that. Can we reschedule?
            """
        ),

        Topic(
            id: "scenario_voice_message",
            category: .realScenarios,
            title: "Leave a Voice Message",
            icon: "mic.fill",
            paragraph: """
            Hi. I'm calling about the appointment. Please call me back. Thank you.
            """
        ),

        Topic(
            id: "scenario_store_return",
            category: .realScenarios,
            title: "Return an Item",
            icon: "bag.fill",
            paragraph: """
            Hi. I would like to return this item. It did not work for me. Thank you.
            """
        ),

        Topic(
            id: "scenario_check_in_desk",
            category: .realScenarios,
            title: "At the Front Desk",
            icon: "building.2.fill",
            paragraph: """
            Hi. I have a reservation. Can you check it please? Thank you.
            """
        )
    ]

    /// ✅ Ordered (easiest -> hardest) with SR-confusable items pushed last.
    static func topics(for category: TopicCategory) -> [Topic] {
        let filtered = all.filter { $0.category == category }

        return filtered.sorted { a, b in
            let ra = rank(for: a)
            let rb = rank(for: b)
            if ra != rb { return ra < rb }

            // Stable fallback sorting
            if a.title != b.title { return a.title < b.title }
            return a.id < b.id
        }
    }

    // MARK: - Ranking logic (manual, stutter-first)

    /// Lower rank = easier / safer for stuttering pacing.
    /// Higher rank = harder (more complex sounds, longer phrases, or SR-confusable).
    private static func rank(for topic: Topic) -> Int {
        switch topic.category {

        case .readingPassages:
            return readingRank[topic.id] ?? 9_999

        case .realScenarios:
            return scenarioRank[topic.id] ?? 9_999
        }
    }

    /// Reading: easier first = softer consonants, fewer tricky clusters (sh, sl, tr, st),
    /// fewer /r/ chains, less alliteration, and simpler pacing.
    private static let readingRank: [String: Int] = [
        // ✅ Easiest (very smooth, repetitive calm vowels)
        "reading_small_recipe": 10,      // warm / soft / honey (gentle rhythm)
        "reading_library_cat": 20,       // simple nouns, calm pacing
        "reading_garden_path": 30,       // gentle, predictable

        // ✅ Medium
        "reading_ocean_glass": 40,       // "sea glass" ok, still easy
        "reading_train_window": 50,      // "glides" "slides" (a bit more articulation)
        "reading_snowy_morning": 60,     // "street lights" (st + r)

        // ✅ Harder (more clusters/alliteration that can trigger blocks or SR slips)
        "reading_river_stones": 80,      // r-r-r + "ripples shimmer" can be tricky
        "reading_moonlight_walk": 90,    // "street shines" "small lights ripple" (lots of s + l)
        "reading_market_morning": 100,   // "fresh fruit" "friendly" (fr clusters)
        "reading_space_postcard": 110    // "silver ship floats past silent stars" (s clusters + poetry)
    ]

    /// Scenarios: easier first = fewer sentences, fewer repair phrases, fewer question marks,
    /// less SR confusion (avoid contractions / filler).
    /// SR-confusable topics pushed last.
    private static let scenarioRank: [String: Int] = [
        // ✅ Easiest (short, clear, common words)
        "scenario_directions": 10,
        "scenario_check_in_desk": 20,
        "scenario_order_food": 30,
        "scenario_small_problem": 40,

        // ✅ Medium (more turns / questions)
        "scenario_follow_up_message": 60,
        "scenario_schedule_time": 70,
        "scenario_repeat_please": 80,     // has pacing request + question

        // ✅ Harder / SR-confusable (kept last)
        "scenario_answer_phone": 120,     // "Yes this is..." sometimes heard weird in quick speech
        "scenario_store_return": 130,     // longer + “would like to” can be dropped
        "scenario_voice_message": 140,    // voicemail style; SR can drop “appointment”
        "scenario_cancel_politely": 150,  // “reschedule” tends to be misrecognized
        "scenario_apology_late": 160      // timing stress + “sorry I'm late” can get clipped
    ]
}

// MARK: - Text Engine (Offline, predictable)

private enum TopicText {

    static func cleanWhitespace(_ text: String) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        var out = ""
        var lastWasSpace = false
        for ch in collapsed {
            if ch == " " {
                if !lastWasSpace { out.append(ch) }
                lastWasSpace = true
            } else {
                out.append(ch)
                lastWasSpace = false
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// ✅ SR-safety: replace smart apostrophes with plain ASCII apostrophe.
    /// (Apple Speech can be inconsistent with Unicode punctuation in some edge cases.)
    static func makeSRSafer(_ text: String) -> String {
        text
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
    }

    /// Splits into sentences on . ! ? (simple + stable for offline).
    static func splitIntoSentences(_ paragraph: String) -> [String] {
        var sentences: [String] = []
        var current = ""

        for ch in paragraph {
            current.append(ch)

            if ch == "." || ch == "!" || ch == "?" {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }

        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty {
            sentences.append(tail)
        }

        return sentences.filter { !$0.isEmpty }
    }

    static func trimPunctuation(_ sentence: String) -> String {
        sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
    }

    static func makeRhythmSentence(from sentences: [String]) -> String {
        guard !sentences.isEmpty else { return "Take it slow. Stay calm." }

        if sentences.count >= 2 {
            let s1 = trimPunctuation(sentences[0])
            let s2 = trimPunctuation(sentences[1])
            let joined = "\(s1). \(s2)."
            if joined.count <= 90 { return joined }
        }

        let s1 = trimPunctuation(sentences[0])
        return "\(s1)."
    }

    /// Easy Onset: 1 word -> 2 words -> 4 words -> full sentence (per sentence).
    static func makeEasyOnsetSteps(from sentences: [String]) -> [String] {
        var out: [String] = []

        for sentence in sentences {
            let clean = trimPunctuation(sentence)
            let words = tokenizeWords(clean)
            guard !words.isEmpty else { continue }

            let targets = makeCumulativeTargets(words: words, maxLevels: 4)

            for t in targets where !out.contains(t) {
                out.append(t)
            }
        }

        if out.isEmpty { return ["Hello", "Hello there", "Hello there please"] }
        return out
    }

    private static func tokenizeWords(_ sentence: String) -> [String] {
        let raw = sentence.split(separator: " ").map(String.init)
        let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: "'"))

        return raw.compactMap { token in
            let trimmed = token.trimmingCharacters(in: allowed.inverted)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private static func makeCumulativeTargets(words: [String], maxLevels: Int) -> [String] {
        let n = words.count
        guard n > 0 else { return [] }

        var prefixCounts: [Int] = [1, 2, 4, n]
        prefixCounts = prefixCounts.map { min(max($0, 1), n) }

        var unique: [Int] = []
        for c in prefixCounts where !unique.contains(c) {
            unique.append(c)
        }

        if unique.count > maxLevels {
            unique = Array(unique.prefix(maxLevels))
        }

        return unique.map { count in
            words.prefix(count).joined(separator: " ")
        }
    }
}
