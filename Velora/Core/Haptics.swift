//
//  Haptics.swift
//  Velora
//
//  Centralized haptic utility
//  - Supports legacy calls: soft()
//  - Supports new calls: tap(), success()
//
//  Created by LAYAN on 03/09/1447 AH.
//

import UIKit

enum Haptics {

    // MARK: - Legacy
    /// Legacy name used in some UI components (e.g. PrimaryButton)
    static func soft() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Current
    /// Preferred name for taps
    static func tap() {
        soft()
    }

    /// Success feedback (completion moments)
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Optional future use
    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Optional future use
    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}
