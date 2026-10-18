//
//  SpeechWordMatcherTests.swift
//  Velora/QualityChecks
//
//  Runs without SwiftUI, hardware, microphone, or network. Tests only the
//  written/recognized text equivalence contract; does not validate audio.
//
import Foundation

@main
struct SpeechWordMatcherTests {
    static func main() {
        let equal: [(String, String)] = [
            ("I am ready", "I'm ready"),
            ("I am ready", "I’m ready"),
            ("I would like a sandwich", "I'd like a sandwich"),
            ("I had a book", "I'd a book"),
            ("That is all", "That's all"),
            ("Here is my receipt", "Here's my receipt"),
            ("Please do not leave", "Please don't leave"),
            ("I cannot go", "I can't go"),
            ("I can not go", "I cannot go"),
            ("We will call", "We'll call"),
            ("We have arrived", "We've arrived"),
            ("You are welcome", "You're welcome"),
            ("May we meet around three", "May we meet around 3"),
            ("Hello, I would like tea!", "hello i'd like tea"),
            ("He has finished", "He's finished"),
            ("She is here", "She's here"),
            ("Let us begin", "Let's begin"),
            ("The cat's toy", "The cat’s toy"),
            ("It is warm", "It's warm")
        ]
        let notEqual: [(String, String)] = [
            ("I am ready", "I am late"),
            ("I can go", "I can't go"),
            ("I would like tea", "I had tea"),
            ("The cat is here", "The cats here"),
            ("Three apples", "Four apples"),
            ("Could you help", "Would you help")
        ]
        var count = 0
        for (expected, actual) in equal {
            precondition(SpeechWordMatcher.sameWords(expected, actual), "Should match: \(expected) / \(actual)")
            count += 1
        }
        for (expected, actual) in notEqual {
            precondition(!SpeechWordMatcher.sameWords(expected, actual), "Should NOT match: \(expected) / \(actual)")
            count += 1
        }
        print("PASS: \(count) text-equivalence checks")
    }
}
