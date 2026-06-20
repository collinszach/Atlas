"""Aircraft database lookup via adsbdb (free, keyless).

GET https://api.adsbdb.com/v0/aircraft/{registration}
-> response.aircraft: manufacturer, type, registered_owner, registered_owner_country_name
"""
from __future__ import annotations

import logging
import time
from typing import NamedTuple

import httpx

logger = logging.getLogger(__name__)

_BASE = "https://api.adsbdb.com/v0/aircraft"
_TIMEOUT = 5.0
_TTL = 24 * 3600

_cache: dict[str, tuple["AircraftInfo | None", float]] = {}


class AircraftInfo(NamedTuple):
    manufacturer: str | None
    type_long: str | None
    owner: str | None
    owner_country: str | None


async def get_aircraft_info(registration: str | None) -> AircraftInfo | None:
    """Look up airframe details by registration. None on missing reg / any error."""
    if not registration:
        return None
    key = registration.upper()
    now = time.monotonic()
    cached = _cache.get(key)
    if cached is not None and now < cached[1]:
        return cached[0]

    result = await _fetch(key)
    _cache[key] = (result, now + _TTL)
    return result


async def _fetch(registration: str) -> AircraftInfo | None:
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(f"{_BASE}/{registration}")
            if resp.status_code != 200:
                return None
            a = (resp.json().get("response") or {}).get("aircraft") or {}
    except Exception as exc:  # noqa: BLE001
        logger.debug("adsbdb aircraft lookup failed for %s: %s", registration, exc)
        return None
    if not a:
        return None
    return AircraftInfo(
        manufacturer=a.get("manufacturer") or None,
        type_long=a.get("type") or None,
        owner=a.get("registered_owner") or None,
        owner_country=a.get("registered_owner_country_name") or None,
    )
