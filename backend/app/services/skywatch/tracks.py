"""Retention of observed ADS-B positions.

Every prediction Atlas wants to make — arrival time, route inference, what will
be overhead next — needs history, and until now the watcher discarded each poll
as soon as it had evaluated notability. This records the observations and prunes
them on a retention window.
"""
from __future__ import annotations

import logging
from datetime import datetime, timedelta, timezone
from typing import Iterable

from sqlalchemy import delete, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.skywatch import AircraftTrack

logger = logging.getLogger(__name__)

# Matches aircraft_tracks.hex. Observations are written as one multi-row INSERT,
# so an over-long identifier used to discard the entire cycle rather than itself
# (migration 015). Guard the batch instead of trusting the feed.
MAX_HEX_LEN = 12


def cycle_timestamp(now: datetime | None = None) -> datetime:
    """Quantize to the poll interval so concurrent observers agree on `seen_at`.

    Two devices polling the same aircraft a few hundred milliseconds apart must
    produce the same `seen_at`, or the (hex, seen_at) unique constraint won't
    collapse them and the history gains duplicate points.
    """
    now = now or datetime.now(timezone.utc)
    step = max(1, settings.skywatch_poll_seconds)
    epoch = int(now.timestamp()) // step * step
    return datetime.fromtimestamp(epoch, tz=timezone.utc)


async def record_observations(
    session: AsyncSession,
    aircraft: Iterable,
    seen_at: datetime,
) -> int:
    """Persist one cycle's observations. Returns the number of new rows.

    Positions without a fix are skipped — a row with no lat/lon teaches nothing
    and would still occupy a slot in the (hex, seen_at) unique index.
    """
    rows = [
        {
            "hex": ac.hex,
            "seen_at": seen_at,
            "callsign": (ac.flight or None),
            "registration": ac.registration,
            "type": ac.type,
            "lat": ac.lat,
            "lng": ac.lon,
            "alt_baro": ac.alt_baro,
            "ground_speed": ac.ground_speed,
            "track_deg": ac.track,
            "squawk": ac.squawk,
            "is_military": bool(ac.is_military),
        }
        for ac in aircraft
        if ac.hex and len(ac.hex) <= MAX_HEX_LEN and ac.lat is not None and ac.lon is not None
    ]

    skipped = sum(
        1 for ac in aircraft if ac.hex and len(ac.hex) > MAX_HEX_LEN
    )
    if skipped:
        logger.warning(
            "Skipped %s observation(s) with an over-long hex identifier", skipped
        )
    if not rows:
        return 0

    # Deduplicate within the batch as well: one resolver response can merge a
    # local dump1090 feed with the network source and repeat a hex.
    deduped: dict[str, dict] = {}
    for row in rows:
        deduped[row["hex"]] = row

    stmt = pg_insert(AircraftTrack).values(list(deduped.values()))
    stmt = stmt.on_conflict_do_nothing(index_elements=["hex", "seen_at"])
    result = await session.execute(stmt)
    return result.rowcount or 0


async def prune_tracks(session: AsyncSession, now: datetime | None = None) -> int:
    """Delete observations older than the retention window. Returns rows removed."""
    now = now or datetime.now(timezone.utc)
    cutoff = now - timedelta(days=settings.skywatch_track_retention_days)
    result = await session.execute(
        delete(AircraftTrack).where(AircraftTrack.seen_at < cutoff)
    )
    await session.commit()
    removed = result.rowcount or 0
    if removed:
        logger.info(
            "Pruned %s aircraft_tracks rows older than %s days",
            removed,
            settings.skywatch_track_retention_days,
        )
    return removed


async def track_count(session: AsyncSession) -> int:
    result = await session.execute(select(func.count()).select_from(AircraftTrack))
    return int(result.scalar() or 0)
