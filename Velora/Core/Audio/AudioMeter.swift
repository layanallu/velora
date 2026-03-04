//
//  AudioMeter.swift
//  Velora
//
//  Real mic RMS meter (offline).
//  ✅ Requests microphone permission.
//  ✅ Publishes changes on MAIN thread (fixes background thread warning).
//  ✅ Provides a smoothed RMS for stable detection.
//
//  Created by LAYAN on 03/09/1447 AH.
//  Updated by Velora on 24/02/2026.
//

import Foundation
import Combine
import AVFoundation

@MainActor
final class AudioMeter: ObservableObject {
    @Published var rms: Float = 0               // raw-ish
    @Published var smoothedRMS: Float = 0       // stable for gating
    @Published var isRunning: Bool = false
    @Published var isAuthorized: Bool = false

    private let engine = AVAudioEngine()
    private var inputNode: AVAudioInputNode { engine.inputNode }

    // Smoothing factor: 0.0 = no smoothing, 1.0 = never changes
    // 0.85 gives a calm, stable envelope.
    private let smoothing: Float = 0.85

    /// Call before starting if you want a strict gate.
    func requestPermission() async -> Bool {
        let session = AVAudioSession.sharedInstance()

        // If already determined:
        switch session.recordPermission {
        case .granted:
            isAuthorized = true
            return true
        case .denied:
            isAuthorized = false
            return false
        case .undetermined:
            break
        @unknown default:
            break
        }

        return await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                Task { @MainActor in
                    self.isAuthorized = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func start() async throws {
        if isRunning { return }

        // Strict: require permission
        let ok = await requestPermission()
        guard ok else {
            isAuthorized = false
            return
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)

        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }

            let value = Self.calculateRMS(buffer: buffer)

            // Hop to main actor for publishing.
            Task { @MainActor in
                self.rms = value
                self.smoothedRMS = (self.smoothing * self.smoothedRMS) + ((1 - self.smoothing) * value)
            }
        }

        engine.prepare()
        try engine.start()

        isRunning = true
        rms = 0
        smoothedRMS = 0
    }

    func stop() {
        guard isRunning else { return }
        inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        rms = 0
        smoothedRMS = 0
    }

    private static func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let n = Int(buffer.frameLength)
        if n == 0 { return 0 }

        var sum: Float = 0
        for i in 0..<n {
            let x = channelData[i]
            sum += x * x
        }
        let mean = sum / Float(n)
        return sqrt(mean)
    }
}

