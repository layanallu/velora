//
//  SessionRecord.swift
//  Velora
//
//  Stores a completed session record (Topic-based).
//  - No ExerciseType.
//  - Designed for the official Velora Feedback screen:
//      Smoothness Score, Rhythm Score, Confidence Indicator, One supportive suggestion
//  - Offline-friendly (Codable ready for later persistence).
//
//  Created by LAYAN  on 03/09/1447 AH.
//

import Foundation

struct SessionRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()

    // Topic snapshot (store minimal “what the user saw”)
    var topicID: String
    var topicTitle: String
    var topicCategoryRaw: String

    // Feedback metrics (0...100)
    var smoothnessScore: Int
    var rhythmScore: Int
    var confidenceScore: Int

    // One supportive suggestion (short, safe)
    var suggestion: String

    // Optional: saved audio filename (for Feedback playback only)
    var audioFilename: String?

    // MARK: - Convenience

    static func make(
        topicID: String,
        topicTitle: String,
        topicCategoryRaw: String,
        smoothness: Int,
        rhythm: Int,
        confidence: Int,
        suggestion: String,
        audioFilename: String? = nil
    ) -> SessionRecord {
        SessionRecord(
            topicID: topicID,
            topicTitle: topicTitle,
            topicCategoryRaw: topicCategoryRaw,
            smoothnessScore: smoothness.clamped01to100,
            rhythmScore: rhythm.clamped01to100,
            confidenceScore: confidence.clamped01to100,
            suggestion: suggestion,
            audioFilename: audioFilename
        )
    }
}

// MARK: - Small Helpers (safe + judge-friendly)

private extension Int {
    var clamped01to100: Int {
        Swift.min(100, Swift.max(0, self))
    }
}
