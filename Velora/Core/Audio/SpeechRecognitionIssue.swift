//
//  SpeechRecognitionIssue.swift
//  Velora/Core/Audio
//
//  Human-readable reasons why offline speech cannot continue.
//  Kept independent of SwiftUI so the same diagnostic can be used by
//  Easy Onset and Rhythm Pacing and verified with lightweight tests.
//
//  A working microphone does not imply a working Speech service.
//  These issues never grant an Easy Onset success or alter scores.
//

import Foundation

enum SpeechRecognitionIssue: Equatable {
    case permissionRequired
    case onDeviceEnglishUnavailable
    case dictationDisabled
    case dictationResourcesUnavailable
    case serviceInterrupted
    case microphoneUnavailable

    var title: String {
        switch self {
        case .permissionRequired: return "Speech Access Needed"
        case .onDeviceEnglishUnavailable: return "Offline Speech Unavailable"
        case .dictationDisabled: return "Dictation Is Turned Off"
        case .dictationResourcesUnavailable: return "English Speech Setup Needed"
        case .serviceInterrupted: return "Speech Recognition Unavailable"
        case .microphoneUnavailable: return "Microphone Unavailable"
        }
    }

    var message: String {
        switch self {
        case .permissionRequired:
            return "Velora needs Microphone and Speech Recognition access. Open Settings and allow both, then return to try again."
        case .onDeviceEnglishUnavailable:
            return "This device cannot currently use English (US) speech recognition offline. You can check Settings > General > Keyboard > Dictation Languages, then try again."
        case .dictationDisabled:
            return "On-device speech may need Dictation enabled. In Settings, go to General > Keyboard > Enable Dictation, then return to Velora."
        case .dictationResourcesUnavailable:
            return "English (US) recognition resources may not be ready. Check Settings > General > Keyboard > Dictation Languages and allow the language resources to finish installing."
        case .serviceInterrupted:
            return "The iPhone speech service stopped responding. Check Velora's permissions, then Settings > General > Keyboard > Enable Dictation and English (US). If those are already enabled, try again or restart your iPhone."
        case .microphoneUnavailable:
            return "Velora couldn't start the microphone. Check Microphone access in Settings, then return and try again."
        }
    }

    /// Settings opens Velora's own app settings. iOS does not provide a
    /// public deep link straight to General > Keyboard > Dictation Languages.
    var offersSettings: Bool { true }

    /// The concrete Speech codes are documented by Apple. A code 1110
    /// means no words were recognized, not that the system service failed.
    static func from(error: NSError) -> SpeechRecognitionIssue? {
        switch (error.domain, error.code) {
        case ("kAFAssistantErrorDomain", 301):
            return nil
        case ("kAFAssistantErrorDomain", 1110):
            return nil
        case ("kAFAssistantErrorDomain", 1700):
            return .permissionRequired
        case ("kAFAssistantErrorDomain", 1100),
             ("kAFAssistantErrorDomain", 1101),
             ("kAFAssistantErrorDomain", 1107):
            return .serviceInterrupted
        case ("kLSRErrorDomain", 102):
            return .dictationResourcesUnavailable
        case ("kLSRErrorDomain", 201):
            return .dictationDisabled
        case ("NSCocoaErrorDomain", 4097):
            return .serviceInterrupted
        default:
            return .serviceInterrupted
        }
    }
}
