from datetime import datetime, timezone

from app.services.adsb.models import Aircraft
from app.services.skywatch import watcher as watcher_mod
from app.services.skywatch.rules import Match
from app.services.skywatch.watcher import _build_payload, _is_quiet_hours


def _utc(h, m=0):
    return datetime(2026, 6, 13, h, m, tzinfo=timezone.utc)


def test_no_quiet_hours_config_never_suppresses():
    assert _is_quiet_hours({}, _utc(3)) is False
    assert _is_quiet_hours({"start": "22:00"}, _utc(23)) is False  # missing end


def test_daytime_window():
    qh = {"start": "09:00", "end": "17:00", "timezone": "UTC"}
    assert _is_quiet_hours(qh, _utc(12)) is True
    assert _is_quiet_hours(qh, _utc(8)) is False
    assert _is_quiet_hours(qh, _utc(18)) is False


def test_overnight_window_wraps_midnight():
    qh = {"start": "22:00", "end": "07:00", "timezone": "UTC"}
    assert _is_quiet_hours(qh, _utc(23)) is True
    assert _is_quiet_hours(qh, _utc(3)) is True
    assert _is_quiet_hours(qh, _utc(12)) is False


def test_malformed_config_does_not_suppress():
    assert _is_quiet_hours({"start": "nope", "end": "07:00"}, _utc(3)) is False
    assert _is_quiet_hours({"start": "22:00", "end": "07:00", "timezone": "Bad/Zone"}, _utc(3)) is True


async def test_payload_carries_position_for_deep_link(monkeypatch):
    monkeypatch.setattr(watcher_mod, "is_enabled", lambda: False)
    aircraft = Aircraft(hex="abc123", type="F16", lat=47.6, lon=-122.3)
    match = Match(trigger="military", score=10, message="Military aircraft overhead")

    payload = await _build_payload(aircraft, match)

    assert payload["hex"] == "abc123"
    assert payload["trigger"] == "military"
    assert payload["lat"] == 47.6
    assert payload["lon"] == -122.3
    assert "alert" in payload["aps"]


async def test_payload_omits_position_when_unknown(monkeypatch):
    monkeypatch.setattr(watcher_mod, "is_enabled", lambda: False)
    aircraft = Aircraft(hex="def456", lat=None, lon=None)
    match = Match(trigger="emergency", score=20, message="Squawking 7700")

    payload = await _build_payload(aircraft, match)

    assert "lat" not in payload
    assert "lon" not in payload
