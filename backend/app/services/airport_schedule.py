"""Airport departures/arrivals via AviationStack (reuses the same key as
transport.py's flight enrichment — no new account needed).

GET http://api.aviationstack.com/v1/flights?dep_iata={iata}   -> departures
GET http://api.aviationstack.com/v1/flights?arr_iata={iata}   -> arrivals

ADS-B (airplanes.live / dump1090) only carries live positions, not scheduled
flights, so this is a genuinely separate data source. Cached 15 min per
(iata, direction) since schedules don't change second-to-second.
"""
from __future__ import annotations

import logging
import time
from enum import Enum
from typing import NamedTuple

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

_BASE = "http://api.aviationstack.com/v1/flights"
_TIMEOUT = 10.0
_TTL = 15 * 60


class Direction(str, Enum):
    DEPARTURES = "departures"
    ARRIVALS = "arrivals"


class ScheduledFlight(NamedTuple):
    flight_number: str | None
    airline: str | None
    aircraft_type: str | None
    scheduled_time: str | None
    estimated_time: str | None
    actual_time: str | None
    status: str | None
    origin_iata: str | None
    origin_name: str | None
    dest_iata: str | None
    dest_name: str | None
    gate: str | None
    terminal: str | None


_cache: dict[tuple[str, Direction], tuple[list[ScheduledFlight], float]] = {}


async def get_schedule(iata: str, direction: Direction) -> list[ScheduledFlight]:
    """Departures or arrivals for an airport. Empty list if unconfigured or on error —
    callers should fall back to an ADS-B-derived "recent activity" view, never a dead end."""
    if not settings.aviationstack_api_key:
        return []
    key = (iata.upper(), direction)
    now = time.monotonic()
    cached = _cache.get(key)
    if cached is not None and now < cached[1]:
        return cached[0]

    result = await _fetch(iata.upper(), direction)
    _cache[key] = (result, now + _TTL)
    return result


async def _fetch(iata: str, direction: Direction) -> list[ScheduledFlight]:
    param = "dep_iata" if direction is Direction.DEPARTURES else "arr_iata"
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
            resp = await client.get(
                _BASE,
                params={"access_key": settings.aviationstack_api_key, param: iata, "limit": 50},
            )
            if resp.status_code != 200:
                return []
            flights = resp.json().get("data") or []
    except Exception as exc:  # noqa: BLE001
        logger.debug("aviationstack schedule lookup failed for %s/%s: %s", iata, direction, exc)
        return []

    out: list[ScheduledFlight] = []
    for f in flights:
        dep = f.get("departure") or {}
        arr = f.get("arrival") or {}
        flight = f.get("flight") or {}
        airline = f.get("airline") or {}
        aircraft = f.get("aircraft") or {}
        out.append(
            ScheduledFlight(
                flight_number=flight.get("iata"),
                airline=airline.get("name"),
                aircraft_type=aircraft.get("icao") if aircraft else None,
                scheduled_time=(dep if direction is Direction.DEPARTURES else arr).get("scheduled"),
                estimated_time=(dep if direction is Direction.DEPARTURES else arr).get("estimated"),
                actual_time=(dep if direction is Direction.DEPARTURES else arr).get("actual"),
                status=f.get("flight_status"),
                origin_iata=dep.get("iata"),
                origin_name=dep.get("airport"),
                dest_iata=arr.get("iata"),
                dest_name=arr.get("airport"),
                gate=(dep if direction is Direction.DEPARTURES else arr).get("gate"),
                terminal=(dep if direction is Direction.DEPARTURES else arr).get("terminal"),
            )
        )
    return out
