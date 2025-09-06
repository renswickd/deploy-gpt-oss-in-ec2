from __future__ import annotations

import json
from typing import Any, Dict

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import JSONResponse, StreamingResponse
from starlette.concurrency import iterate_in_threadpool

from ..core.config import settings
from ..schemas import ChatRequest

router = APIRouter()


async def get_client(request: Request):
    client = getattr(request.app.state, "ollama_client", None)
    if client is None:
        raise HTTPException(status_code=503, detail="Ollama client not initialized")
    return client


@router.get("/health")
async def health(request: Request, client=Depends(get_client)):
    try:
        tags = await run_in_threadpool(client.list)
        return {"status": "ok", "ollama": "reachable", "tags": tags}
    except Exception as e:
        return JSONResponse(status_code=503, content={"status": "degraded", "error": str(e)})


@router.post("/chat")
async def chat(req: ChatRequest, client=Depends(get_client)):
    payload_messages: list[dict[str, str]] = [m.model_dump() for m in req.messages]

    # Merge temperature into options for the Ollama API
    merged_options: Dict[str, Any] = {}
    if req.options:
        merged_options.update(req.options)
    if req.temperature is not None:
        merged_options.setdefault("temperature", req.temperature)

    if req.stream:
        def stream_gen_sync():
            try:
                for part in client.chat(
                    model=settings.ollama_model,
                    messages=payload_messages,
                    stream=True,
                    options=merged_options or None,
                ):
                    yield json.dumps(part) + "\n"
            except Exception as e:
                yield json.dumps({"error": str(e)}) + "\n"

        return StreamingResponse(
            iterate_in_threadpool(stream_gen_sync()),
            media_type="application/x-ndjson",
        )

    try:
        data: Dict[str, Any] = await run_in_threadpool(
            lambda: client.chat(
                model=settings.ollama_model,
                messages=payload_messages,
                stream=False,
                options=merged_options or None,
            )
        )
        return data
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Ollama error: {e}")
