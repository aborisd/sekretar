#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
API_KEY="${API_KEY:-}"
MODEL="${MODEL:-mistralai/Mistral-7B-Instruct-v0.2}"

auth=( )
if [[ -n "${API_KEY}" ]]; then
  auth=( -H "Authorization: Bearer ${API_KEY}" )
fi

echo "[TEST] GET /v1/models"
curl -sS "${auth[@]}" "${BASE_URL}/v1/models" | sed -e 's/.\{200\}$/.../'
echo

echo "[TEST] POST /v1/chat/completions"
curl -sS "${auth[@]}" -H 'Content-Type: application/json' \
  -d '{"model":"'"${MODEL}"'","messages":[{"role":"user","content":"Hello!"}]}' \
  "${BASE_URL}/v1/chat/completions" | sed -e 's/.\{200\}$/.../'
echo

