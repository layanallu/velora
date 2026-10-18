//
//  SpeechRecoveryAlertModifier.swift
//  Velora/UI/Component
//
//  One shared recovery alert for both speech techniques.
//  We explain that Open Settings leads to Velora's app-specific settings;
//  iOS does not allow apps to open the Dictation Languages screen directly.
//  Retry is always a user action: never auto-loop after a service failure.
//

import SwiftUI
import UIKit

private struct SpeechRecoveryAlertModifier: ViewModifier {
    @Binding var issue: SpeechRecognitionIssue?
    let onRetry: () -> Void

    func body(content: Content) -> some View {
        content.alert(
            issue?.title ?? "Speech Recognition Unavailable",
            isPresented: Binding(
                get: { issue != nil },
                set: { if !$0 { issue = nil } }
            )
        ) {
            Button("Open Settings") {
                issue = nil
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button("Try Again") {
                issue = nil
                // Allow the system alert to dismiss before requesting the mic.
                DispatchQueue.main.async { onRetry() }
            }
            Button("Not Now", role: .cancel) { issue = nil }
        } message: {
            if let issue {
                Text(issue.message + "\n\nOpen Settings opens Velora's settings. For Dictation, navigate to General > Keyboard manually.")
            }
        }
    }
}

extension View {
    func speechRecoveryAlert(
        issue: Binding<SpeechRecognitionIssue?>,
        onRetry: @escaping () -> Void
    ) -> some View {
        modifier(SpeechRecoveryAlertModifier(issue: issue, onRetry: onRetry))
    }
}
