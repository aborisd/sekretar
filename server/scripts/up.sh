#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose up -d
echo "[INFO] Stack is up. Use scripts/test.sh to verify."

