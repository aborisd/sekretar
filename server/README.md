vLLM / llama.cpp Server (OpenAI-compatible)
==========================================

This folder contains Docker Compose setups to run an OpenAI-compatible endpoint for LLM inference.

Options
- vLLM (GPU): `docker-compose.yml` — recommended on GPU instances (A10G/L4/A100).
- llama.cpp (CPU): `docker-compose.cpu.yml` — for small GGUF models on CPU/Mac.

vLLM (GPU) quickstart
---------------------
1) Pick a GPU VM (RunPod, GCP, AWS) with NVIDIA GPU (L4/A10G/A100).
2) Install NVIDIA drivers and Docker runtime (nvidia-container-toolkit).
3) Copy `.env.sample` to `.env` and set at least `MODEL` (e.g. `mistralai/Mistral-7B-Instruct-v0.2`). Optionally set `HF_TOKEN`.
4) (Recommended) Set `API_KEY` to a strong random string. The server will require `Authorization: Bearer <API_KEY>`.
5) Run:
   - `docker compose up -d`
6) Test:
   - `curl -H "Authorization: Bearer $API_KEY" http://<host>:8000/v1/models`
   - `curl -H "Authorization: Bearer $API_KEY" -H 'Content-Type: application/json' \
        -d '{"model":"'$MODEL'","messages":[{"role":"user","content":"Hello!"}]}' \
        http://<host>:8000/v1/chat/completions`
7) The API is available at `http://<host>:8000/v1/chat/completions` (OpenAI-compatible).

llama.cpp (CPU) quickstart
--------------------------
1) Download a small GGUF model into `./models` (e.g., TinyLlama GGUF).
2) Set `GGUF_MODEL` env var (e.g., `GGUF_MODEL=tinyllama-1.1b-chat-q4_k_m.gguf`).
3) Run: `docker compose -f docker-compose.cpu.yml up -d`.
4) API will be available at `http://localhost:8000/v1/chat/completions`.

Helper scripts (optional)
-------------------------
- `scripts/test.sh` — quick test against a base URL with API key.
- `scripts/up.sh` / `scripts/down.sh` — bring stack up/down.

Notes
- For TLS and auth, put a reverse proxy (Caddy/Traefik/NGINX) in front and require an API key.
- vLLM flags:
  - `--max-model-len` controls context length.
  - `--gpu-memory-utilization` controls VRAM usage headroom.
- llama.cpp flags:
  - `--ctx-size` controls context length; `--n-gpu-layers 0` keeps it pure CPU.
