# Changelog

This file consolidates the meaningful evolution recorded in the handoff documentation shipped with the source project. The historical labels below are **internal development milestones**, not claims that these versions were published on the App Store. The Xcode app version/build settings are still `1.0 (1)`.

## Current codebase — internal milestone v3.6

### Exit and session continuity (v3.1–v3.6)
- A consistently positioned exit action is available in Breathing, Ready to Start, Easy Onset and Rhythm; Feedback uses its own navigation.
- The latest design uses an **edge-to-edge SwiftUI confirmation overlay**, not the older floating system sheet. Top corners are rounded; the lower and side edges meet the display.
- Each phase has context-specific confirmation text. **Keep Practicing**, swiping down, or tapping the scrim cancels departure; only **Leave Session** exits.
- Session content is paused while exit confirmation is being considered. Breathing also pauses when the app becomes inactive or moves to the background.

### Speech fairness and real scenarios (v2.6–v3.0)
- Refined a library of 22 English topics (10 reading passages, 12 real scenarios) with short, connected sentences and natural introductions.
- Easy Onset uses **curated cumulative phrase boundaries** while Rhythm uses the same underlying topic text; the existing test suite currently finds **66 sentences and 156 steps**.
- Added shared offline word normalization for common contraction and number-format variants returned by Apple Speech.
- Restored an **80% ordered word matching threshold** for Easy Onset rather than requiring an exact 100% transcript. This is separate from assessing the onset quality.
- A positive onset verdict is required to accept the acoustic technique. Ambiguous measurement is treated as inconclusive rather than proof that the user failed.
- The onset detector is a lightweight acoustic heuristic, not clinically validated.

### Audio, feedback and guidance (v1.2–v2.1)
- Improved microphone readiness/recovery messages, automatic stop when the expected phrase is recognized, and concise, supportive Easy Onset feedback.
- Preserved the first completed acoustic onset measurement during a spoken attempt, preventing subsequent words from replacing that evidence.
- Reduced the onset capture sample window from 0.55 to 0.45 seconds as a **device-trial setting**, not a requirement to elongate the first word.
- Kept temporary audio playback confined to the Feedback phase and improved cleanup of recordings.
- Moved abandoned-recording maintenance off the initial app launch path.

### Experience design
- Onboarding → Home → Topics → Breathing → Ready → Easy Onset → Rhythm → Feedback.
- Expressive SwiftUI character, timeline, karaoke-style progression, gentle pacing, demo-preview mode and supportive feedback.
- Light-only Mint/Aqua design with no third-party frameworks.

## Before publishing

Consult [App Store release checklist](docs/APP_STORE_RELEASE_CHECKLIST.md), especially signing/build numbering, offline speech recognition, mic permissions, privacy disclosures and physical-device regression. Successful source-level tests alone do not qualify a release.
