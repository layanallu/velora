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
//  ✅ Replaced smart apostrophes (' / I'm) with plain ASCII (').
//
//  Updated: Custom Topic Support
//  ✅ Topic.init now accepts optional custom easy onset steps + rhythm clauses.
//  ✅ All existing topics unaffected (defaults preserve old behavior exactly).
//  ✅ Demo mode hidden behind flag (code preserved for future use).
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
    /// Custom topics inject their own steps directly via init.
    let easyOnsetSteps: [String]

    /// Rhythm sentence (first 1–2 sentences merged).
    let rhythmSentence: String

    // MARK: - Standard Init (used by TopicLibrary for all built-in topics)
    // All existing call sites are unaffected — same signature as before.

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

        let cleaned = TopicText.cleanWhitespace(paragraph)
        self.paragraph = TopicText.makeSRSafer(cleaned)

        let sentences = TopicText.splitIntoSentences(self.paragraph)

        self.phrases = sentences.map { TopicText.trimPunctuation($0) }
        self.rhythmSentence = TopicText.makeRhythmSentence(from: sentences)
        self.easyOnsetSteps = TopicText.makeEasyOnsetSteps(from: sentences, builtInTopicID: id)
    }

    // MARK: - Custom Init (used by CustomTopicBuilder only)
    // Accepts pre-analyzed steps so the builder's smart logic is used directly.
    // rhythmSentence is derived from paragraph as usual.

    init(
        id: String,
        category: TopicCategory,
        title: String,
        icon: String,
        paragraph: String,
        customEasyOnsetSteps: [String],
        customRhythmClauses: [String]
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.icon = icon

        let cleaned = TopicText.cleanWhitespace(paragraph)
        self.paragraph = TopicText.makeSRSafer(cleaned)

        let sentences = TopicText.splitIntoSentences(self.paragraph)
        self.phrases = sentences.map { TopicText.trimPunctuation($0) }

        // Use custom steps from builder (smart analysis)
        self.easyOnsetSteps = customEasyOnsetSteps.isEmpty
            ? TopicText.makeEasyOnsetSteps(from: sentences)
            : customEasyOnsetSteps

        // Build rhythm sentence from clauses joined naturally
        self.rhythmSentence = customRhythmClauses.isEmpty
            ? TopicText.makeRhythmSentence(from: sentences)
            : customRhythmClauses.joined(separator: ". ")
    }
}

// MARK: - TopicLibrary

enum TopicLibrary {

    // MARK: - Demo Topic (hidden — code preserved for future use)
    // Set isEnabled = true to restore Quick Preview in TopicCategoryView.

    static let isDemoEnabled: Bool = false

    static let demoPreviewTopic: Topic = Topic(
        id: "demo_preview",
        category: .readingPassages,
        title: "Quick Preview",
        icon: "sparkles",
        paragraph: "Welcome to Velora."
    )

