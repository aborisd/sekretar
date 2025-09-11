# calendAI

Lightweight SwiftUI iOS demo app with SPM module layout.

## Build & Run (Xcode)
- Open `calendAI.xcodeproj`
- Select scheme `calendAI`
- Choose an iOS Simulator (e.g. iPhone SE)
- Product → Run

## Useful Commands
- Build via CLI: `xcodebuild -project calendAI.xcodeproj -scheme calendAI -configuration Debug -sdk iphonesimulator build`
- Run on current simulator: `xcrun simctl launch booted com.aka.calendai`

## Notes
- Swift Package manifest `Package.swift` targets the `calendAI` folder and processes resources from there.
- Backup files (`*.swift.backup`) are excluded from the app bundle.

## MLC-LLM (On-Device) Integration
- Config: `mlc-package-config.json`
- Setup guide: `docs/MLC_SETUP.md`
- Provider: `calendAI/MLCLLMProvider.swift` (falls back if MLCSwift not linked)
