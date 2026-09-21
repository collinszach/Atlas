"""Device-independent collection of ADS-B history.

The watcher only recorded while a user's device reported a fresh location, so
the corpus stopped growing the moment the app was closed — 120 rows over one
16-minute window, then nothing for hours.
"""
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.services.adsb.airplanes_live import AdsbServiceError
from app.services.adsb.models import Aircraft
from app.services.skywatch.collector import parse_sites, run_collection_cycle


# --- site parsing -------------------------------------------------------

def test_parses_a_single_site():
    assert parse_sites("40.7128,-74.0060") == [(40.7128, -74.006)]


def test_parses_multiple_sites_and_tolerates_whitespace():
    assert parse_sites(" 40.7,-74.0 ; 37.87,-122.25 ") == [(40.7, -74.0), (37.87, -122.25)]


def test_empty_configuration_disables_collection():
    assert parse_sites("") == []
    assert parse_sites(None) == []
    assert parse_sites("   ") == []


@pytest.mark.parametrize("bad", ["40.7", "40.7,-74.0,12", "abc,def", "91.0,0.0", "0.0,181.0"])
def test_malformed_sites_are_skipped_not_fatal(bad):
    """One bad entry must not take the collector down."""
    assert parse_sites(bad) == []


def test_a_bad_site_does_not_discard_the_good_ones():
    assert parse_sites("40.7,-74.0; nonsense; 37.8,-122.4") == [(40.7, -74.0), (37.8, -122.4)]


# --- collection cycle ---------------------------------------------------

def _session():
    s = MagicMock()
    s.commit = AsyncMock()
    s.rollback = AsyncMock()
    return s


def _resolver(aircraft=None, error=None):
    r = MagicMock()
    r.get_aircraft = AsyncMock(side_effect=error) if error else AsyncMock(return_value=aircraft or [])
    return r


@pytest.mark.asyncio
async def test_no_sites_configured_is_a_no_op(monkeypatch):
    from app.services.skywatch import collector
    monkeypatch.setattr(collector.settings, "skywatch_collect_sites", "")
    resolver = _resolver([Aircraft(hex="a1", lat=1.0, lon=1.0)])
    assert await run_collection_cycle(_session(), resolver) == 0
    resolver.get_aircraft.assert_not_awaited()


@pytest.mark.asyncio
async def test_records_and_commits_each_site(monkeypatch):
    from app.services.skywatch import collector
    monkeypatch.setattr(collector.settings, "skywatch_collect_sites", "40.7,-74.0; 37.8,-122.4")
    monkeypatch.setattr(collector, "record_observations", AsyncMock(return_value=3))

    session = _session()
    resolver = _resolver([Aircraft(hex="a1", lat=1.0, lon=1.0)])
    written = await run_collection_cycle(session, resolver)

    assert written == 6  # two sites, three rows each
    assert resolver.get_aircraft.await_count == 2
    assert session.commit.await_count == 2


@pytest.mark.asyncio
async def test_one_unreachable_site_does_not_stop_the_others(monkeypatch):
    from app.services.skywatch import collector
    monkeypatch.setattr(collector.settings, "skywatch_collect_sites", "40.7,-74.0; 37.8,-122.4")
    monkeypatch.setattr(collector, "record_observations", AsyncMock(return_value=2))

    calls = {"n": 0}

    async def flaky(lat, lon, radius):
        calls["n"] += 1
        if calls["n"] == 1:
            raise AdsbServiceError("403 Forbidden")
        return [Aircraft(hex="a2", lat=2.0, lon=2.0)]

    resolver = MagicMock()
    resolver.get_aircraft = AsyncMock(side_effect=flaky)

    written = await run_collection_cycle(_session(), resolver)
    assert written == 2  # only the healthy site contributed


@pytest.mark.asyncio
async def test_all_sites_share_one_timestamp(monkeypatch):
    """Both sites must land on the same bucket so overlapping coverage dedupes."""
    from app.services.skywatch import collector
    monkeypatch.setattr(collector.settings, "skywatch_collect_sites", "40.7,-74.0; 40.8,-74.1")

    seen_ats = []

    async def capture(session, aircraft, seen_at):
        seen_ats.append(seen_at)
        return 1

    monkeypatch.setattr(collector, "record_observations", capture)
    await run_collection_cycle(_session(), _resolver([Aircraft(hex="a1", lat=1.0, lon=1.0)]))
    assert len(seen_ats) == 2
    assert seen_ats[0] == seen_ats[1]


@pytest.mark.asyncio
async def test_uses_the_track_radius_not_any_alert_radius(monkeypatch):
    from app.services.skywatch import collector
    monkeypatch.setattr(collector.settings, "skywatch_collect_sites", "40.7,-74.0")
    monkeypatch.setattr(collector.settings, "skywatch_track_radius_km", 120.0)
    monkeypatch.setattr(collector, "record_observations", AsyncMock(return_value=1))

    resolver = _resolver([Aircraft(hex="a1", lat=1.0, lon=1.0)])
    await run_collection_cycle(_session(), resolver)
    assert resolver.get_aircraft.await_args.args[2] == 120.0
