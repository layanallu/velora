# Cleanup / static verification record

**Source:** user-supplied ZIP titled `Velora_Edge_To_Edge_Exit_FullProject_v3_6(1).zip` (internal development milestone v3.6).

## What changed in the delivery structure

- Renamed only the *outer project folder* from a versioned handoff name to `Velora`.
- Consolidated **27 historical top-level Markdown handoff files** into a current `README.md`, a historical `CHANGELOG.md`, and a small `docs/` reference set. Earlier raw documents remain in the user-provided original ZIP, not in this cleaned release tree.
- Moved three README screenshots from `ui/` to `docs/images/` and updated Markdown references.
- Added `.gitignore` for non-source Xcode, Swift and macOS artifacts.
- Kept `Velora.xcodeproj`, the full app source, all required bundled assets and the offline `QualityChecks` scripts at their existing paths.

## Static and scripted verification performed

- 58 app Swift files passed `swiftc -frontend -parse` (syntax-only).
- The supplied four QualityChecks scripts passed in the available Swift toolchain:
  - 25 text equivalence checks; 22 topics / 66 sentences / 156 cumulative steps.
  - 9 Easy Onset acceptance checks.
  - 16 first-onset evidence checks.
  - 13 onset analyzer smoke checks.
- Source app and Xcode project files were checked against the original ZIP at the byte level to ensure this cleanup **did not alter application behavior**.

## Not verified in this environment

- Xcode/iOS compilation, code signing, Product → Archive, TestFlight, and App Store Connect submission.
- iPhone/iPad layout, real Apple Speech recognition, recording/playback, VoiceOver and device-specific performance.
- Ownership/redistribution rights for the included sample recordings.

**App Store package distinction:** Only the `Velora/` app target is compiled into the iOS application. The root docs, screenshots in `docs/images/`, test scripts and git settings are source-repository material, not runtime app features.
