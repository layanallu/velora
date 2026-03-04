//
//  TechniqueIntroStore.swift
//  Velora
//
//  Persist "seen" state for technique intro cards.
//  Offline-only, using UserDefaults.
//
//  Updated by Velora on 27/02/2026.
//

import Foundation

enum TechniqueIntroStore {

    private static let prefix = "velora.techniqueIntro.seen."

    static func hasSeen(_ technique: TechniqueKind) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: technique))
    }

    static func markSeen(_ technique: TechniqueKind) {
        UserDefaults.standard.set(true, forKey: key(for: technique))
    }

    private static func key(for technique: TechniqueKind) -> String {
        prefix + technique.rawValue
    }
}
