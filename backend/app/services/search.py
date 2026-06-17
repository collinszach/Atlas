"""Aircraft search across airplanes.live lookup endpoints (free, keyless).

Routes a free-text query to the right airplanes.live endpoint(s) by shape:
  - 4 digits          -> /squawk/{q}   (e.g. 7700)
  - 6 hex chars       -> /hex/{q}
  - otherwise         -> /callsign/{q} + /reg/{q} + /type/{q}
"""
from __future__ import annotations

import asyncio
import logging
import re

import httpx

from app.config import settings
from app.services.adsb.models import Aircraft

logger = logging.getLogger(__name__)

_TIMEOUT = 8.0
_MAX_RESULTS = 30

_SQUAWK_RE = re.compile(r"^\d{4}$")
_HEX_RE = re.compile(r"^[0-9a-fA-F]{6}$")


def _suffixes_for(query: str) -> list[str]:
    q = query.strip()
    if not q:
        return []
    if _SQUAWK_RE.match(q):
        return [f"squawk/{q}"]
    if _HEX_RE.match(q) and not q.isdigit():
        return [f"hex/{q.lower()}"]
    enc = q.upper()
    return [f"callsign/{enc}", f"reg/{enc}", f"type/{enc}"]


async def _fetch(client: httpx.AsyncClient, suffix: str) -> list[Aircraft]:
    url = f"{settings.airplanes_live_base.rstrip('/')}/{suffix}"
    try:
        resp = await client.get(url)
        if resp.status_code != 200:
            return []
        raw = resp.json().get("ac") or []
    except Exception as exc:  # noqa: BLE001 - search must never raise
        logger.debug("search fetch failed for %s: %s", suffix, exc)
        return []
    out: list[Aircraft] = []
    for entry in raw:
        try:
            out.append(Aircraft.from_raw(entry))
        except ValueError:
            continue
    return out


async def search_aircraft(query: str) -> list[Aircraft]:
    """Return matching aircraft, deduped by hex. Empty list on no match / error."""
    suffixes = _suffixes_for(query)
    if not suffixes:
        return []
    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        results = await asyncio.gather(
            *[_fetch(client, s) for s in suffixes], return_exceptions=True
        )
    seen: dict[str, Aircraft] = {}
    for r in results:
        if isinstance(r, Exception):
            continue
        for ac in r:
            seen.setdefault(ac.hex, ac)
    return list(seen.values())[:_MAX_RESULTS]
