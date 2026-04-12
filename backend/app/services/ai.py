from __future__ import annotations

import json
import logging
import re
from typing import Any

from anthropic import AsyncAnthropic

from app.config import settings

logger = logging.getLogger(__name__)

_client: AsyncAnthropic | None = None

MODEL = "claude-haiku-4-5-20251001"


def _get_client() -> AsyncAnthropic:
    global _client
    if _client is None:
        if not settings.anthropic_api_key:
            raise RuntimeError("ANTHROPIC_API_KEY is not configured")
        _client = AsyncAnthropic(api_key=settings.anthropic_api_key)
    return _client


def _strip_fences(text: str) -> str:
    """Remove markdown code fences (```json ... ```) if present."""
    text = text.strip()
    match = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
    if match:
        return match.group(1).strip()
    return text


async def get_recommendations(
    preferences: dict[str, Any],
    already_visited: list[str],
) -> list[dict[str, Any]]:
    """Return 3 AI destination recommendations as a list of dicts."""
    prompt = (
        f"You are a knowledgeable travel advisor. Based on the traveler's preferences and history, "
        f"suggest exactly 3 destination recommendations.\n\n"
        f"Traveler preferences:\n{json.dumps(preferences, indent=2)}\n\n"
        f"Countries already visited (ISO codes): {', '.join(already_visited) if already_visited else 'none'}\n\n"
        f"Return ONLY a JSON array (no markdown, no explanation) with exactly 3 objects, each with keys:\n"
        f"  country (string), country_code (ISO 3166-1 alpha-2), city (string or null),\n"
        f"  why_youll_love_it (string, personalized to their history/preferences),\n"
        f"  best_time (string), rough_cost (\"budget\"|\"moderate\"|\"luxury\"),\n"
        f"  getting_there (string)"
    )
    client = _get_client()
    message = await client.messages.create(
        model=MODEL,
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )
    raw = message.content[0].text
    try:
        return json.loads(_strip_fences(raw))
    except json.JSONDecodeError as exc:
        raise ValueError(f"AI returned non-JSON response: {raw!r}") from exc


async def get_destination_brief(country: str, country_code: str | None, city: str | None) -> dict[str, Any]:
    """Return a destination brief as a dict."""
    location = f"{city}, {country}" if city else country
    prompt = (
        f"You are a travel expert. Write a concise destination brief for: {location}\n\n"
        f"Return ONLY a JSON object (no markdown, no explanation) with keys:\n"
        f"  destination (string), overview (string, 2-3 sentences),\n"
        f"  best_months (list of ints 1-12), visa_notes (string),\n"
        f"  rough_costs (string), must_do (list of strings, max 5),\n"
        f"  food_highlights (list of strings, max 5),\n"
        f"  transport_within (string)"
    )
    client = _get_client()
    message = await client.messages.create(
        model=MODEL,
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )
    raw = message.content[0].text
    try:
        return json.loads(_strip_fences(raw))
    except json.JSONDecodeError as exc:
        raise ValueError(f"AI returned non-JSON response: {raw!r}") from exc


async def enrich_bucket_list_item(
    country_name: str | None,
    country_code: str | None,
    city: str | None,
    reason: str | None,
) -> str:
    """Return a short AI-generated summary string for a bucket list item."""
    location = city if city else country_name or country_code or "Unknown"
    context = f" The traveler wants to go because: {reason}" if reason else ""
    prompt = (
        f"Write a 2-3 sentence travel teaser for {location}.{context} "
        f"Make it evocative and specific — highlight what makes this place special. "
        f"Return only the plain text summary, no markdown, no JSON."
    )
    client = _get_client()
    message = await client.messages.create(
        model=MODEL,
        max_tokens=256,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text.strip()
