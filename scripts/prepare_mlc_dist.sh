#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
CONFIG="$ROOT_DIR/mlc-package-config.json"

if ! command -v mlc_llm >/dev/null 2>&1; then
  echo "[ERROR] mlc_llm CLI not found. Please install the mlc_llm binary as per docs." >&2
  echo "See: https://github.com/mlc-ai/mlc-llm/tree/main#install-mlc-llm" >&2
  exit 1
fi

if [[ -z "${MLC_LLM_SOURCE_DIR:-}" ]]; then
  echo "[ERROR] Please set MLC_LLM_SOURCE_DIR to your cloned mlc-llm path." >&2
  echo "Example: export MLC_LLM_SOURCE_DIR=$ROOT_DIR/third_party/mlc-llm" >&2
  exit 1
fi

echo "[INFO] Using MLC_LLM_SOURCE_DIR=$MLC_LLM_SOURCE_DIR"
echo "[INFO] Packaging with config: $CONFIG"

mlc_llm package

echo "[OK] dist prepared under $DIST_DIR"
echo "- dist/lib contains static libraries"
echo "- dist/bundle contains mlc-app-config.json and optional weights"

