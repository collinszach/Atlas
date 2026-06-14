"""Natural-language → Skywatch preference compilation via the local LLM."""
from __future__ import annotations
import logging
from typing import Any

from app.models.skywatch import SkywatchPreference
from app.services.llm import LocalLLMError, OllamaClient

logger = logging.getLogger(__name__)

_VALID_WATCHLIST_KINDS = {"airline", "type", "registration"}

MIN_RADIUS_KM = 5
MAX_RADIUS_KM = 250

_SYSTEM_PROMPT = """\
You translate a user's natural-language aircraft-alert preferences into a strict JSON object.

Output JSON with exactly these keys:
- "rare_types": boolean — true if the user wants alerts for rare, unusual, old, vintage, \
classic, warbird, or "special" aircraft types.
- "military": boolean — true if the user wants alerts for military, government, or VIP aircraft.
- "emergencies": boolean — true if the user wants alerts for aircraft in trouble — emergencies, \
mayday, distress, squawking 7700/7600/7500, or flying unusually low.
- "radius_km": integer between 5 and 250 — how far around the user's location to watch. \
If the user doesn't mention a distance, infer a reasonable default (30) or use the current value \
if given. Convert miles to km (1 mile ≈ 1.6 km) and nautical miles to km (1 nm ≈ 1.852 km).
- "watchlist": an array (may be empty) of objects with keys "kind" (one of "airline", "type", \
"registration") and "value" (string), for any specific airlines, aircraft types, or tail numbers \
the user names.

Only set a boolean to true if the user's text clearly asks for that category. Leave categories \
the user doesn't mention unchanged from their current value, which is provided in the user message. \
Respond with ONLY the JSON object, no commentary.
"""


def _clamp_radius(value: Any, fallback: float) -> int:
    try:
        radius = int(round(float(value)))
    except (TypeError, ValueError):
        radius = int(round(fallback))
    return max(MIN_RADIUS_KM, min(MAX_RADIUS_KM, radius))


def _sanitize_watchlist(raw: Any) -> list[dict[str, str]]:
    if not isinstance(raw, list):
        return []
    cleaned: list[dict[str, str]] = []
    for entry in raw:
        if not isinstance(entry, dict):
            continue
        kind = entry.get("kind")
        value = entry.get("value")
        if kind not in _VALID_WATCHLIST_KINDS:
            continue
        if not isinstance(value, str) or not value.strip():
            continue
        cleaned.append({"kind": kind, "value": value.strip()})
    return cleaned


async def compile_preferences(nl_prompt: str, current: SkywatchPreference) -> dict:
    """Ask the local LLM to translate `nl_prompt` into preference field updates.

    Returns a dict with keys suitable for applying via `setattr` onto a
    `SkywatchPreference`: `notable_types_enabled`, `military_enabled`,
    `emergency_enabled`, `radius_km`, and optionally `watchlist` /
    `watchlist_enabled`.

    Raises `LocalLLMError` if the LLM is unreachable or returns output that
    can't be interpreted.
    """
    client = OllamaClient()

    user_message = (
        f"Current preferences: rare_types={current.notable_types_enabled}, "
        f"military={current.military_enabled}, emergencies={current.emergency_enabled}, "
        f"radius_km={float(current.radius_km)}.\n\n"
        f"User request: {nl_prompt.strip()}"
    )

    result = await client.chat_json(_SYSTEM_PROMPT, user_message)

    if not isinstance(result, dict):
        raise LocalLLMError(f"Local LLM returned non-object JSON: {result!r}")

    updates: dict[str, Any] = {}
    recognized = False

    if "rare_types" in result and isinstance(result["rare_types"], bool):
        updates["notable_types_enabled"] = result["rare_types"]
        recognized = True
    if "military" in result and isinstance(result["military"], bool):
        updates["military_enabled"] = result["military"]
        recognized = True
    if "emergencies" in result and isinstance(result["emergencies"], bool):
        updates["emergency_enabled"] = result["emergencies"]
        recognized = True
    if "radius_km" in result:
        recognized = True

    watchlist = _sanitize_watchlist(result.get("watchlist"))
    if watchlist:
        updates["watchlist"] = watchlist
        updates["watchlist_enabled"] = True
        recognized = True

    if not recognized:
        raise LocalLLMError(f"Local LLM returned no usable preference fields: {result!r}")

    updates["radius_km"] = _clamp_radius(result.get("radius_km"), float(current.radius_km))

    return updates
