//
//  Persistence.swift
//  Velora
//
//  Created by Layan on 05/09/1447 AH.
//
//
//  Persistence.swift
//  Velora
//
//  Created by LAYAN  on 03/09/1447 AH.
//

import Foundation
import Combine

/// A tiny persistence layer that stays Swift Student Challenge friendly:
/// - Offline only
/// - No tracking
/// - Simple local UserDefaults storage
final class PersistenceStore: ObservableObject {

    // MARK: - Keys
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
    }

    // MARK: - Published State
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    /// Session history (in-memory for now).
    /// Later we can serialize this into JSON in UserDefaults (still offline).
    @Published var records: [SessionRecord] = []

    // MARK: - Init
    init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding)
    }

    // MARK: - Records
    func addRecord(_ record: SessionRecord) {
        records.insert(record, at: 0)
    }
}
