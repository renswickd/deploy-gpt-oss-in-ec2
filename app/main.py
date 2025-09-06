from __future__ import annotations

import logging
from contextlib import asynccontextmanager

import ollama
from fastapi import FastAPI
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware

from .api.routes import router as api_router
from .core.config import settings

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create a single Ollama client for reuse
    app.state.ollama_client = ollama.Client(host=settings.ollama_host)
    try:
        # Best-effort connectivity check
        await run_in_threadpool(app.state.ollama_client.list)
        logger.info("Connected to Ollama at %s", settings.ollama_host)
    except Exception as e:
        logger.warning("Ollama health check failed: %s", e)
    yield
    # The ollama Client does not maintain open connections that require closing


app = FastAPI(title=settings.app_name, version="0.1.0", lifespan=lifespan)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes
app.include_router(api_router, prefix="/api")


@app.get("/")
async def root():
    return {"name": settings.app_name, "ollama_model": settings.ollama_model}
