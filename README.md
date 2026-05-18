# Sekretar

Sekretar is a SwiftUI iOS productivity assistant that combines calendar planning, task management, reminders, and an AI chat interface. The app is built as a practical MVP/demo: it opens into a native iOS dashboard, supports task and calendar workflows, and includes an LLM-backed chat mode for questions and natural-language planning commands.

Public project branch:
https://github.com/aborisd/sekretar/tree/codex-apple-friendly-demo-minimum

## What It Does

- Apple-style home dashboard with today's calendar summary, open tasks, quick navigation, and upcoming items.
- AI chat with two modes: free-form AI questions and structured task/calendar commands.
- Natural-language task and event creation pipeline with preview/confirmation cards.
- Core Data persistence for tasks, events, projects, user preferences, and AI action logs.
- Calendar views, task list, task editor, event editor, settings, reminders, privacy, and debug tooling.
- Remote OpenAI-compatible LLM provider with local fallback, plus on-device MLC-LLM scaffolding.
- Localization resources for English and Russian.
- TestFlight-oriented diagnostics, crash reporting, analytics hooks, and offline sync scaffolding.

## Technology Stack

- Swift, SwiftUI, Combine, async/await
- iOS, Xcode, Swift Package Manager
- Core Data / NSPersistentContainer
- AppIntents shortcuts
- UserNotifications, EventKit, AVFoundation / Speech input
- URLSession, Server-Sent Events streaming, OpenAI-compatible chat completions
- OpenRouter / remote LLM configuration via local plist
- MLC-LLM integration scaffold for on-device inference
- Natural-language date parsing and AI intent routing
- Localization with `.strings` resources
- Simulator automation with `xcrun simctl`

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
