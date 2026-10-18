//
//  AudioRecorder.swift
//  Velora
//
//  Session-only Rhythm audio storage and CAF segment merging.
//  No network, account, or persistent session recording history.
//
//  Privacy lifecycle:
//  - Record temporary segments in Caches/VeloraRecordings (not Documents).
//  - Merge the segments for playback exclusively on the Feedback screen.
//  - Delete segment files after merging or abandoning Rhythm practice.
//  - Delete the merged file when the session/Feedback screen closes.
//  - At next launch, clean recordings left after an unexpected termination,
//    including files made by older releases in Documents/VeloraRecordings.
//

import Foundation
import AVFoundation

enum AudioRecorder {

    // MARK: - Private, non-backed-up storage

    // Maintenance never runs at app launch. All first-use preparation and
    // segment URL creation are serialized so cleanup cannot remove a new file.
    // This preserves interrupted-session privacy without blocking Home.
    private static let maintenanceQueue = DispatchQueue(
        label: "velora.recording-maintenance", qos: .utility
    )
    private static var hasPreparedStorage = false

    /// Begin maintenance during the 60-second breathing ritual, not cold launch.
    /// The Rhythm recording URL call below provides a barrier if it is unfinished.
    static func prepareStorageInBackground() {
        maintenanceQueue.async {
            guard !hasPreparedStorage else { return }
            cleanupAbandonedRecordingsOnLaunch()
            hasPreparedStorage = true
        }
    }

    private static func ensureStorageReadyBeforeRecording() {
        maintenanceQueue.sync {
            guard !hasPreparedStorage else { return }
            cleanupAbandonedRecordingsOnLaunch()
            hasPreparedStorage = true
        }
    }

    private static let folderName = "VeloraRecordings"

    private static var recordingsFolderURL: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Only this app-owned recording folder is ever used for live playback.
    static func recordingURL(for filename: String) -> URL? {
        guard filename == (filename as NSString).lastPathComponent,
              filename.hasPrefix("rhythm_full_"),
              filename.hasSuffix(".caf") else { return nil }
        return recordingsFolderURL.appendingPathComponent(filename, isDirectory: false)
    }

    static func makeSegmentURL() -> URL {
        // Never allow legacy cleanup to overlap a newly created recording.
        ensureStorageReadyBeforeRecording()
        return recordingsFolderURL.appendingPathComponent("rhythm_seg_\(UUID().uuidString).caf")
    }

    static func makeMergedURL(topicID: String) -> URL {
        let safeTopic = topicID.replacingOccurrences(
            of: "[^a-zA-Z0-9_\\-]", with: "_", options: .regularExpression
        )
        // UUIDs prevent two quick sessions from sharing the same output path.
        return recordingsFolderURL.appendingPathComponent(
            "rhythm_full_\(safeTopic)_\(UUID().uuidString).caf"
        )
    }

    // MARK: - Audio file processing

    /// Concatenate compatible PCM CAF segments, preserving the Feedback replay.
    /// If merging fails, discard the incomplete output instead of retaining it.
    static func mergeSegments(_ segments: [URL], outputURL: URL) -> URL? {
        let existing = segments.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { return nil }

        do {
            let firstFile = try AVAudioFile(forReading: existing[0])
            let format = firstFile.processingFormat

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }

            let output = try AVAudioFile(forWriting: outputURL, settings: format.settings)
            for url in existing {
                let input = try AVAudioFile(forReading: url)
                let frameCount = AVAudioFrameCount(input.length)
                guard frameCount > 0,
                      let buffer = AVAudioPCMBuffer(
                        pcmFormat: input.processingFormat,
                        frameCapacity: frameCount
                      ) else { continue }

                try input.read(into: buffer)
                try output.write(from: buffer)
            }
            return outputURL
        } catch {
            cleanup([outputURL])
            return nil
        }
    }

    /// Delete only the app-created file URLs passed in by Rhythm practice.
    static func cleanup(_ files: [URL]) {
        for url in files {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Remove the recording associated with one completed session.
    static func cleanupMergedRecording(named filename: String?) {
        guard let filename, let url = recordingURL(for: filename) else { return }
        cleanup([url])
    }

    /// Clear orphaned files from previous sessions before the next recording.
    /// Called only through the serialized maintenance queue. Never run it while
    /// a Rhythm recording is active; older files in Documents are handled too.
    static func cleanupAbandonedRecordingsOnLaunch() {
        let fileManager = FileManager.default
        let current = recordingsFolderURL
        let legacy = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent(folderName, isDirectory: true)

        for folder in [current, legacy].compactMap({ $0 }) {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: nil
            ) else { continue }
            for url in contents where url.pathExtension.lowercased() == "caf" {
                try? fileManager.removeItem(at: url)
            }
        }
    }
}
