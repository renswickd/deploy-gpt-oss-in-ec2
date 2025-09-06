#!/usr/bin/env bash
set -euo pipefail

# Build the API image and ensure the Ollama model is pulled
# Usage:
#   bash scripts/build_and_pull.sh [--with-ollama] [--model NAME]
#
# Modes:
#   - default (host): expects Ollama running on host at 11434.
#     Sets OLLAMA_HOST to http://host.docker.internal:11434 for the API container.
#     Pulls the model on the host using `ollama pull`.
#   - --with-ollama: runs the Ollama container via compose profile "ollama" and
#     pulls the model inside that container; sets OLLAMA_HOST=http://ollama:11434.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

WITH_OLLAMA="false"
MODEL=""

# Load .env if present for OLLAMA_MODEL default
if [[ -f .env ]]; then
  # shellcheck disable=SC2046
  export $(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' .env | xargs -0 -I {} echo {}) || true
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-ollama)
      WITH_OLLAMA="true"; shift ;;
    --model)
      MODEL="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: bash scripts/build_and_pull.sh [--with-ollama] [--model NAME]"; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "${MODEL}" ]]; then
  MODEL="${OLLAMA_MODEL:-}"
fi

if [[ -z "${MODEL}" ]]; then
  echo "Error: model name not provided. Set OLLAMA_MODEL in .env or pass --model <name>." >&2
  exit 1
fi

echo "==> Building API image"
docker compose build api

if [[ "$WITH_OLLAMA" == "true" ]]; then
  echo "==> Using compose-managed Ollama service"
  export COMPOSE_PROFILES=ollama
  export OLLAMA_HOST=${OLLAMA_HOST:-http://ollama:11434}

  echo "==> Starting Ollama service"
  docker compose up -d ollama

  echo "==> Pulling model '${MODEL}' inside the Ollama container"
  docker compose exec -T ollama ollama pull "$MODEL"

  echo "==> Starting API service"
  docker compose up -d api
else
  echo "==> Using host Ollama"
  export OLLAMA_HOST=${OLLAMA_HOST:-http://host.docker.internal:11434}

  if command -v ollama >/dev/null 2>&1; then
    echo "==> Pulling model '${MODEL}' on host"
    ollama pull "$MODEL"
  else
    echo "Warning: 'ollama' CLI not found on host; skipping model pull on host." >&2
    echo "Ensure your host Ollama has the model available: $MODEL" >&2
  fi

  echo "==> Starting API service"
  docker compose up -d api
fi

echo "\nDone. Services running:"
docker compose ps

echo "\nHealth check: curl http://localhost:8000/api/health"
echo "Chat example: POST http://localhost:8000/api/chat"
echo "Model: $MODEL | OLLAMA_HOST (effective for API): ${OLLAMA_HOST}"

