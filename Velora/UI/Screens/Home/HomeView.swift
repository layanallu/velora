//
//  HomeView.swift
//  Velora
//
//  Step 2: Home Page (Minimal & Clean)
//  - Primary action: Start Session
//  - Velora present
//
//  Fixes:
//  ✅ Velora is now stable (no floating) on Home.
//  ✅ Start Session navigation works (no nested Button inside NavigationLink).
//
//  Created by LAYAN on 03/09/1447 AH.
//  Updated by Velora on 28/02/2026:
//  ✅ Preview no longer wraps its own NavigationStack to avoid confusion with the app-level stack.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 28)

                // ✅ Stable on Home: glow + breathe only (no "flying up/down")
                VeloraCharacterView(
                    expression: .smile,
                    size: 170,
                    gaze: .center
                )
                .frame(width: 170, height: 170)

                VStack(spacing: 12) {
                    Text("Ready when you are")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.ink)
                        .multilineTextAlignment(.center)

                    Text("A calm session.\nOne step at a time.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.ink.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 26)
                }

                Spacer()

                // ✅ Proper navigation (no nested Button)
                NavigationLink {
                    TopicCategoryView()
                } label: {
                    PrimaryButtonLabel(title: "Start Session", systemImage: "sparkles")
                }
                .simultaneousGesture(TapGesture().onEnded {
                    Haptics.tap()
                })
                .buttonStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.bottom, 50)
            }
        }
        .navigationTitle(AppStrings.appName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .preferredColorScheme(.light)
    }
}
