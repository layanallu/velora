//
//  AppStrings.swift
//  Velora
//
//  Central strings (single source of truth)
//  - Includes legacy keys used by existing code (Exercise.swift, etc.)
//  - Includes new keys for Topic flow
//
//  Created by LAYAN on 03/09/1447 AH.
//

import Foundation

enum AppStrings {
    static let appName = "Velora"


    static let continueText = "Continue"
    static let getStarted = "Get Started"

    // MARK: - Home
    static let startSession = "Start Session"

    // MARK: - Topic Flow (NEW)
    static let topics = "Topics"
    static let readingPassages = "Reading Passages"
    static let realScenarios = "Real Scenarios"
    static let chooseCategoryTitle = "Choose your path"
    static let chooseCategorySubtitle = "Start with reading, or try a real-life scenario."


    // MARK: - Legacy ExerciseType strings (USED in Models/Exercise.swift)
    static let smoothStart = "Easy Onset"
    static let slowFlow = "Slow Flow"
    static let rhythmRide = "Rhythm Pacing"

    static let smoothStartDesc = "Start softly. One word at a time."
    static let slowFlowDesc = "Keep it steady. Stay relaxed."
    static let rhythmRideDesc = "Follow the gentle rhythm."
}
