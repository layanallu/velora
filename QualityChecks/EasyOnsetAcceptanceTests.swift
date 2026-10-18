//
//  EasyOnsetAcceptanceTests.swift
//  Velora/QualityChecks
//
//  Test the acoustic gate separately from transcript matching. These are
//  deterministic decisions, not clinical speech samples.
//
import Foundation

@main
struct EasyOnsetAcceptanceTests {
    static func main() {
        var total = 0
        func expect(_ result: EasyOnsetAcceptance.Decision,
                    equals target: EasyOnsetAcceptance.Decision,
                    _ label: String) {
            precondition(result == target, label)
            total += 1
        }
        func decision(_ verdict: OnsetMetrics.Verdict,
                      _ kind: OnsetMetrics.Kind,
                      _ confidence: Float,
                      _ score: Int,
                      _ words: [String] = ["ocean", "waves", "roll", "onto", "the", "sand"])
            -> EasyOnsetAcceptance.Decision {
            EasyOnsetAcceptance.classify(
                verdict: verdict,
                kind: kind,
                confidence: confidence,
                score: score,
                expectedWords: words
            )
        }

        expect(decision(.good, .soft, 0.85, 86), equals: .accepted,
               "A recognized gentle start passes")
        expect(decision(.great, .soft, 0.94, 91), equals: .accepted,
               "A recognized great onset passes")
        expect(decision(.tryAgain, .hard, 0.90, 95), equals: .retryGentler,
               "A long phrase with a high score cannot override an abrupt verdict")
        expect(decision(.tryAgain, .noisy, 0.90, 95), equals: .uncertain,
               "Noise does not become evidence of user error")
        expect(decision(.tryAgain, .hard, 0.60, 95), equals: .uncertain,
               "Low-confidence rough onset gets a neutral retry")
        expect(decision(.notDetected, .unknown, 0.95, 95), equals: .uncertain,
               "Missing acoustic evidence never becomes a pass")
        expect(decision(.good, .soft, 0.40, 95), equals: .uncertain,
               "Noisy or weak evidence cannot be automatic success")
        expect(decision(.tryAgain, .hard, 0.90, 95, ["hi"]), equals: .retryGentler,
               "Short initial words do not override a hard acoustic verdict")
        expect(decision(.good, .soft, 0.91, 85, ["paper"]), equals: .accepted,
               "Existing plosive adaptation keeps positive onsets valid")
        print("PASS: \(total) onset-decision safeguards")
    }
}
