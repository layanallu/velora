//
//  OnsetEvidenceStoreTests.swift
//  Foundation-only regression tests (not included in the app target).
//
//  The training goal is the FIRST detected acoustic onset of each attempt.
//  A later part of the phrase must not overwrite that result, whether the
//  original measurement was supportive, difficult or inconclusive.
//

import Foundation

@main
struct OnsetEvidenceStoreTests {
    static func main() {
        var count = 0
        func check(_ condition: Bool, _ label: String) {
            guard condition else { fatalError("FAIL: \(label)") }
            count += 1
            print("PASS: \(label)")
        }

        let store = OnsetEvidenceStore()
        let a = UUID()
        let b = UUID()
        let gentle = OnsetMetrics(score: 89, kind: .soft, verdict: .good,
                                  hint: "Gentle", confidence: 0.91, debug: nil)
        let abrupt = OnsetMetrics(score: 48, kind: .hard, verdict: .tryAgain,
                                  hint: "Softer start", confidence: 0.88, debug: nil)
        let uncertain = OnsetMetrics(score: 55, kind: .unknown, verdict: .notDetected,
                                    hint: "Uncertain", confidence: 0.25, debug: nil)

        check(store.snapshot(generation: a) == nil, "No evidence before attempt")
        store.begin(generation: a)
        check(store.snapshot(generation: a) == nil, "New attempt starts with no evidence")
        store.recordCompleted(gentle, generation: b)
        check(store.snapshot(generation: a) == nil, "Ignore wrong generation")
        store.recordCompleted(abrupt, generation: a)
        check(store.snapshot(generation: a) == abrupt, "First difficult start is captured")
        store.recordCompleted(gentle, generation: a)
        check(store.snapshot(generation: a) == abrupt, "Later gentle word cannot erase difficult start")
        store.recordCompleted(uncertain, generation: a)
        check(store.snapshot(generation: a) == abrupt, "Later uncertainty cannot replace first result")
        check(store.snapshot(generation: b) == nil, "Wrong generation cannot read result")

        store.begin(generation: b)
        check(store.snapshot(generation: b) == nil, "New generation clears old evidence")
        store.recordCompleted(gentle, generation: a)
        check(store.snapshot(generation: b) == nil, "Late old-attempt result ignored")
        store.recordCompleted(gentle, generation: b)
        store.recordCompleted(abrupt, generation: b)
        check(store.snapshot(generation: b) == gentle, "Later rough sound does not erase good first start")

        let c = UUID()
        store.begin(generation: c)
        store.recordCompleted(uncertain, generation: c)
        store.recordCompleted(gentle, generation: c)
        check(store.snapshot(generation: c) == uncertain, "Unclear first onset never becomes a free pass")
        store.invalidate()
        check(store.snapshot(generation: c) == nil, "Stop clears evidence")
        store.recordCompleted(gentle, generation: c)
        check(store.snapshot(generation: c) == nil, "Stopped audio cannot record a new result")

        // In production the audio tap and main thread can access the store
        // concurrently. Keep a fixed first result and try to overwrite it.
        let d = UUID()
        store.begin(generation: d)
        store.recordCompleted(abrupt, generation: d)
        DispatchQueue.concurrentPerform(iterations: 300) { index in
            store.recordCompleted(index.isMultiple(of: 2) ? gentle : uncertain, generation: d)
            _ = store.snapshot(generation: d)
        }
        check(store.snapshot(generation: d) == abrupt, "Concurrent updates preserve first result")
        store.invalidate()
        check(store.snapshot(generation: d) == nil, "Concurrent result can be invalidated")

        // Keep the baseline onset estimator unchanged and guard against
        // noise-free silence being interpreted as an onset.
        let analyzer = OnsetAnalyzer()
        analyzer.reset(sampleRate: 44_100, framesPerBuffer: 1_024)
        let silentSamples = Array(repeating: Float(0.0003), count: 90)
        var completed: OnsetMetrics?
        for sample in silentSamples {
            if let result = analyzer.process(rms: sample) { completed = result }
        }
        check(completed == nil, "Silence does not create an onset result")

        print("First onset evidence checks: \(count) passed")
    }
}
