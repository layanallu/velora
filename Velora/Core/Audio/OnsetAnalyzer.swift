//
//  OnsetAnalyzer.swift
//  Velora
//
//  Smart Easy Onset estimator (offline, no ML).
//
//  ✅ Fixes for short words (e.g., "Hi"):
//  - Calibration ends EARLY if speech begins (so we don't miss the onset).
//  - Lower, adaptive detection threshold.
//  - Scores: Rise Time (10%->60%), Roughness, Post-onset Stability.
//  - Returns Verdict + Hint + Confidence (honest + supportive).
//
//  Created by Velora on 25/02/2026.
//  Updated by Velora on 25/02/2026.
//  Updated by Velora on 28/02/2026: ✅ more forgiving thresholds.
//

import Foundation

struct OnsetMetrics: Equatable {

    enum Kind: String {
        case unknown
        case soft
        case hard
        case noisy
    }

    enum Verdict: String {
        case great
        case good
        case tryAgain
        case notDetected
    }

    var score: Int
    var kind: Kind

    var verdict: Verdict
    var hint: String
    var confidence: Float
    var debug: String?
}

final class OnsetAnalyzer {

    // MARK: - Tunables (short-word friendly)

    private let emaAlpha: Float = 0.22
    private let cooldownSec: Double = 0.20

    // Calibration (pre-roll)
    private let calibrationSec: Double = 0.12

    // Detection threshold (more forgiving)
    private let thresholdFactor: Float = 1.22  // was 1.35
    private let minThreshold: Float = 0.005    // was 0.006

    // Capture windows
    private let maxCaptureSec: Double = 0.55
    private let stabilityWindowSec: Double = 0.22

    // Rise-time targets (ms) — wider window (less strict)
    private let riseGreatMin = 120
    private let riseGreatMax = 620
    private let riseGoodMin  = 90
    private let riseGoodMax  = 900

    // Roughness thresholds (less strict)
    private let roughGreatMax: Float = 0.30
    private let roughGoodMax: Float = 0.46

    // Stability thresholds (less strict)
    private let stabilityGreatMin: Float = 0.64
    private let stabilityGoodMin: Float = 0.48

    // MARK: - Audio step
    private var sampleRate: Double = 44100
    private var framesPerBuffer: Double = 1024
    private var dt: Double { framesPerBuffer / sampleRate }

    // MARK: - State
    private var rmsEMA: Float = 0
    private var noiseFloorEMA: Float = 0.01

    private var lastTriggerTime: CFAbsoluteTime = 0

    // Calibration
    private var isCalibrating: Bool = true
    private var calibrationFramesTarget: Int = 0
    private var calibrationFramesSeen: Int = 0
    private var calibrationSamples: [Float] = []

    // Capture
    private var isCapturing: Bool = false
    private var captureFramesTarget: Int = 0
    private var captureRMS: [Float] = []

    func reset(sampleRate: Double, framesPerBuffer: Double = 1024) {
        self.sampleRate = max(sampleRate, 8000)
        self.framesPerBuffer = max(framesPerBuffer, 256)

        rmsEMA = 0
        noiseFloorEMA = 0.01

        lastTriggerTime = 0

        isCalibrating = true
        calibrationFramesSeen = 0
        calibrationSamples.removeAll(keepingCapacity: true)
        calibrationFramesTarget = max(3, Int(calibrationSec / max(dt, 0.001)))

        isCapturing = false
        captureRMS.removeAll(keepingCapacity: true)
        captureFramesTarget = max(10, Int(maxCaptureSec / max(dt, 0.001)))
    }

