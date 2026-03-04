//
//  AudioPlayback.swift
//  Velora
//
//  Playback + metering for reactive waveform UI.
//  Uses AVAudioPlayer (offline, simple, reliable).
//
//  Created by Velora on 26/02/2026.
//  Updated by Velora on 28/02/2026:
//  ✅ Added bundled audio helpers (loadBundled / playBundled)
//  ✅ Added AVAudioSession configuration for reliable playback
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioPlayback: NSObject, ObservableObject, AVAudioPlayerDelegate {

    @Published var isPlaying: Bool = false
    @Published var level: Float = 0        // 0...1 (meter smoothed)
    @Published var didFinish: Bool = false

    private var player: AVAudioPlayer?
    private var meterTimer: Timer?

    func load(url: URL) {
        stop()

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.isMeteringEnabled = true
            p.delegate = self
            p.prepareToPlay()
            player = p
            level = 0
            didFinish = false
        } catch {
            player = nil
        }
    }

    // MARK: - Bundled audio helpers

    /// Loads a file that exists in the app bundle (e.g. "My Name Is.m4a").
    func loadBundled(named fileName: String, ext: String) {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: ext) else {
            // ✅ If it doesn't play, most likely:
            // - Target Membership is off
            // - Not in Copy Bundle Resources
            // - Name mismatch (spaces / capitalization)
            return
        }
        load(url: url)
    }

    /// Loads + plays bundled file immediately.
    func playBundled(named fileName: String, ext: String) {
        loadBundled(named: fileName, ext: ext)
        play()
    }

    func play() {
        guard let player else { return }

        configureAudioSessionForPlayback()

        didFinish = false
        player.play()
        isPlaying = true
        startMeter()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopMeter()
        level = 0

        deactivateAudioSessionIfNeeded()
    }

    func stop() {
        player?.stop()
        isPlaying = false
        stopMeter()
        level = 0

        deactivateAudioSessionIfNeeded()
    }

    func toggle() {
        isPlaying ? pause() : play()
    }

    private func startMeter() {
        stopMeter()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard let player else { return }
            guard self.isPlaying else { return }

            player.updateMeters()

            // AVAudioPlayer meter is in dB: [-160...0]
            let db = player.averagePower(forChannel: 0)
            let normalized = Self.dbTo01(db)

            // Smooth (avoid jitter)
            self.level = self.level * 0.78 + normalized * 0.22
        }
    }

    private func stopMeter() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        didFinish = true
        stopMeter()
        level = 0

        deactivateAudioSessionIfNeeded()
    }

    // MARK: - Audio Session

    private func configureAudioSessionForPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            // If session fails, playback may still work, but this increases reliability.
        }
    }

    private func deactivateAudioSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Let other audio resume nicely.
            try session.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch { }
    }

    private static func dbTo01(_ db: Float) -> Float {
        // Map [-55...0] into [0...1] (forgiving)
        let clamped = max(-55, min(0, db))
        let t = (clamped + 55) / 55
        // Slight curve so low sounds still move
        return powf(t, 1.6)
    }
}
