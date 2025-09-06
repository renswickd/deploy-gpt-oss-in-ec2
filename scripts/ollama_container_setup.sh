#!/usr/bin/env bash
set -euo pipefail

# Starts an Ollama container and pulls a model (GPU optional)
# Usage:
#   bash scripts/ollama_container_setup.sh --model gpt-oss-20b [--gpus]

MODEL=""
USE_GPU="true"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      MODEL="${2:-}"; shift 2 ;;
    --gpus)
      USE_GPU="true"; shift ;;
    -h|--help)
      echo "Usage: $0 --model <name> [--gpus]"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$MODEL" ]]; then
  echo "Error: --model <name> is required" >&2
  exit 1
fi

OPTS=(
  -d --restart unless-stopped
  -p 11434:11434
  -v ollama:/root/.ollama
  --name ollama
)

if [[ "$USE_GPU" == "true" ]]; then
  OPTS+=(--gpus all -e NVIDIA_VISIBLE_DEVICES=all)
fi

echo "==> Starting Ollama container"
docker rm -f ollama 2>/dev/null || true
docker run "${OPTS[@]}" ollama/ollama:latest

echo "==> Pulling model: $MODEL"
docker exec -it ollama ollama pull "$MODEL"

echo "Done. Ollama listening on http://localhost:11434"

