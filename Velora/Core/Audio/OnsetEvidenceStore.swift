//
//  OnsetEvidenceStore.swift
//  Velora/Core/Audio
//
//  Thread-safe handoff for completed Easy Onset measurements.
//
//  The audio tap produces an onset result on an audio callback thread, while
//  SFSpeechRecognizer can recognize the target phrase on the main thread
//  before a queued UI update has run. The session uses this store to retrieve
//  completed evidence synchronously BEFORE closing the microphone.
//
//  Important: This store does not analyze partial recordings, infer a verdict,
//  modify scoring thresholds, or turn missing evidence into a success.
//  Generation IDs prevent an old audio callback from affecting a new attempt.
//  The FIRST completed result is held for that attempt; a later spoken word
//  cannot make an initially difficult/unclear start pass by overwriting it.
//

import Foundation

final class OnsetEvidenceStore {
    private let lock = NSLock()
    private var activeGeneration: UUID?
    // First completed acoustic onset wins for this microphone attempt. This
    // includes .notDetected: a later word must never turn a missing/unclear
    // FIRST start into a pass. A new generation resets the decision.
    private var firstCompleted: OnsetMetrics?

    func begin(generation: UUID) {
        lock.lock()
        defer { lock.unlock() }
        activeGeneration = generation
        firstCompleted = nil
    }

    func recordCompleted(_ metrics: OnsetMetrics, generation: UUID) {
        lock.lock()
        defer { lock.unlock() }
        guard activeGeneration == generation else { return }
        guard firstCompleted == nil else { return }
        firstCompleted = metrics
    }

    func snapshot(generation: UUID) -> OnsetMetrics? {
        lock.lock()
        defer { lock.unlock() }
        guard activeGeneration == generation else { return nil }
        return firstCompleted
    }

    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        activeGeneration = nil
        firstCompleted = nil
    }
}
