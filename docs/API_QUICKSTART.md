API Quickstart (No Server to Manage)
===================================

This guide shows the fastest path to see Sekretar talking to a real LLM tonight, using a managed API. Two options:
- OpenRouter (recommended for a 10-minute test)
- RunPod Serverless (auto-scaling endpoint with your GPU templates)

Option A — OpenRouter (10 minutes)
----------------------------------
1) Create account and get API key:
   - https://openrouter.ai/
2) Choose a model (examples):
   - meta-llama/llama-3.1-8b-instruct
   - mistralai/mistral-7b-instruct
3) Configure iOS app (Info.plist or UserDefaults): (see also `docs/INFO_PLIST_SNIPPET.md` for copy/paste)
   - REMOTE_LLM_BASE_URL = https://openrouter.ai/api
   - REMOTE_LLM_MODEL = <your model, e.g., meta-llama/llama-3.1-8b-instruct>
   - REMOTE_LLM_API_KEY = <your OpenRouter key>
   - (optional) REMOTE_LLM_MAX_TOKENS = 256..512
   - (optional) REMOTE_LLM_TEMPERATURE = 0.5..0.7
   - (optional, etiquette) REMOTE_LLM_HTTP_REFERER = https://<your-site-or-repo>
   - (optional, etiquette) REMOTE_LLM_HTTP_TITLE = Sekretar
   - Switch provider once: UserDefaults.standard.set("remote", forKey: "ai_provider")
4) Test with curl:
```
curl -H "Authorization: Bearer $OPENROUTER_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"model":"meta-llama/llama-3.1-8b-instruct","messages":[{"role":"user","content":"Hello!"}]}' \
     https://openrouter.ai/api/v1/chat/completions
```
Notes
- Optional headers per OpenRouter docs: HTTP-Referer, X-Title (not required for a quick test).
- Our client uses non-streamed responses now; streaming can be added later.

Option B — RunPod Serverless (30–60 minutes)
-------------------------------------------
1) Console → "Run AI models via API" → pick vLLM template (or your Docker image `vllm/vllm-openai:latest`).
2) Command args:
```
--model mistralai/Mistral-7B-Instruct-v0.2 \
--max-model-len 4096 \
--gpu-memory-utilization 0.9 \
--api-key $API_KEY
```
3) Env vars: MODEL (optional), API_KEY (strong random), HF_TOKEN (optional).
4) Scaling: min replicas = 1 (avoid cold starts), concurrency as budget allows.
5) Get endpoint URL; test:
```
curl -H "Authorization: Bearer $API_KEY" <RUNPOD_ENDPOINT>/v1/models
```
6) iOS config: set REMOTE_LLM_BASE_URL to `<RUNPOD_ENDPOINT>`, model to your chosen model, API key accordingly.

Security
- Always require Authorization: Bearer token.
- Do not log content bodies; only metadata (status, tokens, latency).
