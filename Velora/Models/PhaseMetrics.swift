//
//  PhaseMetrics.swift
//  Velora
//
//  Simple data containers for passing measured audio metrics
//  between session phases (Easy Onset -> Rhythm -> Feedback).
//
//  Offline, lightweight, and scalable (we can add more fields later).
//
//  Created by Velora on 26/02/2026.
//

import Foundation

/// Metrics captured during Easy Onset phase.
struct EasyOnsetMetrics: Equatable {
    /// RMS samples captured while the mic is ON (AudioMeter.smoothedRMS).
    let rmsSamples: [Float]

    /// One onset score per evaluation attempt (from SpeechTranscriber.onsetScore).
    /// Range expectation: 0...100 (but we clamp in scoring).
    let onsetScores: [Int]

    /// Total number of evaluations (attempts).
    var attempts: Int { onsetScores.count }

    static let empty = EasyOnsetMetrics(rmsSamples: [], onsetScores: [])
}

/// Metrics captured during Rhythm phase.
struct RhythmMetrics: Equatable {
    /// RMS samples captured while user is practicing rhythm (AudioMeter.smoothedRMS).
    let rmsSamples: [Float]

    static let empty = RhythmMetrics(rmsSamples: [])
}
