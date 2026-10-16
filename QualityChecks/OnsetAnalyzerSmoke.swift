//
//  OnsetAnalyzerSmoke.swift
//  Velora/QualityChecks (command-line only, not included in the app target)
//
//  Verify that stability fixes did not change the existing amplitude-envelope
//  analyzer's scoring contract. These synthetic signals are not human speech.
//
import Foundation

@main
struct OnsetAnalyzerSmoke {
    static func main() {
        var checks = 0

        func check(_ condition: Bool, _ label: String) {
            guard condition else {
                fputs("FAIL: \(label)\n", stderr)
                exit(1)
            }
            checks += 1
            print("PASS: \(label)")
        }

        func run(_ samples: [Float]) -> OnsetMetrics? {
            let analyzer = OnsetAnalyzer()
            analyzer.reset(sampleRate: 44_100, framesPerBuffer: 1_024)
            var result: OnsetMetrics?
            for value in samples {
                if let metric = analyzer.process(rms: value) {
                    result = metric
                }
            }
            return result
        }

        let silence = Array(repeating: Float(0.0003), count: 90)
        check(run(silence) == nil, "Silence never produces an assessed onset")

        let smoothRamp = (0..<90).map { i -> Float in
            if i < 12 { return 0.001 }
            if i < 43 { return 0.001 + Float(i - 12) * 0.0009 }
            return 0.029
        }
        let abruptRamp = (0..<90).map { i -> Float in
            return i < 12 ? 0.001 : 0.035
        }
        let shortSound = (0..<90).map { i -> Float in
            return i < 12 ? 0.001 : (i < 20 ? 0.022 : 0.001)
        }

        let smooth = run(smoothRamp)
        let abrupt = run(abruptRamp)
        let short = run(shortSound)

        check(smooth != nil, "Gradual onset produces acoustic metrics")
        check(abrupt != nil, "Abrupt onset produces acoustic metrics")
        check(short != nil, "Brief word produces a bounded result")

        for (label, metric) in [("gradual", smooth), ("abrupt", abrupt), ("brief", short)] {
            guard let metric else { continue }
            check((45...95).contains(metric.score), "\(label): score within legacy bounds")
            check((0...1).contains(metric.confidence), "\(label): confidence within bounds")
            check(!metric.hint.isEmpty, "\(label): actionable hint present")
        }

        print("OnsetAnalyzer smoke checks: \(checks) passed")
    }
}
