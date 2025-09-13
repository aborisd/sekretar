# Sekretar

Lightweight SwiftUI iOS demo app with SPM module layout.

## Build & Run (Xcode)
- Open `sekretar.xcodeproj`
- Select scheme `sekretar`
- Choose an iOS Simulator (e.g. iPhone SE)
- Product → Run

## Useful Commands
- Build via CLI: `xcodebuild -project sekretar.xcodeproj -scheme sekretar -configuration Debug -sdk iphonesimulator build`
- Run on current simulator: `xcrun simctl launch booted com.aka.sekretar`

## Notes
- Swift Package manifest `Package.swift` targets the `sekretar` folder and processes resources from there.
- Backup files (`*.swift.backup`) are excluded from the app bundle.

## MLC-LLM (On-Device) Integration
- Config: `mlc-package-config.json`
- Setup guide: `docs/MLC_SETUP.md`
- Provider: `sekretar/MLCLLMProvider.swift` (falls back if MLCSwift not linked)
