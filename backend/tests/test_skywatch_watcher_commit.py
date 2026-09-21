"""The scheduler path must commit its own work.

`get_db()` commits for request-path writes, but `run_watch_cycle` runs under
APScheduler with a bare `async_session_factory()` context manager, which closes
without committing. Anything the watcher adds and only flushes is discarded.
"""
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.adsb.models import Aircraft


class _RecordingSession:
    """Minimal async-session stand-in that records the call order."""

    def __init__(self):
        self.calls: list[str] = []

    async def commit(self):
        self.calls.append("commit")

    async def rollback(self):
        self.calls.append("rollback")

    async def flush(self):
        self.calls.append("flush")

    def add(self, _obj):
        self.calls.append("add")


@pytest.mark.asyncio
async def test_observations_are_committed_even_when_nothing_fires(monkeypatch):
    """The quiet-sky path returns early — tracks must already be durable."""
    from app.services.skywatch import watcher

    session = _RecordingSession()
    recorded: dict = {}

    async def fake_record(sess, aircraft, seen_at):
        recorded["count"] = len(list(aircraft))
        return recorded["count"]

    monkeypatch.setattr(watcher, "record_observations", fake_record)
    monkeypatch.setattr(watcher, "evaluate_aircraft", lambda *a, **k: [])

    resolver = MagicMock()
    resolver.get_aircraft = AsyncMock(
        return_value=[Aircraft(hex="abc123", lat=37.7, lon=-122.4)]
    )

    device = MagicMock(id="d1", user_id="u1", last_lat=37.7, last_lng=-122.4, apns_token=None)
    preference = MagicMock(quiet_hours={}, radius_km=30, cooldown_minutes=60)

    await watcher._process_device(
        session, device, preference, {}, {}, resolver, MagicMock(),
        datetime(2026, 9, 20, 12, 0, tzinfo=timezone.utc),
    )

    assert recorded["count"] == 1
    assert "commit" in session.calls, (
        "observations were recorded but never committed — the scheduler's "
        "session closes without committing, so they would be discarded"
    )
