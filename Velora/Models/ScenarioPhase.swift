//
//  ScenarioPhase.swift
//  Velora
//
//  Source of truth for the Live Scenario Engine flow.
//  - IMPORTANT: Breathing happens BEFORE SessionView (BreathingGateView).
//  - Timeline inside SessionView: Breathing (done) -> Easy Onset -> Rhythm
//  - Feedback is a separate screen (not part of timeline).
//
//  Created by Layan on 05/09/1447 AH.
//

import Foundation

enum ScenarioPhase: String, CaseIterable, Codable {
    case easyOnset
    case rhythmPacing
    case feedback
}
