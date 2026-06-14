"""Async client for a local Ollama instance, reached over Tailscale.

Used for runtime intelligence (NL preference parsing, alert copy) so the
hot path costs zero Claude tokens. Entirely opt-in — `is_enabled()` is False
unless `LOCAL_LLM_BASE` is configured.
"""
from __future__ import annotations
import json
import logging

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class LocalLLMError(Exception):
    """Raised when the local LLM is unreachable, errors, or returns invalid JSON."""


def is_enabled() -> bool:
    return bool(settings.local_llm_base)


class OllamaClient:
    """Thin async wrapper around Ollama's `/api/chat` endpoint with JSON-mode output."""

    def __init__(self, base_url: str | None = None, model: str | None = None, timeout: float = 30.0):
        self.base_url = (base_url if base_url is not None else settings.local_llm_base).rstrip("/")
        self.model = model or settings.local_llm_model
        self.timeout = timeout

    async def chat_json(self, system: str, user: str) -> dict:
        """Send a system+user message pair and return the parsed JSON response.

        Raises LocalLLMError if the request fails, times out, or the model's
        `message.content` is not valid JSON.
        """
        if not self.base_url:
            raise LocalLLMError("LOCAL_LLM_BASE is not configured")

        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "format": "json",
            "stream": False,
        }

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                resp = await client.post(f"{self.base_url}/api/chat", json=payload)
                resp.raise_for_status()
                data = resp.json()
        except httpx.HTTPError as exc:
            raise LocalLLMError(f"Local LLM request failed: {exc}") from exc

        try:
            content = data["message"]["content"]
        except (KeyError, TypeError) as exc:
            raise LocalLLMError(f"Local LLM response missing message.content: {data!r}") from exc

        try:
            return json.loads(content)
        except json.JSONDecodeError as exc:
            raise LocalLLMError(f"Local LLM returned invalid JSON: {content!r}") from exc
