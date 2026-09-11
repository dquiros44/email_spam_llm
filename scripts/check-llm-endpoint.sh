#!/usr/bin/env bash
# Quick health check for the LM Studio endpoint the n8n pipeline depends on.
set -euo pipefail

HOST="${LLM_HOST:-10.10.10.202}"
PORT="${LLM_PORT:-1234}"

echo "Checking http://${HOST}:${PORT}/v1/models ..."
curl -sf -m 5 "http://${HOST}:${PORT}/v1/models" | head -c 500
echo
echo "OK"
