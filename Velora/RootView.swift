//
//  RootView.swift
//  Velora
//
//  ✅ Single NavigationStack for the whole app.
//  ✅ Hard reset supported even with NavigationLink(destination:)
//     by recreating the NavigationStack via .id(router.resetID).
//
//  Updated by Velora on 28/02/2026:
//  ✅ Home button works reliably (hard reset).
//

import SwiftUI
import Combine

// MARK: - App Router (single source of truth)

@MainActor
final class AppRouter: ObservableObject {

    /// ✅ When this changes, RootView recreates the NavigationStack,
    /// which guarantees a real "pop to root" even if navigation uses destination links.
    @Published var resetID: UUID = UUID()

    func goHome() {
        resetID = UUID()
    }
}

struct RootView: View {
    @EnvironmentObject private var persistence: PersistenceStore
    @StateObject private var router = AppRouter()

    var body: some View {
        Group {
            if persistence.hasCompletedOnboarding {
                NavigationStack {
                    HomeView()
                }
                // ✅ This is the magic: hard-reset the entire stack.
                .id(router.resetID)
                .environmentObject(router)
            } else {
                OnboardingView()
                    .environmentObject(router) // harmless + keeps env consistent
            }
        }
    }
}

// MARK: - Preview
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        let store = PersistenceStore()
        store.hasCompletedOnboarding = true

        return RootView()
            .environmentObject(store)
            .preferredColorScheme(.light)
    }
}

