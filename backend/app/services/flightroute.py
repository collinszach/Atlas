"""Route enrichment via adsbdb (free, no key required).

GET https://api.adsbdb.com/v0/callsign/{callsign}
Returns response.flightroute with origin/destination airport info (incl. coordinates).

The adsbdb route is the *scheduled* route for a callsign — usually right, but stale or
reversed for some flights. `validate_route` checks it against the aircraft's actual
position + heading and either keeps it, swaps it (reverse leg), or drops it (contradicts
reality) so we never display a wrong departure/arrival.

In-memory cache with ~6h TTL to avoid hammering the API on repeat callsigns.
"""
from __future__ import annotations

import logging
import math
import time
from typing import NamedTuple

import httpx

from app.services.adsb.geo import haversine_km

logger = logging.getLogger(__name__)

_BASE = "https://api.adsbdb.com/v0/callsign"
_TIMEOUT = 5.0
_TTL = 6 * 3600

_cache: dict[str, tuple["RouteInfo | None", float]] = {}

# Heading must be within this of the bearing-to-destination to trust the route.
_HEADING_TOLERANCE_DEG = 75.0
# Within this distance of an endpoint, the aircraft is departing/arriving — trust the route.
_NEAR_ENDPOINT_KM = 90.0


class RouteInfo(NamedTuple):
    origin_iata: str | None
    origin_name: str | None
    dest_iata: str | None
    dest_name: str | None
    origin_lat: float | None = None
    origin_lon: float | None = None
    dest_lat: float | None = None
    dest_lon: float | None = None

    def swapped(self) -> "RouteInfo":
        return RouteInfo(
            origin_iata=self.dest_iata, origin_name=self.dest_name,
            dest_iata=self.origin_iata, dest_name=self.origin_name,
            origin_lat=self.dest_lat, origin_lon=self.dest_lon,
            dest_lat=self.origin_lat, dest_lon=self.origin_lon,
        )


async def get_route(callsign: str) -> RouteInfo | None:
    """Look up origin→destination for a callsign. Returns None on any error."""
    key = callsign.strip().upper()
    now = time.monotonic()
    cached = _cache.get(key)
    if cached is not None and now < cached[1]:
        return cached[0]
    result = await _fetch_route(key)
    _cache[key] = (result, now + _TTL)
    return result


def _coord(airport: dict, lat: bool) -> float | None:
    for k in (("latitude", "latitude_deg") if lat else ("longitude", "longitude_deg")):
        v = airport.get(k)
        if v is not None:
            try:
                return float(v)
            except (TypeError, ValueError):
                pass
    return None


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
        o = fr.get("origin") or {}
        d = fr.get("destination") or {}
        return RouteInfo(
            origin_iata=o.get("iata_code") or None,
            origin_name=o.get("municipality") or o.get("name") or None,
            dest_iata=d.get("iata_code") or None,
            dest_name=d.get("municipality") or d.get("name") or None,
            origin_lat=_coord(o, True), origin_lon=_coord(o, False),
            dest_lat=_coord(d, True), dest_lon=_coord(d, False),
        )
    except Exception as exc:
        logger.debug("adsbdb parse error for %s: %s", callsign, exc)
        return None


def _bearing(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Initial great-circle bearing from point 1 to point 2, in degrees [0, 360)."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dl = math.radians(lon2 - lon1)
    y = math.sin(dl) * math.cos(p2)
    x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return (math.degrees(math.atan2(y, x)) + 360.0) % 360.0


def _ang_diff(a: float, b: float) -> float:
    d = abs(a - b) % 360.0
    return min(d, 360.0 - d)


def validate_route(
    route: RouteInfo | None,
    ac_lat: float | None,
    ac_lon: float | None,
    track: float | None,
) -> RouteInfo | None:
    """Reconcile a scheduled route with the aircraft's actual position/heading.

    Returns the route (possibly reversed) if it's consistent, or None if it contradicts
    where the aircraft actually is/going — so the UI never shows a wrong airport.
    """
    if route is None:
        return None
    # Can't validate without coords on both endpoints — trust the scheduled route.
    if None in (route.origin_lat, route.origin_lon, route.dest_lat, route.dest_lon, ac_lat, ac_lon):
        return route

    d_dest = haversine_km(ac_lat, ac_lon, route.dest_lat, route.dest_lon)
    d_orig = haversine_km(ac_lat, ac_lon, route.origin_lat, route.origin_lon)

    # Departing or arriving — trust it.
    if d_dest < _NEAR_ENDPOINT_KM or d_orig < _NEAR_ENDPOINT_KM:
        return route
    if track is None:
        return route

    to_dest = _bearing(ac_lat, ac_lon, route.dest_lat, route.dest_lon)
    to_orig = _bearing(ac_lat, ac_lon, route.origin_lat, route.origin_lon)
    if _ang_diff(track, to_dest) <= _HEADING_TOLERANCE_DEG:
        return route
    if _ang_diff(track, to_orig) <= _HEADING_TOLERANCE_DEG:
        return route.swapped()
    # Heading toward neither endpoint — the route is stale/wrong for this flight.
    return None