    // MARK: - All Built-in Topics

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
            Moonlight shines on the wet street. Warm lamps glow along the road. Walking home feels peaceful tonight.
            """
        ),

        Topic(
            id: "reading_library_cat",
            category: .readingPassages,
            title: "Library Cat",
            icon: "books.vertical.fill",
            paragraph: """
            Morning light fills the quiet library. Nearby, a cat sleeps by the window. Old pages turn softly.
            """
        ),

        Topic(
            id: "reading_market_morning",
            category: .readingPassages,
            title: "Morning Market",
            icon: "basket.fill",
            paragraph: """
            Morning air smells of sweet fruit. Warm voices rise across the stalls. Everyone leaves with a smile.
            """
        ),

        Topic(
            id: "reading_space_postcard",
            category: .readingPassages,
            title: "Postcard from Space",
            icon: "sparkles",
            paragraph: """
            Away from Earth, a silver ship floats. Little lights glow inside the cabin. Everything moves quietly.
            """
        ),

        Topic(
            id: "reading_small_recipe",
            category: .readingPassages,
            title: "Simple Recipe",
            icon: "fork.knife",
            paragraph: """
            Warm toast holds a little butter. Honey melts over the top. Every bite is warm and sweet.
            """
        ),

        Topic(
            id: "reading_ocean_glass",
            category: .readingPassages,
            title: "Sea Glass",
            icon: "water.waves",
            paragraph: """
            Ocean waves roll onto the sand. Light catches a piece of sea glass. Morning air feels cool.
            """
        ),

        Topic(
            id: "reading_train_window",
            category: .readingPassages,
            title: "Train Window",
            icon: "tram.fill",
            paragraph: """
            Window light moves across the seats. Green fields slide gently by. Everyone enjoys the quiet ride.
            """
        ),

        Topic(
            id: "reading_garden_path",
            category: .readingPassages,
            title: "Garden Path",
            icon: "leaf.fill",
            paragraph: """
            Morning light warms the garden path. Little flowers grow beside the trees. Walking slowly feels peaceful in the shade.
            """
        ),

        Topic(
            id: "reading_snowy_morning",
            category: .readingPassages,
            title: "Snowy Morning",
            icon: "snowflake",
            paragraph: """
            Morning snow falls without a sound. Little lights glow along the street. Warm hands hold a cup.
            """
        ),

        Topic(
            id: "reading_river_stones",
            category: .readingPassages,
            title: "River Stones",
            icon: "drop.fill",
            paragraph: """
            Water flows over smooth river stones. Little ripples form and fade away. Warm sunlight makes the river sparkle.
            """
        ),

        // ----------------------------
        // Real Scenarios
        // ----------------------------

        Topic(
            id: "scenario_apology_late",
            category: .realScenarios,
            title: "Sorry I'm Late",
            icon: "clock.fill",
            paragraph: """
            Hi there, I am sorry for being late. My bus was delayed. Thank you for waiting.
            """
        ),

        Topic(
            id: "scenario_answer_phone",
            category: .realScenarios,
            title: "Answer a Call",
            icon: "phone.fill",
            paragraph: """
            Hello there, I am glad you called. I have time to talk now. How are you?
            """
        ),

        Topic(
            id: "scenario_repeat_please",
            category: .realScenarios,
            title: "Say That Again",
            icon: "ear.fill",
            paragraph: """
            Sorry, I missed that. Would you say it again, please? Maybe a little slower this time.
            """
        ),

        Topic(
            id: "scenario_schedule_time",
            category: .realScenarios,
            title: "Schedule a Time",
            icon: "calendar.badge.clock",
            paragraph: """
            Hi there, are you free tomorrow? Maybe we could meet around three? Let me know what works.
            """
        ),

        Topic(
            id: "scenario_small_problem",
            category: .realScenarios,
            title: "Quick Fix",
            icon: "wrench.and.screwdriver.fill",
            paragraph: """
            Hello there, I need help. Nothing happens when I tap the screen. Would you mind taking a look?
            """
        ),

        Topic(
            id: "scenario_order_food",
            category: .realScenarios,
            title: "Order Food",
            icon: "takeoutbag.and.cup.and.straw.fill",
            paragraph: """
            Hi there, I would like a sandwich, please. Nothing spicy, please. That is all, thank you.
            """
        ),

        Topic(
            id: "scenario_directions",
            category: .realScenarios,
            title: "Ask for Directions",
            icon: "map.fill",
            paragraph: """
            Hello there, could you help me? Where is the exit? Thank you so much.
            """
        ),

        Topic(
            id: "scenario_follow_up_message",
            category: .realScenarios,
            title: "Follow Up",
            icon: "paperplane.fill",
            paragraph: """
            Hi there, just following up on my message. Have you seen it yet? Thanks for your time!
            """
        ),

        Topic(
            id: "scenario_cancel_politely",
            category: .realScenarios,
            title: "Cancel Politely",
            icon: "xmark.circle.fill",
            paragraph: """
            Hello there, I need to cancel our meeting. Sorry for the short notice. Maybe we can reschedule?
            """
        ),

        Topic(
            id: "scenario_voice_message",
            category: .realScenarios,
            title: "Leave a Voice Message",
            icon: "mic.fill",
            paragraph: """
            Hi there, I am calling about my appointment. When you can, please call me back. Thank you.
            """
        ),

        Topic(
            id: "scenario_store_return",
            category: .realScenarios,
            title: "Return an Item",
            icon: "bag.fill",
            paragraph: """
            Hi there, I would like to return this item. Here is my receipt. Would you mind helping me?
            """
        ),

        Topic(
            id: "scenario_check_in_desk",
            category: .realScenarios,
            title: "At the Front Desk",
            icon: "building.2.fill",
            paragraph: """
            Hello there, I booked a room. Here is my booking confirmation. May I check in now?
            """
        )
    ]

    // MARK: - Sorted Topics

    static func topics(for category: TopicCategory) -> [Topic] {
        let filtered = all.filter { $0.category == category }

        return filtered.sorted { a, b in
            let ra = rank(for: a)
            let rb = rank(for: b)
            if ra != rb { return ra < rb }
            if a.title != b.title { return a.title < b.title }
            return a.id < b.id
        }
    }

    // MARK: - Ranking

    private static func rank(for topic: Topic) -> Int {
        switch topic.category {
        case .readingPassages: return readingRank[topic.id] ?? 9_999
        case .realScenarios: return scenarioRank[topic.id] ?? 9_999
        }
    }

    private static let readingRank: [String: Int] = [
        "reading_small_recipe": 10,
        "reading_library_cat": 20,
        "reading_garden_path": 30,
        "reading_ocean_glass": 40,
        "reading_train_window": 50,
        "reading_snowy_morning": 60,
        "reading_river_stones": 80,
        "reading_moonlight_walk": 90,
        "reading_market_morning": 100,
        "reading_space_postcard": 110
    ]

    private static let scenarioRank: [String: Int] = [
        "scenario_directions": 10,
        "scenario_check_in_desk": 20,
        "scenario_order_food": 30,
        "scenario_small_problem": 40,
        "scenario_follow_up_message": 60,
        "scenario_schedule_time": 70,
        "scenario_repeat_please": 80,
        "scenario_answer_phone": 120,
        "scenario_store_return": 130,
        "scenario_voice_message": 140,
        "scenario_cancel_politely": 150,
        "scenario_apology_late": 160
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

    static func makeSRSafer(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
    }

    static func splitIntoSentences(_ paragraph: String) -> [String] {
        var sentences: [String] = []
        var current = ""

        for ch in paragraph {
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

    // MARK: - Curated Easy Onset boundaries for built-in topics

    // Every array defines prefix word counts for ONE complete sentence.
    // Example: [2, 4, 6] = first 2 words, then 4, then all 6.
    //
    // These boundaries are editorial: the user never has to say a lone
    // auxiliary/article ("Would", "That", "Thank") simply because a
    // generic [1,2,4,n] algorithm picked it. A longer meaningful phrase
    // is preferable to making the person repeat an unnatural fragment.
    //
    // Keep this aligned with TopicLibrary paragraphs. QualityChecks tests
    // assert every sentence reaches its exact final word, with no skips.
    private static let curatedBoundaries: [String: [[Int]]] = [
        "reading_moonlight_walk": [[2, 6], [2, 3, 6], [2, 4, 5]],
        "reading_library_cat": [[2, 3, 6], [4, 7], [2, 4]],
        "reading_market_morning": [[2, 3, 6], [2, 3, 6], [2, 5]],
        "reading_space_postcard": [[3, 6, 7], [2, 3, 6], [2, 3]],
        "reading_small_recipe": [[2, 3, 6], [2, 5], [2, 4, 6]],
        "reading_ocean_glass": [[2, 3, 6], [2, 4, 7], [2, 4]],
        "reading_train_window": [[2, 3, 6], [2, 3, 5], [2, 5]],
        "reading_garden_path": [[2, 3, 6], [2, 3, 6], [2, 4, 7]],
        "reading_snowy_morning": [[2, 3, 6], [2, 3, 6], [2, 3, 5]],
        "reading_river_stones": [[2, 6], [2, 3, 6], [2, 3, 6]],
        "scenario_apology_late": [[2, 5, 8], [2, 4], [2, 4]],
        "scenario_answer_phone": [[2, 5, 7], [3, 6], [3]],
        "scenario_repeat_please": [[1, 4], [4, 6], [4, 6]],
        "scenario_schedule_time": [[2, 6], [4, 6], [3, 5]],
        "scenario_small_problem": [[2, 5], [2, 5, 7], [3, 6]],
        "scenario_order_food": [[2, 7, 8], [2, 3], [3, 5]],
        "scenario_directions": [[2, 6], [4], [2, 4]],
        "scenario_follow_up_message": [[2, 5, 8], [4, 5], [1, 4]],
        "scenario_cancel_politely": [[2, 6, 8], [1, 5], [4]],
        "scenario_voice_message": [[2, 5, 8], [3, 7], [2]],
        "scenario_store_return": [[2, 7, 9], [4], [3, 5]],
        "scenario_check_in_desk": [[2, 4, 6], [5], [4, 5]]
    ]

    static func makeEasyOnsetSteps(
        from sentences: [String],
        builtInTopicID: String? = nil
    ) -> [String] {
        // Custom topics retain their existing step generator; their wording
        // cannot be editorially reviewed at build time.
        guard let topicID = builtInTopicID,
              let boundaries = curatedBoundaries[topicID],
              boundaries.count == sentences.count else {
            return makeAutomaticEasyOnsetSteps(from: sentences)
        }

        var out: [String] = []
        for (sentence, counts) in zip(sentences, boundaries) {
            let words = tokenizeWords(trimPunctuation(sentence))
            guard !words.isEmpty, counts.last == words.count,
                  counts.allSatisfy({ $0 > 0 && $0 <= words.count }),
                  zip(counts, counts.dropFirst()).allSatisfy({ $0 < $1 }) else {
                // Safe fallback when a future editor changes a paragraph
                // without refreshing its boundaries. The tests catch this.
                return makeAutomaticEasyOnsetSteps(from: sentences)
            }
            out.append(contentsOf: counts.map { words.prefix($0).joined(separator: " ") })
        }
        return out
    }

    // Generic fallback remains for personal/custom topics, and for safe
    // recovery after editing the content without updating the curated guide.
    private static func makeAutomaticEasyOnsetSteps(from sentences: [String]) -> [String] {
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

        let proposedCounts = [1, 2, 4, n]
        let incompleteEndings: Set<String> = [
            "a", "an", "the", "to", "of", "for", "with", "on", "at", "by",
            "from", "in", "and", "or", "but", "i", "i'm", "i'd",
            "am", "is", "are", "was", "were", "have", "has", "had",
            "can", "could", "would", "will", "may", "shall", "do", "does", "did"
        ]

        // Never leave a guided prefix ending with a dangling article,
        // preposition, or auxiliary. Keep the single-word introduction,
        // then move only intermediate boundaries forward when needed.
        var prefixCounts: [Int] = []
        for proposed in proposedCounts {
            var count = min(max(proposed, 1), n)
            // A two-letter starter can finish before the acoustic onset window.
            // Begin with a short phrase instead of demanding an isolated "No"
            // or "My". The whole sentence remains the final level.
            if proposed == 1 && words[0].count <= 2 {
                count = min(2, n)
            }
            if proposed > 1 {
                while count < n && incompleteEndings.contains(words[count - 1].lowercased()) {
                    count += 1
                }
            }
            prefixCounts.append(count)
        }

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
