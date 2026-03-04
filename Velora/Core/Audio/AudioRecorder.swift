
//
//  AudioRecorder.swift
//  Velora
//
//  Records Rhythm mic segments (multiple start/stop) then merges them into ONE file.
//  Offline, no network, no external libs.
//
//  Design:
//  - We record each mic-run as a segment (.caf PCM).
//  - At the end of Rhythm, we concatenate segments into a single "rhythm_full.caf".
//  - Feedback plays the merged file.
//
//  Created by Velora on 26/02/2026.
//

import Foundation
import AVFoundation

enum AudioRecorder {

    // Folder: Documents/VeloraRecordings
    private static var recordingsFolderURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("VeloraRecordings", isDirectory: true)
        if FileManager.default.fileExists(atPath: folder.path) == false {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    static func makeSegmentURL() -> URL {
        let name = "rhythm_seg_\(UUID().uuidString).caf"
        return recordingsFolderURL.appendingPathComponent(name)
    }

    static func makeMergedURL(topicID: String) -> URL {
        let safe = topicID.replacingOccurrences(of: "[^a-zA-Z0-9_\\-]", with: "_", options: .regularExpression)
        let name = "rhythm_full_\(safe)_\(Int(Date().timeIntervalSince1970)).caf"
        return recordingsFolderURL.appendingPathComponent(name)
    }

    /// Concatenate segment CAF files into ONE CAF (PCM).
    /// Assumes same format (which is true if recorded on same device session).
    static func mergeSegments(_ segments: [URL], outputURL: URL) -> URL? {
        let existing = segments.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard existing.isEmpty == false else { return nil }

        do {
            // Use format from the first segment
            let firstFile = try AVAudioFile(forReading: existing[0])
            let format = firstFile.processingFormat

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try? FileManager.default.removeItem(at: outputURL)
            }

            let outFile = try AVAudioFile(forWriting: outputURL, settings: format.settings)

            // Append each segment
            for url in existing {
                let inFile = try AVAudioFile(forReading: url)
                let frameCount = AVAudioFrameCount(inFile.length)

                guard let buffer = AVAudioPCMBuffer(pcmFormat: inFile.processingFormat, frameCapacity: frameCount) else {
                    continue
                }

                try inFile.read(into: buffer)
                try outFile.write(from: buffer)
            }

            return outputURL
        } catch {
            return nil
        }
    }

    /// Convenience: delete temporary segments after merge.
    static func cleanup(_ segments: [URL]) {
        for url in segments {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
