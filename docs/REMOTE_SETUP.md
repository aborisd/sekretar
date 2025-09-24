Remote LLM (vLLM or llama.cpp)
==============================

This guide shows how to run an OpenAI-compatible LLM endpoint via Docker and connect the iOS app to it.

Option A — vLLM (GPU)
---------------------
1) Provision a GPU VM (RunPod/GCP/AWS). Recommended: L4/A10G 24GB for 7B–8B models.
2) Install NVIDIA drivers and nvidia-container-toolkit.
3) In `server/`:
   - Copy `.env.sample` to `.env` and set `MODEL` (e.g., `mistralai/Mistral-7B-Instruct-v0.2`). Optionally set `HF_TOKEN`.
   - (Recommended) Set `API_KEY` to a strong random string — vLLM will require `Authorization: Bearer <API_KEY>`.
   - Run `docker compose up -d`.
4) Verify: `curl http://<host>:8000/v1/models`.
5) API endpoint: `http://<host>:8000/v1/chat/completions`.

Option B — llama.cpp (CPU)
--------------------------
1) Download a small GGUF model into `server/models` (e.g., TinyLlama GGUF).
2) Run: `docker compose -f server/docker-compose.cpu.yml up -d` (set `GGUF_MODEL=<file>` env var).
3) API endpoint: `http://localhost:8000/v1/chat/completions`.

 iOS app wiring
 --------------
 Debug (local overrides via plist)
 - Copy `sekretar/RemoteLLM.plist.sample` → `sekretar/RemoteLLM.plist` and fill in real values.
 - This file is ignored by git and read only in Debug builds.
 - Alternatively, create `RemoteLLM.local.plist` with the same keys. In Debug the app looks for `RemoteLLM.local.plist` then `RemoteLLM.plist`.

 Release/CI (no secrets in bundle)
 - Provide non-sensitive defaults in `Info.plist` or set values via `UserDefaults` at runtime.
 - API keys should not be embedded in the app bundle; prefer Keychain (UI to enter the key) or server-side proxy.

 Minimal wiring
 1) Configure via one of the sources (priority order):
    - UserDefaults (`REMOTE_LLM_*`), then Debug-only local plist, then `Info.plist`.
 2) Build and run. The app uses `RemoteLLMProvider` automatically when `REMOTE_LLM_BASE_URL` is present.

 Notes
 - Cancellation: the app cancels the in-flight request; UI doesn’t show an error on user cancel.
 - Streaming: SSE streaming is implemented in `RemoteLLMProvider` with cooperative cancel.
 - Security: front vLLM with a reverse proxy (TLS, API key) before exposing to the internet.
 - Secrets hygiene: `RemoteLLM.plist`/`RemoteLLM.local.plist` are for Debug only; they are ignored by git and not read by Release builds.

TLS + API key (production-ready sketch)
--------------------------------------
1) Point a domain (e.g., `llm.example.com`) to your VM public IP.
2) In `server/secure/`:
   - Copy `.env.sample` to `.env` and set `DOMAIN`, `ACME_EMAIL`, `API_KEY` and `MODEL`.
   - Run: `docker compose -f docker-compose.caddy.yml --env-file .env up -d`.
3) Caddy issues TLS via Let’s Encrypt and proxies `https://$DOMAIN` → `vllm:8000`.
4) Client must send `Authorization: Bearer <API_KEY>`.

Cloud Deployment Guides
-----------------------
- RunPod: `docs/DEPLOY_VLLM_RUNPOD.md`
- GCP: `docs/DEPLOY_VLLM_GCP.md`
- AWS: `docs/DEPLOY_VLLM_AWS.md`

API-Only Quickstart (no server)
-------------------------------
- OpenRouter: `docs/API_QUICKSTART.md`
