# Sekretar

**AI-powered calendar, tasks, and chat assistant for iOS.**

[English](README.md) · [Русский](README.ru.md)

[![Platform](https://img.shields.io/badge/platform-iOS%2017%2B-blue)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Sekretar turns a normal conversation into a managed day. Type "Schedule a sync with Anna tomorrow at 11" or "Remind me to renew the lease on Friday" and Sekretar parses the intent, shows an inline action card, and — after one tap — writes it to your calendar or task list. It runs locally first, calls an LLM only when heuristics aren't sure, and supports both a self-hosted OpenAI-compatible endpoint and on-device inference via [MLC-LLM](https://github.com/mlc-ai/mlc-llm).

<p align="center">
  <img src="docs/image.png" width="420" alt="Sekretar screenshot" />
</p>

## Features

- **Natural-language scheduling** — events and tasks created from plain Russian or English ("в пятницу в 15:00", "next Monday at 9am").
- **AI chat with streaming** — SSE-streamed responses with cooperative cancellation and a polished typing indicator.
- **Inline action cards** — every AI-proposed action is previewed (date, title, attendees, recurrence) and editable before you confirm.
- **Calendar in day / week / month** — native EventKit sync so the iOS Calendar and Sekretar stay in lockstep.
- **Task list with bulk ops** — multi-select to complete or delete, priority and due dates, fast-entry input.
- **Voice input** — Speech framework powers a one-tap mic in chat.
- **Home dashboard** — time-of-day greeting, incomplete tasks, upcoming events, quick actions.
- **Pluggable LLM backend** — point at any OpenAI-compatible server (vLLM, llama.cpp, OpenRouter) or run on-device with MLC-LLM.
- **Bilingual UI** — Russian and English localizations.
- **Privacy-first** — all tasks and events live in local CoreData; remote LLM is opt-in and configured per-device.

## Architecture

```
┌────────────────────┐    ┌─────────────────────┐    ┌──────────────────────┐
│  SwiftUI screens   │ →  │   AIIntentService   │ →  │  LLMProviderProtocol │
│  (Home, Chat,      │    │  ├─ heuristic fast  │    │  ├─ RemoteLLMProvider│
│  Calendar, Tasks)  │    │  │  path (RU/EN)    │    │  │  (OpenAI-compat   │
│                    │ ←  │  └─ JSON-validated  │ ←  │  │   + SSE)         │
│  CoreData / EventKit│   │     action preview  │    │  └─ MLCLLMProvider   │
└────────────────────┘    └─────────────────────┘    │     (on-device)      │
                                                     └──────────────────────┘
```

The intent pipeline ([`sekretar/AIIntentService.swift`](sekretar/AIIntentService.swift)) tries to recognise common phrasings locally before spending a network call. When it falls back to the LLM, responses are parsed as strict JSON (with retries), then re-validated against the user's calendar state before any action card is rendered.

## Tech Stack

Swift 5.9 · SwiftUI · CoreData · EventKit · Speech · App Intents / Shortcuts · MLC-LLM (optional, on-device) · vLLM or llama.cpp (optional, remote).

## Getting Started

**Requirements**

- macOS with Xcode 15 or newer
- iOS 17+ simulator or device
- Git with submodule support (only needed if you plan to wire up on-device MLC-LLM)

**Clone and run**

```bash
git clone --recurse-submodules https://github.com/aborisd/sekretar.git
cd sekretar
open sekretar.xcodeproj
```

Pick the `sekretar` scheme, choose any iPhone simulator, and press `Cmd-R`. Sekretar runs out of the box — the heuristic intent path works offline.

**CLI build**

```bash
xcodebuild -project sekretar.xcodeproj -scheme sekretar -configuration Debug -sdk iphonesimulator build
```

## Configuring AI

Sekretar works without any AI configuration — the heuristic path handles a lot of common phrasings. To unlock the full LLM pipeline, pick one of the two options below.

### Option A — Remote LLM (recommended)

Copy the sample and fill in your endpoint:

```bash
cp sekretar/RemoteLLM.plist.sample sekretar/RemoteLLM.plist
```

Edit `sekretar/RemoteLLM.plist` and set at minimum:

- `REMOTE_LLM_BASE_URL` — your OpenAI-compatible server (vLLM, llama.cpp, OpenRouter)
- `REMOTE_LLM_MODEL` — model id served by that endpoint
- `REMOTE_LLM_API_KEY` — optional for self-hosted, required for OpenRouter and friends

`RemoteLLM.plist` is gitignored, so real keys never leak. For deployment, see:
- [docs/REMOTE_SETUP.md](docs/REMOTE_SETUP.md)
- [docs/DEPLOY_VLLM_AWS.md](docs/DEPLOY_VLLM_AWS.md)
- [docs/DEPLOY_VLLM_GCP.md](docs/DEPLOY_VLLM_GCP.md)
- [docs/DEPLOY_VLLM_RUNPOD.md](docs/DEPLOY_VLLM_RUNPOD.md)

### Option B — On-device with MLC-LLM

See [docs/MLC_SETUP.md](docs/MLC_SETUP.md). The runtime ships as a submodule under `third_party/mlc-llm`; you'll need to build and link the MLCSwift target and place model weights as described in the guide.

## Project Layout

```
sekretar.xcodeproj/         # Xcode workspace
sekretar/                   # iOS app (SwiftUI sources, assets, localizations)
sekretarTests/              # XCTest unit tests
sekretarUITests/            # XCUITest UI tests
docs/                       # Setup, deployment, and roadmap docs
server/                     # Docker Compose for self-hosted inference servers
scripts/                    # Helper shell scripts
third_party/mlc-llm/        # MLC-LLM runtime (submodule)
```

## Documentation

- [docs/REMOTE_SETUP.md](docs/REMOTE_SETUP.md) — configure the remote LLM client
- [docs/MLC_SETUP.md](docs/MLC_SETUP.md) — wire up on-device inference
- [docs/API_QUICKSTART.md](docs/API_QUICKSTART.md) — backend API reference
- [docs/DEPLOY_VLLM_AWS.md](docs/DEPLOY_VLLM_AWS.md) · [GCP](docs/DEPLOY_VLLM_GCP.md) · [RunPod](docs/DEPLOY_VLLM_RUNPOD.md) — deployment recipes
- [docs/CLOUD_LLM_ROADMAP.md](docs/CLOUD_LLM_ROADMAP.md) — cloud LLM roadmap
- [docs/PROGRESS.md](docs/PROGRESS.md) — feature roadmap and current phase

## License

MIT — see [LICENSE](LICENSE).
