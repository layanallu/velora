//
//  VoicingDetector.swift
//  Velora
//
//  Lightweight voiced/unvoiced estimator (offline, no ML).
//
//  Goal:
//  - Return a stable voicingConfidence (0...1).
//  - Works on raw mic buffers.
//  - Helps Easy Onset: ignore breath noise, fricatives (S/F/TH), and stop bursts (K/T/P).
//
//  Approach (simple but effective):
//  - Autocorrelation over a limited lag range (human F0 band).
//  - Normalize by energy.
//  - Use max normalized correlation as periodicity proxy.
//
//  Created by Velora on 25/02/2026.
//

import Foundation
import AVFoundation

struct VoicingDetector {

    /// Typical human F0 range (Hz). We keep it conservative for speech.
    /// You can tune later if needed.
    var f0MinHz: Float = 70
    var f0MaxHz: Float = 320

    /// Energy gate: below this RMS, we treat as unvoiced regardless.
    var minRMSGate: Float = 0.006

    /// Computes voicing confidence from a mono float buffer.
    /// - Returns: 0...1 (higher means more periodic/voiced)
    func voicingConfidence(samples: UnsafePointer<Float>, count: Int, sampleRate: Double, rms: Float) -> Float {
        guard count >= 256 else { return 0 }
        guard sampleRate >= 8000 else { return 0 }
        guard rms >= minRMSGate else { return 0 }

        // Lag range for autocorrelation
        let minLag = Int(sampleRate / Double(f0MaxHz))
        let maxLag = Int(sampleRate / Double(f0MinHz))

        let safeMinLag = max(8, minLag)
        let safeMaxLag = min(maxLag, count / 2)
        if safeMaxLag <= safeMinLag { return 0 }

        // We evaluate on a window (first N samples) to keep it cheap.
        // 1024 is good trade-off; use less if buffer is smaller.
        let n = min(count, 1024)

        // Energy (normalize)
        var energy: Float = 0
        for i in 0..<n {
            let x = samples[i]
            energy += x * x
        }
        if energy < 1e-6 { return 0 }

        // Remove DC (helps correlation)
        var mean: Float = 0
        for i in 0..<n { mean += samples[i] }
        mean /= Float(n)

        // Autocorrelation max in lag band
        var best: Float = 0

        // To reduce CPU, stride the lag a bit (still accurate enough for voicing gate).
        // If you want more precision later, make stride = 1.
        let lagStride = 2

        var lag = safeMinLag
        while lag <= safeMaxLag {
            var sum: Float = 0
            var e1: Float = 0
            var e2: Float = 0

            // Compute normalized correlation at this lag
            // r = sum(x[t]*x[t-lag]) / sqrt(sum(x^2)*sum(y^2))
            for t in lag..<n {
                let a = samples[t] - mean
                let b = samples[t - lag] - mean
                sum += a * b
                e1 += a * a
                e2 += b * b
            }

            let denom = sqrt(max(e1 * e2, 1e-9))
            let r = sum / denom
            if r > best { best = r }

            lag += lagStride
        }

        // Map best correlation (roughly 0.0..1.0) to confidence.
        // Voiced speech often yields >0.55. Unvoiced/noise usually <0.35.
        // We soften mapping to be supportive.
        let conf = clamp01((best - 0.30) / 0.45) // 0 at 0.30, 1 at 0.75
        return conf
    }

    private func clamp01(_ x: Float) -> Float { max(0, min(1, x)) }
}
