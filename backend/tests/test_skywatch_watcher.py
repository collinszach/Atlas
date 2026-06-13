from datetime import datetime, timezone

from app.services.skywatch.watcher import _is_quiet_hours


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
