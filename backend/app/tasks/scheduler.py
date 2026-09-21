from __future__ import annotations

import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler

from app.config import settings
from app.database import async_session_factory
from app.services.skywatch.apns import ApnsClient
from app.services.skywatch.collector import configured_sites, run_collection_cycle
from app.services.skywatch.tracks import prune_tracks
from app.services.skywatch.watcher import run_watch_cycle

logger = logging.getLogger(__name__)

_scheduler: AsyncIOScheduler | None = None


async def _skywatch_tick() -> None:
    """One scheduled Skywatch cycle. Opens its own session; never raises."""
    try:
        async with async_session_factory() as session:
            await run_watch_cycle(session)
    except Exception:
        logger.exception("Skywatch tick failed")


async def _prune_tracks_tick() -> None:
    """Nightly retention pass over aircraft_tracks. Never raises."""
    try:
        async with async_session_factory() as session:
            await prune_tracks(session)
    except Exception:
        logger.exception("Aircraft track prune failed")


async def _collect_tick() -> None:
    """One device-independent observation pass. Never raises."""
    try:
        async with async_session_factory() as session:
            await run_collection_cycle(session)
    except Exception:
        logger.exception("Aircraft collection tick failed")


def start_scheduler() -> AsyncIOScheduler:
    """Start the background scheduler (idempotent)."""
    global _scheduler
    if _scheduler is not None:
        return _scheduler

    scheduler = AsyncIOScheduler()
    scheduler.add_job(
        _skywatch_tick,
        trigger="interval",
        seconds=settings.skywatch_poll_seconds,
        id="skywatch_watch_cycle",
        max_instances=1,
        coalesce=True,
        replace_existing=True,
    )
    sites = configured_sites()
    if sites:
        scheduler.add_job(
            _collect_tick,
            trigger="interval",
            seconds=settings.skywatch_collect_seconds,
            id="aircraft_collection",
            max_instances=1,
            coalesce=True,
            replace_existing=True,
        )

    scheduler.add_job(
        _prune_tracks_tick,
        trigger="cron",
        hour=settings.skywatch_track_prune_hour,
        id="aircraft_track_prune",
        max_instances=1,
        coalesce=True,
        replace_existing=True,
    )
    scheduler.start()
    _scheduler = scheduler
    apns_state = "configured" if ApnsClient().is_configured else "NOT configured (push disabled)"
    logger.info(
        "Skywatch scheduler started (every %ss) — APNs %s; collection sites: %s",
        settings.skywatch_poll_seconds,
        apns_state,
        len(sites) or "none (history only accrues while a device reports)",
    )
    return scheduler


def shutdown_scheduler() -> None:
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
        logger.info("Skywatch scheduler stopped")
