//
//  TechniqueKind.swift
//  Velora
//
//  Technique cards content (Breathing / Easy Onset / Rhythm).
//  Includes example views for the centered modal card.
//
//  Updated by Velora on 27/02/2026:
//  ✅ Fixed BreathingExampleView call (it takes no arguments).
//

import SwiftUI

enum TechniqueKind: String, CaseIterable, Identifiable {
    case breathing
    case easyOnset
    case rhythm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breathing: return "Breathing"
        case .easyOnset: return "Easy Onset"
        case .rhythm: return "Rhythm Pacing"
        }
    }

    var intro: String {
        switch self {
        case .breathing:
            return "A calm entry ritual\nto help your body feel steady"
        case .easyOnset:
            return "A softer start\nso speech feels easier"
        case .rhythm:
            return "Bubbles help you pace\nyour words with calm spacing"
        }
    }

    var bullets: [String] {
        switch self {
        case .breathing:
            return [
                "Match Velora’s Breathe In/Out",
                "Let your shoulders and jaw soften",
                "Stay with the rhythm for one minute"
            ]

        case .easyOnset:
            return [
                "Watch the tutorial, then tap the mic",
                "Follow the karaoke all the way through",
                "Start with air—then add your voice"
            ]

        case .rhythm:
            return [
                "Pop bubbles by speaking word by word",
                "One bubble = one word",
                "Follow the pulse to stay steady"
            ]
        }
    }

    var closing: String {
        switch self {
        case .breathing:
            return "When you feel settled\nyou’ll be ready to speak"
        case .easyOnset:
            return "Soft start first\nthen continue at a normal pace"
        case .rhythm:
            return "One word per bubble\ncalm and steady"
        }
    }

    @ViewBuilder
    func exampleView(audioTap: @escaping () -> Void) -> some View {
        switch self {
        case .breathing:
            BreathingExampleView()

        case .easyOnset:
            EasyOnsetExampleView(onTapAudio: audioTap)

        case .rhythm:
            RhythmExampleView()
        }
    }
}

