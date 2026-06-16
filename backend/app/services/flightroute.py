"""Route enrichment via adsbdb (free, no key required).

GET https://api.adsbdb.com/v0/callsign/{callsign}
Returns response.flightroute with origin/destination airport info.

In-memory cache with ~6h TTL to avoid hammering the API on repeat callsigns.
"""
from __future__ import annotations

import logging
import time
from typing import NamedTuple

import httpx

logger = logging.getLogger(__name__)

_BASE = "https://api.adsbdb.com/v0/callsign"
_TIMEOUT = 5.0
_TTL = 6 * 3600  # 6 hours in seconds

# Cache: callsign -> (result | None, expiry_ts)
_cache: dict[str, tuple["RouteInfo | None", float]] = {}


class RouteInfo(NamedTuple):
    origin_iata: str | None
    origin_name: str | None
    dest_iata: str | None
    dest_name: str | None


async def get_route(callsign: str) -> RouteInfo | None:
    """Look up origin→destination for a callsign. Returns None on any error."""
    key = callsign.strip().upper()
    now = time.monotonic()

    cached = _cache.get(key)
    if cached is not None:
        result, expiry = cached
        if now < expiry:
            return result

    result = await _fetch_route(key)
    _cache[key] = (result, now + _TTL)
    return result


async def _fetch_route(callsign: str) -> RouteInfo | None:
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(f"{_BASE}/{callsign}")
            if resp.status_code != 200:
                return None
            data = resp.json()
    except Exception as exc:
        logger.debug("adsbdb route lookup failed for %s: %s", callsign, exc)
        return None

    try:
        fr = data.get("response", {}).get("flightroute")
        if not fr:
            return None
        origin = fr.get("origin") or {}
        dest = fr.get("destination") or {}
        return RouteInfo(
            origin_iata=origin.get("iata_code") or None,
            origin_name=origin.get("municipality") or origin.get("name") or None,
            dest_iata=dest.get("iata_code") or None,
            dest_name=dest.get("municipality") or dest.get("name") or None,
        )
    except Exception as exc:
        logger.debug("adsbdb parse error for %s: %s", callsign, exc)
        return None