    func process(rms: Float) -> OnsetMetrics? {

        rmsEMA = ema(ema: rmsEMA, x: rms, alpha: emaAlpha)
        let now = CFAbsoluteTimeGetCurrent()

        let thresholdNow = max(noiseFloorEMA * thresholdFactor, minThreshold)

        // 1) Calibration with early exit
        if isCalibrating {
            calibrationFramesSeen += 1
            calibrationSamples.append(min(rmsEMA, 0.06))

            if rmsEMA > thresholdNow * 1.15 {
                finalizeCalibration()
                isCapturing = true
                lastTriggerTime = now
                captureRMS.removeAll(keepingCapacity: true)
                return collect(rms: rmsEMA)
            }

            if calibrationFramesSeen >= calibrationFramesTarget {
                finalizeCalibration()
            }
            return nil
        }

        // Update baseline when idle
        if !isCapturing {
            let capped = min(rmsEMA, 0.06)
            noiseFloorEMA = ema(ema: noiseFloorEMA, x: capped, alpha: 0.06)
        }

        // Cooldown
        if now - lastTriggerTime < cooldownSec {
            if isCapturing { return collect(rms: rmsEMA) }
            return nil
        }

        let threshold = max(noiseFloorEMA * thresholdFactor, minThreshold)

        // 2) Detect onset
        if !isCapturing, rmsEMA > threshold {
            isCapturing = true
            lastTriggerTime = now
            captureRMS.removeAll(keepingCapacity: true)
        }

        // 3) Capture + score
        if isCapturing {
            return collect(rms: rmsEMA)
        }

        return nil
    }

    private func finalizeCalibration() {
        let med = robustMedian(calibrationSamples)
        noiseFloorEMA = max(ema(ema: noiseFloorEMA, x: med, alpha: 0.45), 0.004)
        isCalibrating = false
        calibrationSamples.removeAll(keepingCapacity: false)
    }

    private func collect(rms: Float) -> OnsetMetrics? {
        captureRMS.append(rms)

        if captureRMS.count >= captureFramesTarget {
            isCapturing = false
            return scoreSegment(captureRMS)
        }

        return nil
    }

    // MARK: - Scoring

