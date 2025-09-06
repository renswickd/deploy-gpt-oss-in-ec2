# Deploying Local LLM API with gpt-oss-20b on AWS EC2

This guide walks through deploying the FastAPI + Ollama app on AWS EC2 to serve the `gpt-oss-20b` model. It focuses on practical, reproducible steps you can adapt into a blog post later.

## Overview

- App: FastAPI service (`/api/chat`) using the official `ollama` Python client.
- Model: `gpt-oss-20b` served by Ollama.
- Deploy options:
  - Host Ollama on the same EC2 instance (simplest single-box setup).
  - Run Ollama as a separate Docker service (compose profile) on the same EC2.
  - Advanced: Split API and Ollama across instances (private networking).

## Instance Sizing for 20B Models

20B-parameter models are heavy. Resource needs depend on quantization and context length. Since we can’t verify your exact model artifact here, use these conservative, experience-based guidelines:

- RAM (CPU inference):
  - Recommend 32 GB RAM minimum to avoid swapping for typical contexts (4–8k tokens). 64 GB if you expect concurrent users or long contexts.

- GPU (optional but faster):
  - 4-bit on a single 24 GB GPU (e.g., NVIDIA L4 or A10G) generally fits with room for KV cache; higher context or concurrency benefits from more VRAM.
  - Full-precision or 8-bit needs much more VRAM (typically 40 GB+).


Recommended EC2 types (pick one):
- GPU-accelerated (best latency):
  - `g5.2xlarge` (1× A10G 24 GB, 8 vCPU, 32 GB RAM) — good starter.
  - `g6.xlarge` (1× L4 24 GB) — newer gen alternative where available.
  - For heavier concurrency: step up to larger g5/g6 sizes.
- CPU-only (cost-effective, slower):
  - `c7i.2xlarge` (8 vCPU, 16 GB) — works for tests; prefer 32 GB RAM.
  - `c7i.4xlarge` (16 vCPU, 32 GB) — better headroom.
  - Any `m7i` with 32–64 GB RAM if balanced compute/memory is preferred.


## High-Level Architecture

```
Client → FastAPI (Docker) → Ollama (host or Docker) → gpt-oss-20b
```

- The API calls `OLLAMA_HOST` (default `http://localhost:11434` on host, or `http://ollama:11434` in compose) to reach the model server.

## Provision EC2

1) Launch an instance with one of the recommended types above.
2) Choose an OS (Ubuntu 22.04 LTS or Amazon Linux 2023 are common).
3) Attach a Security Group allowing your admin IPs.
4) Storage: allocate at least 50–100 GB if you plan to host multiple models.

## Prepare the Instance

Install Docker and Compose (Ubuntu example):

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
```

GPU (only if you selected a GPU instance):
- Prefer a GPU-enabled AMI (e.g., NVIDIA/AWS DLAMI) to skip manual driver installs.
- Otherwise, install NVIDIA drivers and the NVIDIA container runtime (`nvidia-container-toolkit`). Once installed, `docker run --gpus all …` should work and `nvidia-smi` should report the GPU inside containers.

## Get the App on EC2

```bash
git clone <your_repo_url>
cd <repo>
cp .env.example .env  # if you have one; otherwise create .env
echo "OLLAMA_MODEL=gpt-oss-20b" >> .env
```

Set `OLLAMA_HOST` per your deployment mode (see below).

## Deployment Modes

### A) Host Ollama (single instance, simplest)

1) Install Ollama on the host and start it:

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama serve >/var/log/ollama.log 2>&1 &
```

2) Pull the model on the host:

```bash
ollama pull gpt-oss-20b
```

3) Run the API via Docker Compose:

```bash
docker compose up --build -d
```

The API listens on `:8000`. Health endpoint: `GET /api/health`.

### B) Compose-managed Ollama (same instance)

Run both services with the optional `ollama` profile and point the API to the service name:

```bash
export OLLAMA_HOST=http://ollama:11434
COMPOSE_PROFILES=ollama docker compose up --build -d
docker compose --profile ollama exec ollama ollama pull gpt-oss-20b
```

GPU acceleration: enable GPU for the Ollama service in `docker-compose.yml` by adding under `services.ollama`:

```yaml
    # Enable GPU for Ollama container (Compose v2.12+)
    gpus: all
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
```

Then restart:

```bash
COMPOSE_PROFILES=ollama docker compose up -d --build
```

### C) API and Ollama on different instances

1) Run Ollama on a private EC2 or container; allow inbound 11434 from the API’s Security Group.
2) Set the API’s `OLLAMA_HOST` to the private address of the Ollama instance.

## Using the Helper Script

This repo includes `scripts/build_and_pull.sh` to automate building and pulling models.

Host Ollama:
```bash
bash scripts/build_and_pull.sh --model gpt-oss-20b
```

## Cost & Throughput Considerations

- GPU instances cost more but provide lower latency. For sporadic traffic, CPU-only with smaller quantization can be cost-effective.
- Long contexts and streaming responses increase memory pressure. Scale vCPU/RAM or VRAM accordingly.
- For concurrency, scale out using multiple API replicas behind a load balancer. If using a single Ollama instance, it becomes the bottleneck—consider sharding models across instances for higher throughput.

## Troubleshooting

- 502 from `/api/chat`: API cannot reach `OLLAMA_HOST`. Verify the value inside the container and that the Ollama server is healthy.
- Slow responses: reduce `temperature`, consider smaller quantization, or add GPU.
- GPU not used in container: ensure NVIDIA drivers and `--gpus all`/`gpus: all` is set; check `nvidia-smi` inside the container.

---

This guide is intentionally practical. If you need deeper model-specific tuning for `gpt-oss-20b` (context windows, rope scaling, quantization formats), confirm with the artifact you’re using and benchmark under your real prompts.

