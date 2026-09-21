"""Device-independent collection of ADS-B observations.

The watcher only records what it sees while polling for a *user's* alerts, so
history accrued only while someone had the app open and a location fresher than
`skywatch_location_freshness_minutes`. In practice that meant a few minutes of
data and then nothing — useless for learning routes, arrival timing or delays.

This polls fixed sites on a schedule instead, so the corpus grows whether or not
anyone is using the app. It shares `cycle_timestamp` with the watcher so the two
land on the same bucket grid and the (hex, seen_at) constraint dedupes across
both rather than storing each observation twice.
"""
from __future__ import annotations

import logging

from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.services.adsb.airplanes_live import AdsbServiceError
from app.services.adsb.resolver import DataSourceResolver
from app.services.skywatch.tracks import cycle_timestamp, record_observations

logger = logging.getLogger(__name__)


def parse_sites(raw: str | None) -> list[tuple[float, float]]:
    """Parse `"lat,lon; lat,lon"` into coordinate pairs, skipping bad entries.

    A malformed site must not take the whole collector down with it, so each
    entry is validated independently and logged if unusable.
    """
    if not raw or not raw.strip():
        return []

    sites: list[tuple[float, float]] = []
    for chunk in raw.split(";"):
        chunk = chunk.strip()
        if not chunk:
            continue
        parts = chunk.split(",")
        if len(parts) != 2:
            logger.warning("Ignoring malformed collection site %r", chunk)
            continue
        try:
            lat, lon = float(parts[0]), float(parts[1])
        except ValueError:
            logger.warning("Ignoring non-numeric collection site %r", chunk)
            continue
        if not (-90.0 <= lat <= 90.0) or not (-180.0 <= lon <= 180.0):
            logger.warning("Ignoring out-of-range collection site %r", chunk)
            continue
        sites.append((lat, lon))
    return sites


def configured_sites() -> list[tuple[float, float]]:
    return parse_sites(settings.skywatch_collect_sites)


async def run_collection_cycle(
    session: AsyncSession,
    resolver: DataSourceResolver | None = None,
) -> int:
    """Record one observation pass over every configured site.

    Returns the number of rows written. Per-site failures are logged and skipped
    so one unreachable source cannot stop the others.
    """
    sites = configured_sites()
    if not sites:
        return 0

    resolver = resolver or DataSourceResolver()
    seen_at = cycle_timestamp()
    radius_km = settings.skywatch_track_radius_km
    total = 0

    for lat, lon in sites:
        try:
            aircraft = await resolver.get_aircraft(lat, lon, radius_km)
        except AdsbServiceError as exc:
            logger.warning("Collection site %s,%s unavailable: %s", lat, lon, exc)
            continue
        try:
            total += await record_observations(session, aircraft, seen_at)
            await session.commit()
        except Exception:
            logger.exception("Failed recording collection site %s,%s", lat, lon)
            await session.rollback()

    if total:
        logger.debug("Collection cycle recorded %s observations", total)
    return total
