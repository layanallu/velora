//
//  HomeView.swift
//  Velora
//
//  Home is intentionally simple: a calm character, one primary action,
//  and a discreet but accessible link to the published Privacy Policy.
//
//  The privacy link is kept below Start Session, outside the primary action,
//  so it never interferes with starting a speaking session.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 28)

                // Stable character: soft glow and breathing, no floating on Home.
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

                VStack(spacing: 4) {
                    // Primary action remains unchanged, including haptic feedback.
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

                    // Required in-app privacy access (App Review Guideline 5.1.1).
                    // The label is visually understated while the touch area is 44pt.
                    if let privacyPolicyURL = URL(string: "https://layanallu.github.io/velora/") {
                        Link(destination: privacyPolicyURL) {
                            Text("Privacy Policy")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .underline()
                                .foregroundStyle(AppTheme.ink.opacity(0.55))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens Velora's privacy policy in Safari")
                    }
                }
                .padding(.bottom, 5)
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
