# Local LLM FastAPI App (Ollama)

A FastAPI service that calls a locally hosted Ollama model for chat-style interactions. Uses the official `ollama` Python client. Designed with simple, clean structure and reasonable best practices.

## Prerequisites

- Python 3.10+
- [Ollama](https://ollama.com) running within container (default `http://localhost:11434`)
- Considering the extensive resource usage, `llama3:8b` model available in local Ollama. (for testing the app functionalities)

## Configuration

The app reads settings from `.env` in the project root.

Required:

- Instance sizing for 20B (recommended):
    - GPU: 24 GB VRAM fits 4-bit quantization comfortably (e.g., g5.2xlarge).
    - CPU-only: favor 32–64 GB RAM; e.g., c7i.4xlarge (16 vCPU, 32 GB) for better headroom.

Optional:

- `OLLAMA_HOST` — default `http://ollama:11434`
- `APP_NAME` — default `Local gpt-oss-20b Chat API`
- `DEBUG` — default `false`
- `CORS_ORIGINS` — comma-separated list (defaults to `*`)

## Install & Run

```bash
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\\Scripts\\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

## Docker

Build the image:

```bash
docker build -t local-llm-api:latest .
```

### Docker Compose

Run an Ollama container too (optional):

```bash
docker compose --profile ollama up --build
```

The API is available at `http://localhost:8000`. Health check: `GET /api/health`.

### Docker/Compose host configuration

- If both run in compose, use the Ollama service name, e.g. `OLLAMA_HOST=http://ollama:11434`.

## AWS EC2 Deployment

To deploy this app with the `gpt-oss-20b` model on AWS EC2 (instance sizing, GPU options, Compose configurations, and hardening), see:

- `docs/aws-ec2-deployment.md`

Quick starts on EC2:

- Host Ollama (CPU or GPU on host):
- Compose-managed Ollama (same box):
  - `export OLLAMA_HOST=http://ollama:11434 && COMPOSE_PROFILES=ollama docker compose up --build -d`
  - `docker compose --profile ollama exec ollama ollama pull gpt-oss-20b`

Helper scripts:

- `bash scripts/ollama_container_setup.sh --model gpt-oss-20b [--gpus]` to run Ollama in a container and pull the model.

## Helper Script

Run a single script to build the image, pull the model, and start services:

```bash
# Host Ollama (default):
bash scripts/build_and_pull.sh --model "$OLLAMA_MODEL"
```

Notes:
- If `--model` is omitted, the script reads `OLLAMA_MODEL` from `.env`.

## Endpoints

- `GET /` — basic info
- `GET /api/health` — app + Ollama health
- `POST /api/chat` — chat completion

### POST /api/chat

Body:

```json
{
  "messages": [
    {"role": "system", "content": "You are helpful assistant."},
    {"role": "user", "content": "What is Langchain in one line?"}
  ],
  "stream": false,
  "temperature": 0.2
}
```

- If `stream: true`, the response is newline-delimited JSON (`application/x-ndjson`) compatible with Ollama streaming chunks.
- If `stream: false` or omitted, returns a single JSON object from Ollama.

## Notes

- Startup performs a best-effort health check but does not fail the app if Ollama is down.
