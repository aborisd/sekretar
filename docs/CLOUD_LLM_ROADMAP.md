Sekretar Cloud LLM Roadmap
==========================

Purpose
- Deliver a balanced, secure, and maintainable cloud LLM backend (vLLM) for Sekretar, aligned with BRD: privacy-first, minimal PII exposure, cancellable requests, structured JSON modes, and future on-device fallback.

Phase 0 — Decisions (1–2h)
- Cloud: choose RunPod (fast/cheap), GCP (managed), or AWS (ecosystem).
- GPU: L4 24GB or A10G 24GB for 7B/8B; A100 80GB for 13B.
- Model: start with mistralai/Mistral-7B-Instruct-v0.2 (4k ctx), consider Llama-3.1-8B.
- Domain & TLS: use subdomain (e.g., llm.example.com), Let’s Encrypt via Caddy.
- Security posture: API key required, no content logs, rate limits at proxy.

Phase 1 — Minimal Functional (Day 1)
- Provision VM with GPU; install NVIDIA drivers + nvidia-container-toolkit.
- Deploy vLLM via Docker Compose (server/docker-compose.yml) with API key.
- Verify endpoints:
  - GET /v1/models (auth required)
  - POST /v1/chat/completions (short prompt)
- iOS: set Info.plist keys (REMOTE_LLM_BASE_URL, REMOTE_LLM_MODEL, REMOTE_LLM_API_KEY) and switch ai_provider=remote.
- Acceptance: short prompts < 2s median, cancellation works, no content in logs.

Phase 2 — TLS + Harden (Day 2)
- Enable Caddy reverse proxy (server/secure/*) with Let’s Encrypt TLS.
- Enforce API key at proxy (header Authorization: Bearer …) and vLLM.
- Add basic rate-limit (Caddy/Cloudflare), firewall to expose only 80/443.
- Acceptance: HTTPS only, rejected requests without token, baseline rate-limit in place.

Phase 3 — Streaming + JSON Modes (Week 1)
- iOS: add SSE streaming in RemoteLLMProvider (stream=true), co-op cancel.
- JSON modes: strict prompts + validation + retries for intents/optimizer.
- Tool calling (function calling): declare create_task, update_task, schedule_task; preview/confirm before execution.
- Acceptance: JSON success ≥95%, token stream UX smooth, Stop button cancels stream.

Phase 4 — Privacy & Data Handling (Week 1–2)
- Client redaction: mask emails/phones/addresses before sending.
- Minimization: only send minimal context relevant to request.
- Server logging: drop request/response bodies; log metadata only (status, tokens, latency).
- Data retention: 0 content, 14–30d for aggregates (configurable).
- Acceptance: PII never stored, documented policy.

Phase 5 — Observability & Ops (Week 2)
- Metrics: enable vLLM metrics port (Prometheus scrape), basic dashboards (latency, t/s, queue).
- Logs: structured jsonl; centralize (optional) without content fields.
- Alerts: p95 latency, 5xx rate, GPU memory pressure.
- Runbooks: restart, scale up/down, rotate API keys, incident steps.
- Acceptance: on-call checklist in repo, alerts reach target channel.

Phase 6 — Performance & Cost (Week 2+)
- Tuning: max_tokens(<=512–768), temperature(0.5–0.7), gpu-memory-utilization(0.85–0.9).
- Quantization: consider AWQ/GPTQ weights for lower VRAM; test quality.
- Scaling: spot instances or autoscaling group; pre-warm models.
- Acceptance: predictable cost profile; throughput tests documented.

Phase 7 — On-Device MLC (Parallel)
- Track mlc.ai wheel sync (tvm/tvm_ffi). When fixed: `mlc_llm package` TinyLlama, link MLCSwift.
- Keep same UX; provider switch via settings.
- Acceptance: offline responses for standard tasks; proper cancel.

Security Checklist
- API key mandatory (server and proxy) and rotated quarterly.
- HTTPS everywhere (HSTS), firewall restricts non-HTTPS ports.
- No content logging; only metadata (latency, tokens in/out, status).
- Rate limit & basic WAF; IP allowlist for admin.
- Dependencies pinned; regular updates for images.

iOS Client Tasks
- RemoteLLMProvider: add SSE, backoff, and circuit breaker.
- Settings UI: base_url, model, api_key (Keychain for prod), provider switch (remote/mlc/local).
- Redaction: local masking of PII (regex-based + unit tests).
- JSON adapters for: intents, task analysis, schedule optimization; strict decoding + retry.
- Tool calling integration: preview + confirm execution.

Server Tasks
- vLLM compose (GPU) with API_KEY (done), secure stack with Caddy (done templates).
- Add metrics port for Prometheus (optional flag in command).
- Cloudflare in front (optional): TLS, IP filtering, rate limiting.
- Scripts: up/down/test (done); add rotate_key.sh (future).

Day-0/D-1 Runbook (Ops)
- Day 0 (dev): bring up vLLM with API key, test via server/scripts/test.sh.
- Day 1 (staging): DNS + TLS via Caddy, enforce key, confirm iOS app connects.
- Rollback: keep fallback to local EnhancedLLMProvider; DNS switchback; compose down.

Cost Notes (estimates)
- L4/A10G 24GB: ~$0.35–$1.20/h; good for 7B/8B with 4–8k ctx, 35–80 tok/s.
- A100 80GB: $2–$3.5/h for 13B/70B; higher quality, higher cost.
- Storage: 20–60GB HF cache; egress minimal for small traffic.

Repository Pointers
- GPU compose: server/docker-compose.yml:1
- Secure stack: server/secure/docker-compose.caddy.yml:1
- Test script: server/scripts/test.sh:1
- iOS provider: sekretar/RemoteLLMProvider.swift:1
- iOS config sample: sekretar/RemoteLLM.plist.sample:1
- Setup guide: docs/REMOTE_SETUP.md:1

Next Steps (Actionable)
1) Pick cloud + GPU and model; create DNS (llm.example.com).
2) Bring up secure stack (server/secure/*.yml), set strong API_KEY, verify curl.
3) Wire iOS to remote; test cancel/latency; collect baseline metrics.
4) Implement SSE streaming in client; add Settings UI and redaction.
5) Introduce JSON modes + tool calling; add preview/confirm UX.
6) Add monitoring/alerts; document incident runbooks.

