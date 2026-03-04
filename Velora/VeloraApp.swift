//
//  VeloraApp.swift
//  Velora
//
//  Created by LAYAN  on 03/09/1447 AH.
//

import SwiftUI

@main
struct VeloraApp: App {
    @StateObject private var persistence = PersistenceStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(persistence)
                .preferredColorScheme(.light)
        }
    }
}
