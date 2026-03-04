//
//  AudioSampleButton.swift
//  Velora
//
//  Plays a bundled audio sample (offline).
//  Default sample: "My Name Is.m4a"
//
//  Created by Velora on 27/02/2026.
//  Updated by Velora on 28/02/2026:
//  ✅ Now plays bundled sample via AudioPlayback
//

import SwiftUI

struct AudioSampleButton: View {

    /// Bundled file name without extension (e.g. "My Name Is")
    var sampleFileName: String = "My Name Is"
    /// File extension (e.g. "m4a")
    var sampleFileExtension: String = "m4a"

    @StateObject private var playback = AudioPlayback()

    var body: some View {
        Button {
            Haptics.tap()
            playback.playBundled(named: sampleFileName, ext: sampleFileExtension)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "headphones")
                    .font(.system(size: 16, weight: .semibold))
                Text("Listen to a sample")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(AppTheme.ink.opacity(0.82))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.paper.opacity(0.70))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppTheme.ink.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Audio sample"))
    }
}

// MARK: - Preview

struct AudioSampleButton_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            AudioSampleButton()
        }
        .preferredColorScheme(.light)
    }
}
