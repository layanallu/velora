//
//  SessionMode.swift
//  Velora
//
//  Small, removable switch for running the scenario engine in a guided "Preview" mode.
//  - Keeps the real experience intact (default = .normal)
//  - Lets judges quickly walk through screens without microphone / speech recognition friction
//
//  Created by Velora on 28/02/2026.
//

import Foundation

/// Controls whether the session runs normally (microphone + speech recognition)
/// or as a guided UI preview with simulated progression.
enum SessionMode: String, Codable, Hashable {
    case normal
    case demoPreview

    var isDemo: Bool { self == .demoPreview }
}
