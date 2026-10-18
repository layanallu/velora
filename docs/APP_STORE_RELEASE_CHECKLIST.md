# App Store / TestFlight release checklist

This is a **pre-release checklist**, not a certification that Apple will approve the app.

## Build and signing

- [ ] Open `Velora.xcodeproj` using a compatible Xcode release.
- [ ] Confirm your Apple Developer team, bundle identifier `layan.Velora`, and matching app in App Store Connect.
- [ ] Check the existing live/TestFlight build number. Xcode currently declares **marketing version 1.0, build 1**: increase appropriately **only after checking the destination app's existing numbering**.
- [ ] Review the deployment target (**iOS 26.1** at target level) and supported devices (iPhone + iPad); changing this requires compatibility testing.
- [ ] Perform a Release archive using **Product → Archive**; validate the uploaded build in App Store Connect.
- [ ] Confirm the App Icon, launch behavior, and release metadata/screenshots on both device families.

## Privacy, content and store listing

- [ ] Confirm microphone and Speech Recognition permission purpose strings appear clearly to users.
- [ ] Check App Store Connect privacy answers against **actual behavior in the shipped build**. The source uses local speech recognition and temporary on-device recordings, but that does not replace privacy review.
- [ ] Review the copyright/permission for the bundled sample audio `My Name Is.m4a` and `DemoVoice.mp3` before App Store distribution or publishing a public repository.
- [ ] Do not imply diagnosis, guaranteed fluency gains or clinical validation of onset/smoothness/confidence scores. Describe Velora as supportive speech practice.
- [ ] Supply required contact/support information and any privacy policy URL requested for your app's final distribution configuration.
- [ ] Confirm the screenshots and descriptions represent features actually in the release.

## Real-device regression (Normal Mode, not only Demo)

- [ ] Launch, onboarding, topic selection and custom topic flow.
- [ ] Normal Breathing completes only after the guided active time; lock device/switch apps, then return and confirm paused time was not counted.
- [ ] Breathing → Ready → Easy Onset → Rhythm → Feedback navigation, without accidentally skipping phases.
- [ ] Verify exit button in Breathing/Ready/Easy Onset/Rhythm and **not** Feedback; confirm swiping down resumes practice and Leave Session exits.
- [ ] Test on-device English US recognition while online **and with network disabled**; validate unavailable/offline-restriction messaging.
- [ ] Test mic/Speech permission denial, interruption, silence, short words, slow easy onsets, ordinary starts, abrupt starts, and mixed pauses.
- [ ] Test Apple Speech contractions/digit variants (e.g. `I would` vs `I'd`) without assuming every utterance must be perfect.
- [ ] Confirm Rhythm highlighting and temporary playback in Feedback; test record cleanup on exit/restart.
- [ ] Exercise VoiceOver, Dynamic Type/small screen layouts, screen rotation where supported, contrast, and full app lifecycle.
- [ ] Test a **Release** build on a real iPhone/iPad and check crash logs and launch duration.

## Automated checks

Use the four scripts in `QualityChecks/` (see `README.md`). These cover deterministic text and onset evidence logic only. They do not replace Xcode build/signing verification or trials with people who stutter.
