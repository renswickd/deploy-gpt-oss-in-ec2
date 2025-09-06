# Local LLM FastAPI App (Ollama)

A FastAPI service that calls a locally hosted Ollama model for chat-style interactions. Uses the official `ollama` Python client. Designed with simple, clean structure and reasonable best practices.

## Prerequisites

- Python 3.10+
- [Ollama](https://ollama.com) running locally (default `http://localhost:11434`)
- Considering the extensive resource usage, `llama3:8b` model available in local Ollama. (for testing the app functionalities)

## Configuration

The app reads settings from `.env` in the project root.

Required:

- `OLLAMA_MODEL` — the model name in Ollama (e.g. `llama3:8b`)

Optional:

- `OLLAMA_HOST` — default `http://localhost:11434`
- `APP_NAME` — default `Local LLM API`
- `DEBUG` — default `false`
- `CORS_ORIGINS` — comma-separated list (defaults to `*`)

## Install & Run

```bash
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\\Scripts\\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### Docker/Compose host configuration

- If the API runs in a container and Ollama runs on the host (macOS/Windows), set `OLLAMA_HOST=http://host.docker.internal:11434`.
- If both run in compose, use the Ollama service name, e.g. `OLLAMA_HOST=http://ollama:11434`.

## Endpoints

- `GET /` — basic info
- `GET /api/health` — app + Ollama health
- `POST /api/chat` — chat completion

### POST /api/chat

Body:

```json
{
  "messages": [
    {"role": "system", "content": "You are helpful."},
    {"role": "user", "content": "Say hi in one sentence."}
  ],
  "stream": false,
  "temperature": 0.2
}
```

- If `stream: true`, the response is newline-delimited JSON (`application/x-ndjson`) compatible with Ollama streaming chunks.
- If `stream: false` or omitted, returns a single JSON object from Ollama.

## Notes

- Startup performs a best-effort health check but does not fail the app if Ollama is down.
