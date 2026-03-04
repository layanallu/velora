//
//  OnboardingPage.swift
//  Velora
//
//  Minimal onboarding page model.
//  - Supports swipe onboarding with per-page expression.
//  - Allows optional hint text (shown only on specific pages).
//
//  Created by LAYAN on 03/09/1447 AH.
//  Updated by Velora on 27/02/2026.
//

import SwiftUI

struct OnboardingPage: Identifiable {
    let id: UUID = UUID()

    let title: String
    let body: String

    /// Facial vibe (kept consistent with your VeloraCharacterView system)
    let expression: BubbleExpression

    /// Optional hint shown under page dots (only used on page 1).
    let hint: String?
}
