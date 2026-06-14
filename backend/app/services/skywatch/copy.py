"""LLM-generated alert copy for Skywatch push notifications.

Optional enrichment: if the local LLM is disabled or errors, callers should
fall back to the existing templated copy in `watcher._build_payload`.
"""
from __future__ import annotations
import logging

from app.services.adsb.models import Aircraft
from app.services.llm import LocalLLMError, OllamaClient, is_enabled
from app.services.skywatch.rules import Match

logger = logging.getLogger(__name__)

_SYSTEM_PROMPT = """\
You write short, factual push-notification copy for an aircraft-spotting app. Given details \
about an aircraft and why it triggered an alert, respond with ONLY a JSON object with two keys:
- "title": a short notification title (under 40 chars), e.g. "Antonov An-124 overhead".
- "body": one concise factual sentence (under 100 chars) with notable details like type, \
distance, direction, or altitude, e.g. "Soviet-era heavy freighter · 8 km north · FL310".

Be factual and understated — no hype, exclamation points, or emoji. If a detail is unknown, omit it.
"""


def _format_altitude(alt_baro: int | None) -> str | None:
    if alt_baro is None:
        return None
    if alt_baro == 0:
        return "on the ground"
    return f"FL{round(alt_baro / 100):03d}"


async def alert_copy(aircraft: Aircraft, match: Match) -> tuple[str, str] | None:
    """Generate (title, body) for an alert via the local LLM, or None to fall back.

    Returns None if the local LLM is disabled, unreachable, or returns
    unusable output — never raises.
    """
    if not is_enabled():
        return None

    details: list[str] = [f"trigger: {match.trigger}", f"reason: {match.message}"]
    if aircraft.type:
        details.append(f"type code: {aircraft.type}")
    if aircraft.flight:
        details.append(f"callsign/flight: {aircraft.flight}")
    if aircraft.registration:
        details.append(f"registration: {aircraft.registration}")
    if aircraft.distance_km is not None:
        details.append(f"distance: {aircraft.distance_km:.1f} km")
    altitude = _format_altitude(aircraft.alt_baro)
    if altitude:
        details.append(f"altitude: {altitude}")
    if aircraft.track is not None:
        details.append(f"heading: {aircraft.track:.0f} degrees")

    user_message = "\n".join(details)

    try:
        client = OllamaClient()
        result = await client.chat_json(_SYSTEM_PROMPT, user_message)
    except LocalLLMError as exc:
        logger.warning("alert_copy: local LLM unavailable, falling back to template: %s", exc)
        return None

    if not isinstance(result, dict):
        return None

    title = result.get("title")
    body = result.get("body")
    if not isinstance(title, str) or not isinstance(body, str):
        return None
    title, body = title.strip(), body.strip()
    if not title or not body:
        return None

    return title, body
