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
1) Add the following keys to the app target Info.plist (or via UserDefaults for quick tests):
   - `REMOTE_LLM_BASE_URL` — e.g., `http://<host>:8000`
   - `REMOTE_LLM_MODEL` — e.g., `mistralai/Mistral-7B-Instruct-v0.2`
   - `REMOTE_LLM_API_KEY` — optional, omit for open vLLM server
2) Switch provider:
   - Set `UserDefaults.standard.set("remote", forKey: "ai_provider")` once (or add a small settings toggle later).
3) Build and run. The app will call `/v1/chat/completions` with a concise system prompt.

Notes
- Cancellation: the app cancels the in-flight request; UI doesn’t show an error on user cancel.
- Streaming: current remote provider uses non-streamed responses; we can add SSE streaming later.
- Security: front vLLM with a reverse proxy (TLS, API key) before exposing to the internet.

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
