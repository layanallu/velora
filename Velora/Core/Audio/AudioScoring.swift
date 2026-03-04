//
//  AudioScoring.swift
//  Velora
//
//  Lightweight heuristic scoring (offline, no ML).
//  Focus: technique signals (soft onset + steady rhythm), not pronunciation.
//
//  Updated by Velora on 26/02/2026.
//

import Foundation

enum AudioScoring {

    // MARK: - Metrics

    struct EasyOnsetMetrics: Equatable {
        var rmsSamples: [Float]
        var onsetScores: [Int]
    }

    struct RhythmMetrics: Equatable {
        var rmsSamples: [Float]
        init(rmsSamples: [Float] = []) { self.rmsSamples = rmsSamples }
    }

    // MARK: - Public composites (recommended V1)

    static func smoothnessScoreV1(easy: EasyOnsetMetrics) -> Int {
        let a = smoothStartScore(samples: easy.rmsSamples)
        let b = slowFlowScore(samples: easy.rmsSamples)
        let c = onsetQualityScore(onsetScores: easy.onsetScores)

        let blended = Int(round(
            0.50 * Double(c) +
            0.30 * Double(a) +
            0.20 * Double(b)
        ))

        return clamp(blended, 35, 95)
    }

    static func rhythmScoreV1(rhythm: RhythmMetrics) -> Int {
        rhythmScore(samples: rhythm.rmsSamples)
    }

    static func confidenceScoreV1(easy: EasyOnsetMetrics, rhythm: RhythmMetrics) -> Int {
        let combined = easy.rmsSamples + rhythm.rmsSamples
        guard combined.count >= 20 else { return 60 }

        let voicedRatio = voicedRatio(samples: combined, threshold: 0.018)
        let avgLevel = average(samples: combined)
        let steadiness = 1.0 - normalizedVariance(samples: combined)
        let spikinessPenalty = Double(spikeCount(samples: combined)) * 0.04

        let level01 = clamp01(Double(avgLevel) / 0.05)

        var score01 =
            0.48 * Double(voicedRatio) +
            0.32 * Double(steadiness) +
            0.20 * level01

        score01 -= spikinessPenalty
        score01 = clamp01(score01)

        return clamp(Int(round(45 + score01 * 50)), 35, 95)
    }

    // MARK: - Primitives

    static func smoothStartScore(samples: [Float]) -> Int {
        guard !samples.isEmpty else { return 60 }
        let peak = samples.max() ?? 0.0001
        let norm = samples.map { min($0 / max(peak, 0.0001), 1.0) }

        var spikes = 0
        for i in 1..<norm.count {
            if (norm[i] - norm[i - 1]) > 0.35 { spikes += 1 }
        }

        let raw = 100 - (spikes * 8)
        return clamp(raw, 45, 95)
    }

    static func slowFlowScore(samples: [Float]) -> Int {
        guard !samples.isEmpty else { return 60 }
        let threshold: Float = 0.02
        let voiced = samples.filter { $0 > threshold }.count
        let ratio = Float(voiced) / Float(samples.count)

        let target: Float = 0.65
        let diff = abs(ratio - target)
        let raw = Int(95 - (diff * 140))
        return clamp(raw, 45, 95)
    }

    static func rhythmScore(samples: [Float]) -> Int {
        guard samples.count > 10 else { return 60 }
        let mean = samples.reduce(0, +) / Float(samples.count)
        let varSum = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
        let variance = varSum / Float(samples.count)
        let raw = Int(95 - min(variance * 4000, 50))
        return clamp(raw, 45, 95)
    }

    // MARK: - Helpers

    private static func onsetQualityScore(onsetScores: [Int]) -> Int {
        guard onsetScores.isEmpty == false else { return 60 }
        let clamped = onsetScores.map { clamp($0, 0, 100) }.sorted()
        let trimmed: [Int]
        if clamped.count >= 5 { trimmed = Array(clamped.dropFirst(1).dropLast(1)) }
        else { trimmed = clamped }

        let avg = Double(trimmed.reduce(0, +)) / Double(trimmed.count)
        return clamp(Int(round(avg)), 40, 95)
    }

    private static func voicedRatio(samples: [Float], threshold: Float) -> Float {
        guard samples.isEmpty == false else { return 0 }
        let voiced = samples.filter { $0 > threshold }.count
        return Float(voiced) / Float(samples.count)
    }

    private static func average(samples: [Float]) -> Float {
        guard samples.isEmpty == false else { return 0 }
        return samples.reduce(0, +) / Float(samples.count)
    }

    private static func normalizedVariance(samples: [Float]) -> Double {
        guard samples.count > 10 else { return 0.5 }
        let mean = Double(samples.reduce(0, +)) / Double(samples.count)
        if mean <= 0.0000001 { return 1.0 }

        let varSum = samples
            .map { Double($0) - mean }
            .map { $0 * $0 }
            .reduce(0, +)

        let variance = varSum / Double(samples.count)
        let nv = variance / (mean * mean + 0.000001)
        return clamp01(nv / 1.8)
    }

    private static func spikeCount(samples: [Float]) -> Int {
        guard samples.count > 2 else { return 0 }
        var spikes = 0
        for i in 1..<samples.count {
            if (samples[i] - samples[i - 1]) > 0.020 { spikes += 1 }
        }
        return spikes
    }

    private static func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { max(lo, min(hi, v)) }
    private static func clamp01(_ v: Double) -> Double { max(0, min(1, v)) }
}

// ✅ Convenience names used across UI files (avoid clash with nested types)
typealias AudioEasyOnsetMetrics = AudioScoring.EasyOnsetMetrics
typealias AudioRhythmMetrics = AudioScoring.RhythmMetrics
