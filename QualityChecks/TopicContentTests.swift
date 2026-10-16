//
//  TopicContentTests.swift
//  Velora/QualityChecks
//
//  This is an offline editorial/structural guard; it does not rank people's
//  sounds or claim clinical validation.
//
import Foundation

enum AppStrings {
    static let readingPassages = "Reading Passages"
    static let realScenarios = "Real Scenarios"
}

@main
struct TopicContentTests {
    static func main() {
        let topics = TopicLibrary.all
        precondition(topics.count == 22)
        precondition(topics.filter { $0.category == .readingPassages }.count == 10)
        precondition(topics.filter { $0.category == .realScenarios }.count == 12)
        precondition(Set(topics.map(\.id)).count == 22)
        let dangling: Set<String> = ["a", "an", "the", "to", "of", "for", "with", "on", "at", "by", "from", "in", "and", "or", "but", "i", "am", "would", "could", "over"]

        // No built-in level should begin with a bare auxiliary, pronoun,
        // or fragment selected merely because it was the first token.
        let badStandalone: Set<String> = [
            "a", "i", "my", "the", "that", "would", "could", "may",
            "let", "here", "have", "when", "thank"
        ]

        var sentenceTotal = 0
        var levelTotal = 0
        for topic in topics {
            let sentences = topic.paragraph
                .split(whereSeparator: { ".!?".contains($0) })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            precondition(sentences.count == 3, "Unexpected sentence count: \(topic.title)")
            precondition(!topic.paragraph.contains("'"), "A contraction remains: \(topic.title)")

            let steps = topic.easyOnsetSteps
            var cursor = 0
            for sentence in sentences {
                let words = sentence.split(separator: " ").map { String($0).trimmingCharacters(in: CharacterSet.punctuationCharacters) }
                precondition((2...9).contains(words.count), "Length mismatch: \(topic.title): \(sentence)")
                // A sentence may naturally start with "I". What matters is
                // that we never ask the user to speak "I" as a level alone.
                precondition(!(words.count == 1 && ["a", "i"].contains(words[0].lowercased())),
                             "Single-letter-only sentence: \(topic.title)")
                var previousCount = 0
                var reachedFullSentence = false
                while cursor < steps.count {
                    let step = steps[cursor]
                    let tokens = step.split(separator: " ").map(String.init)
                    if tokens.count > words.count || !Array(words.prefix(tokens.count)).elementsEqual(tokens) { break }
                    precondition(tokens.count > previousCount, "Non-growing step: \(topic.title)")
                    // A few longer transitions are deliberate, e.g. Hello ->
                    // Hello, I have a reservation. A natural full phrase is
                    // preferable to a dangling "Hello I have".
                    precondition(tokens.count - previousCount <= 5, "Excessive step jump: \(topic.title) => \(step)")
                    if tokens.count == 1 {
                        precondition(!badStandalone.contains(tokens[0].lowercased()),
                                     "Unhelpful one-word start: \(topic.title) => \(step)")
                    }
                    if tokens.count > 1 && tokens.count < words.count {
                        precondition(!dangling.contains(tokens.last?.lowercased() ?? "") || tokens.suffix(2).map { $0.lowercased() } == ["check", "in"], "Dangling prefix: \(topic.title) => \(step)")
                    }
                    previousCount = tokens.count
                    cursor += 1
                    if tokens.count == words.count { reachedFullSentence = true; break }
                }
                precondition(reachedFullSentence, "Sentence not completed: \(topic.title): \(sentence)")
                sentenceTotal += 1
            }
            precondition(cursor == steps.count, "Extra steps: \(topic.title)")
            levelTotal += steps.count
        }
        // Real scenarios require natural greetings, without isolated hello/hi.
        for topic in topics where topic.category == .realScenarios {
            let first = topic.paragraph.lowercased()
            // "Sorry" is an appropriate response when asking someone to repeat.
            precondition(first.hasPrefix("hi ") || first.hasPrefix("hello ") || first.hasPrefix("sorry"),
                         "Conversation needs an opener: \(topic.title)")
            if first.hasPrefix("hi ") || first.hasPrefix("hello ") {
                precondition(topic.easyOnsetSteps.first?.split(separator: " ").count ?? 0 >= 2,
                             "Do not assess a greeting alone: \(topic.title)")
            }
        }
        // Editorial contract for this reviewed library. A content change must
        // be reviewed with its curated prefix boundaries before release.
        precondition(levelTotal == 156, "Curated progression was changed; review all boundaries")
        precondition(TopicLibrary.all.first(where: { $0.id == "scenario_order_food" })?
            .easyOnsetSteps.contains("That is all thank") == false,
            "Please keep a natural pause before thank you")
        precondition(TopicLibrary.all.first(where: { $0.id == "reading_river_stones" })?
            .easyOnsetSteps.contains("Water flows over") == false,
            "Do not stop at an unfinished preposition")
        print("PASS: \(topics.count) topics, \(sentenceTotal) complete sentences, \(levelTotal) curated cumulative levels")
    }
}
