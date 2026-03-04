//
//  OnboardingView.swift
//  Velora
//
//  Step 1: Onboarding (Minimal & Soft) — Swipe-based
//
//  ✅ Horizontal swipe (TabView) — no Continue button
//  ✅ Page dots visible
//  ✅ Hint text "Swipe to continue" ONLY on first page
//  ✅ Skip button for user control
//  ✅ Velora size ثابت (مطابق لثيم السلاسة مع باقي الصفحات)
//  ✅ Copy updated (English only, psychologically safe)
//  ✅ Last page uses happy eyes + button title is NOT "Start"
//
//  Created by LAYAN on 03/09/1447 AH.
//  Updated by Velora on 27/02/2026.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var persistence: PersistenceStore
    @State private var index: Int = 0
    
    // MARK: - Content (English only, short + safe)
    private let pages: [OnboardingPage] = [
        .init(
            title: "A gentle start",
            body: "Speaking can feel heavy sometimes.",
            expression: .smile,
            hint: "Swipe to continue"
        ),
        .init(
            title: "No rush here",
            body: "You don’t have to push through words.",
            expression: .gentle, // ✅ changed from focused → gentle
            hint: nil
        ),
        .init(
            title: "One word at a time",
            body: "We’ll take it slowly — together.",
            expression: .smile,
            hint: nil
        )
    ]
    
    // Keep fixed to preserve “same character size across app” feel.
    private let characterSize: CGFloat = 160
    
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            VStack(spacing: 22) {
                // Top bar (Skip)
                HStack {
                    Spacer()
                    
                    Button {
                        persistence.hasCompletedOnboarding = true
                    } label: {
                        Text("Skip")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.ink.opacity(0.55))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Skip onboarding")
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                
                Spacer(minLength: 10)
                
                // Swipe pages
                TabView(selection: $index) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { i, page in
                        pageView(page, pageIndex: i)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: index)
                
                // Dots + hint
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { i in
                            Capsule()
                                .fill(i == index ? AppTheme.ink : AppTheme.ink.opacity(0.18))
                                .frame(width: i == index ? 22 : 10, height: 8)
                                .animation(.spring(response: 0.35, dampingFraction: 0.9), value: index)
                                .accessibilityHidden(true)
                        }
                    }
                    
                    if let hint = pages[index].hint {
                        Text(hint)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.ink.opacity(0.38))
                            .transition(.opacity)
                            .accessibilityLabel(hint)
                    } else {
                        // Keep layout stable (no jump).
                        Color.clear.frame(height: 16)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.top, 6)
                
                Spacer()
                
                // Only show final button on last page (soft close, no "Start" spam)
                if index == pages.count - 1 {
                    PrimaryButton(
                        title: "I’m ready",
                        systemImage: "arrow.right"
                    ) {
                        persistence.hasCompletedOnboarding = true
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 50)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    // Keep bottom spacing consistent across pages.
                    Color.clear
                        .frame(height: 76)
                        .padding(.bottom, 18)
                        .accessibilityHidden(true)
                }
            }
        }
    }
    
    // MARK: - Page Layout
    private func pageView(_ page: OnboardingPage, pageIndex: Int) -> some View {
        let isLast = (pageIndex == pages.count - 1)
        
        // Subtle-but-visible variation per page (no size change)
        let gaze: EyeGaze = {
            switch pageIndex {
            case 1: return .up       // page 2 looks slightly upward = “with you”
            default: return .center
            }
        }()
        
        let eyeState: EyeState = {
            switch pageIndex {
            case 1: return .blink    // page 2: soft blink vibe (calming)
            case 2: return .happy    // page 3: happy eyes closure
            default: return .open
            }
        }()
        
        let blush: CGFloat = {
            switch pageIndex {
            case 1: return 0.25
            case 2: return 0.60
            default: return 0.0
            }
        }()
        
        return VStack(spacing: 22) {
            VeloraCharacterView(
                expression: page.expression,
                size: characterSize,
                gaze: gaze,
                eyeState: isLast ? .happy : eyeState,
                motionStyle: .subtle,
                mouthMode: .curve,
                blushBoost: blush
            )
            
            VStack(spacing: 10) {
                Text(page.title)
                    .font(AppTheme.titleFont)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(AppTheme.ink)
                
                Text(page.body)
                    .font(AppTheme.subtitleFont)
                    .foregroundStyle(AppTheme.ink.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
            }
            .padding(.horizontal, 6)
        }
        .padding(.top, 6)
    }
}

// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        // IMPORTANT:
        // You can swipe pages in preview on device/simulator.
        // If preview doesn’t respond to swipes (sometimes on mac previews),
        // run it on iPhone Simulator for the real feel.
        OnboardingPreviewHarness()
            .preferredColorScheme(.light)
    }

    private struct OnboardingPreviewHarness: View {
        @StateObject private var store = PersistenceStore()

        var body: some View {
            NavigationStack {
                OnboardingView()
                    .environmentObject(store)
            }
        }
    }
}
