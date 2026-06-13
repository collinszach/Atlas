from __future__ import annotations

import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler

from app.config import settings
from app.database import async_session_factory
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
    scheduler.start()
    _scheduler = scheduler
    logger.info(
        "Skywatch scheduler started (every %ss)", settings.skywatch_poll_seconds
    )
    return scheduler


def shutdown_scheduler() -> None:
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
        logger.info("Skywatch scheduler stopped")
