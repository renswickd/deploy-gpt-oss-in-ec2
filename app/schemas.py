from __future__ import annotations

from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field


Role = Literal["system", "user", "assistant"]


class Message(BaseModel):
    role: Role
    content: str


class ChatRequest(BaseModel):
    messages: List[Message]
    stream: bool = False
    temperature: Optional[float] = 0.2
    options: Optional[Dict[str, Any]] = None
