//
//  ScenarioStartView.swift
//  Velora
//
//  Step 5: Scenario Start Screen (Ready)
//
//  ✅ Minimal & supportive
//  ✅ No ring, no dots
//  ✅ Same character size + same vertical placement as BreathingGateView for seamless crossfade
//  ✅ Removed topic card (topic already shown in nav title)
//  ✅ Excited but calm expression
//  Exit button and exit sheet are owned by BreathingGateView, which
//  crossfades into this view. Avoid duplicate controls on Ready to Start.
//



import SwiftUI

struct ScenarioStartView: View {
    let topic: Topic
    var mode: SessionMode = .normal

    @State private var goSession: Bool = false

    private var readyTimelineSteps: [ProgressTimelineView.Step] {
        [
            .init(title: "Breathing", state: .done, kind: .breathing),
            .init(title: "Easy Onset", state: .current, kind: .easyOnset),
            .init(title: "Rhythm", state: .upcoming, kind: .rhythm)
        ]
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Keep the journey visible after breathing, before tapping Start.
                // Easy Onset is highlighted as the next technique to begin.
                ProgressTimelineView(steps: readyTimelineSteps, nodeSize: 33)

                Spacer(minLength: 8)

                VeloraCharacterView(
                    expression: .smile,
                    size: 170,
                    gaze: .center,
                    eyeState: .open,
                    motionStyle: .subtle,
                    mouthMode: .curve
                )
                .scaleEffect(1.26)
                .padding(.top, 6)

                Spacer().frame(height: 22)

                Text("Ready to start?")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.ink)

                Spacer().frame(height: 18)

                Text("We’ll go step by step.\nGentle voice. Easy pace.")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.ink.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 22)

                Spacer()

                NavigationLink(isActive: $goSession) {
                    SessionView(topic: topic, mode: mode)
                } label: {
                    EmptyView()
                }

                PrimaryButton(title: "Start", systemImage: "play.fill") {
                    Haptics.tap()
                    goSession = true
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 50)
            }

        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        // The shared journey timeline, not the native navigation bar, is the header.
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

}

struct ScenarioStartView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ScenarioStartView(topic: TopicLibrary.all.first!, mode: .normal)
        }
        .preferredColorScheme(.light)
    }
}