    private func scoreSegment(_ w: [Float]) -> OnsetMetrics {

        guard w.count >= 10 else {
            return OnsetMetrics(
                score: 55,
                kind: .unknown,
                verdict: .notDetected,
                hint: "I couldn’t catch a clear start. Try a slightly clearer voice (still gentle).",
                confidence: 0.25,
                debug: "too-short"
            )
        }

        let baseCount = max(3, min(Int(0.06 / max(dt, 0.001)), w.count / 4))
        let baseline = robustMedian(Array(w.prefix(baseCount)))

        let peak = w.max() ?? baseline
        let range = max(peak - baseline, 0.00001)

        if range < max(minThreshold * 0.8, baseline * 0.45) {
            return OnsetMetrics(
                score: 58,
                kind: .unknown,
                verdict: .notDetected,
                hint: "I didn’t catch a clear start. Try closer to the mic.",
                confidence: 0.45,
                debug: "range=\(fmt(range)) baseline=\(fmt(baseline))"
            )
        }

        let a10 = baseline + 0.10 * range
        let a60 = baseline + 0.60 * range

        let i10 = firstIndex(in: w, valueAtLeast: a10) ?? 0
        let i60 = firstIndex(in: w, from: i10, valueAtLeast: a60)

        let riseTimeMs: Int? = {
            guard let i60, i60 >= i10 else { return nil }
            let sec = Double(i60 - i10) * dt
            return Int((sec * 1000).rounded())
        }()

        // Roughness
        let earlyCount = max(4, min(Int(Double(w.count) * 0.25), w.count - i10))
        let earlySlice = Array(w[i10 ..< min(w.count, i10 + earlyCount)])

        var maxJump: Float = 0
        if earlySlice.count >= 2 {
            for i in 1..<earlySlice.count {
                let jump = earlySlice[i] - earlySlice[i - 1]
                if jump > maxJump { maxJump = jump }
            }
        }
        let roughRatio = maxJump / range

        // Stability after 60%
        let stability: Float = {
            guard let i60 else { return 0.0 }
            let start = i60
            let postFrames = max(6, min(Int(stabilityWindowSec / max(dt, 0.001)), w.count - start))
            let end = min(w.count, start + postFrames)
            if end <= start + 2 { return 0.0 }

            let slice = Array(w[start..<end])
            let mean = slice.reduce(0, +) / Float(slice.count)
            guard mean > 0 else { return 0.0 }

            let varSum = slice.map { ($0 - mean) * ($0 - mean) }.reduce(0, +)
            let variance = varSum / Float(slice.count)
            return min(max(1.0 - (variance / (mean * mean + 0.0001)), 0.0), 1.0)
        }()

        // Confidence
        var confidence: Float = 0.58
        if i60 != nil { confidence += 0.18 }
        if range > (baseline * 0.9 + 0.005) { confidence += 0.10 }
        if w.count >= max(12, Int(0.28 / max(dt, 0.001))) { confidence += 0.08 }
        confidence = min(max(confidence, 0.25), 0.95)

        // Verdict
        let verdict: OnsetMetrics.Verdict = {
            guard let rt = riseTimeMs else { return .notDetected }

            let riseGreat = (rt >= riseGreatMin && rt <= riseGreatMax)
            let riseGood  = (rt >= riseGoodMin  && rt <= riseGoodMax)

            let roughGreat = roughRatio <= roughGreatMax
            let roughGood  = roughRatio <= roughGoodMax

            let stabGreat = stability >= stabilityGreatMin
            let stabGood  = stability >= stabilityGoodMin

            if riseGreat && roughGreat && stabGreat { return .great }
            if riseGood && roughGood && stabGood { return .good }
            return .tryAgain
        }()

        let kind: OnsetMetrics.Kind = {
            switch verdict {
            case .great, .good:
                return .soft
            case .tryAgain:
                if stability < 0.36 { return .noisy }
                return .hard
            case .notDetected:
                return .unknown
            }
        }()

        // Score
        var score = 78

        if let rt = riseTimeMs {
            if rt < riseGoodMin { score -= min(24, (riseGoodMin - rt) / 6) }
            else if rt > riseGoodMax { score -= min(12, (rt - riseGoodMax) / 28) }
            else { score += 8 }
        } else {
            score -= 12
        }

        if roughRatio > 0.52 { score -= 18 }
        else if roughRatio > roughGoodMax { score -= 10 }
        else if roughRatio <= roughGreatMax { score += 6 }

        if stability >= stabilityGreatMin { score += 8 }
        else if stability >= stabilityGoodMin { score += 4 }
        else if stability < 0.33 { score -= 7 }

        if confidence < 0.55 { score = min(max(score, 52), 90) }

        score = max(45, min(95, score))

        let hint: String = {
            switch verdict {
            case .great:
                return "Soft ramp ✅ Perfect."
            case .good:
                return "Nice 🟡 Try an even gentler fade-in."
            case .tryAgain:
                if roughRatio > 0.52 { return "Try: airflow first… then add voice slowly." }
                if let rt = riseTimeMs, rt < riseGoodMin { return "Try: slower fade-in at the start." }
                if stability < 0.38 { return "Try: steadier breath-out after you start." }
                return "Try again gently—slow build-up."
            case .notDetected:
                return "I couldn’t hear a clear start. Try a clearer but gentle voice."
            }
        }()

        let dbg = "v=\(verdict.rawValue) rt=\(riseTimeMs.map { "\($0)ms" } ?? "nil") rough=\(fmt(roughRatio)) stab=\(fmt(stability)) conf=\(fmt(confidence)) score=\(score)"

        return OnsetMetrics(
            score: score,
            kind: kind,
            verdict: verdict,
            hint: hint,
            confidence: confidence,
            debug: dbg
        )
    }

    // MARK: - Helpers

    private func ema(ema: Float, x: Float, alpha: Float) -> Float {
        alpha * x + (1 - alpha) * ema
    }

    private func robustMedian(_ x: [Float]) -> Float {
        guard !x.isEmpty else { return 0 }
        let s = x.sorted()
        let m = s.count / 2
        if s.count % 2 == 0 { return (s[m - 1] + s[m]) / 2 }
        return s[m]
    }

    private func firstIndex(in x: [Float], valueAtLeast v: Float) -> Int? {
        for i in 0..<x.count { if x[i] >= v { return i } }
        return nil
    }

    private func firstIndex(in x: [Float], from start: Int, valueAtLeast v: Float) -> Int? {
        guard start >= 0, start < x.count else { return nil }
        for i in start..<x.count { if x[i] >= v { return i } }
        return nil
    }

    private func fmt(_ v: Float) -> String { String(format: "%.2f", v) }
}
