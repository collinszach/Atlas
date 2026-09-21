"""Overhead forecast: dead reckoning current tracks into the near future."""
from unittest.mock import MagicMock

import pytest

from app.services.adsb.geo import haversine_km, project_position
from app.services.adsb.models import Aircraft
from app.services.skywatch.forecast import (
    MIN_GROUND_SPEED_KTS,
    closest_approach,
    forecast_overhead,
)

# Observer sits at the origin of every scenario below.
OBS_LAT, OBS_LON = 40.0, -74.0


def _pref(radius_km=30, **kw):
    p = MagicMock()
    p.radius_km = radius_km
    p.alt_ceiling_ft = kw.get("alt_ceiling_ft")
    p.notable_types_enabled = kw.get("notable_types_enabled", True)
    p.military_enabled = kw.get("military_enabled", True)
    p.emergency_enabled = kw.get("emergency_enabled", True)
    p.watchlist_enabled = kw.get("watchlist_enabled", False)
    p.watchlist = kw.get("watchlist", [])
    return p


def _inbound(distance_km: float, speed_kts: float = 450.0, **kw) -> Aircraft:
    """An aircraft `distance_km` due north, tracking due south at the observer."""
    lat, lon = project_position(OBS_LAT, OBS_LON, 0.0, distance_km)
    return Aircraft(
        hex=kw.pop("hex", "abc123"),
        lat=lat,
        lon=lon,
        track=180.0,
        ground_speed=speed_kts,
        alt_baro=kw.pop("alt_baro", 30000),
        **kw,
    )


# --- closest approach ---------------------------------------------------

def test_inbound_aircraft_has_an_eta_and_near_zero_miss_distance():
    ac = _inbound(100.0)
    approach = closest_approach(ac, OBS_LAT, OBS_LON, horizon_seconds=3600)
    assert approach is not None
    # 100km at 450kt (~833 km/h) is a little over 7 minutes.
    assert 400 <= approach.eta_seconds <= 460
    assert approach.closest_distance_km < 5.0


def test_receding_aircraft_returns_none():
    """Its closest approach was in the past; forecasting it is meaningless."""
    ac = _inbound(100.0)
    ac.track = 0.0  # heading away, due north
    assert closest_approach(ac, OBS_LAT, OBS_LON, horizon_seconds=3600) is None


def test_offset_track_reports_the_miss_distance():
    """A target crossing nearby should report how close it actually gets."""
    lat, lon = project_position(OBS_LAT, OBS_LON, 0.0, 100.0)
    ac = Aircraft(hex="off001", lat=lat, lon=lon, track=170.0, ground_speed=450.0, alt_baro=30000)
    approach = closest_approach(ac, OBS_LAT, OBS_LON, horizon_seconds=3600)
    assert approach is not None
    assert 5.0 < approach.closest_distance_km < 40.0


def test_ground_traffic_is_not_projected():
    ac = _inbound(50.0, speed_kts=MIN_GROUND_SPEED_KTS - 1)
    assert closest_approach(ac, OBS_LAT, OBS_LON, horizon_seconds=3600) is None


def test_aircraft_without_a_track_is_not_projected():
    ac = _inbound(50.0)
    ac.track = None
    assert closest_approach(ac, OBS_LAT, OBS_LON, horizon_seconds=3600) is None


def test_horizon_bounds_the_eta():
    approach = closest_approach(_inbound(400.0), OBS_LAT, OBS_LON, horizon_seconds=600)
    # Too far to arrive within 10 minutes; nothing may be reported beyond it.
    assert approach is None or approach.eta_seconds <= 600


# --- forecast selection -------------------------------------------------

def test_military_inbound_is_forecast():
    ac = _inbound(100.0, hex="mil001", is_military=True)
    entries = forecast_overhead([ac], OBS_LAT, OBS_LON, _pref(), notable_only=True)
    assert [e.aircraft.hex for e in entries] == ["mil001"]
    assert entries[0].matches, "should carry the trigger that makes it notable"


def test_ordinary_airliner_is_filtered_when_notable_only():
    ac = _inbound(100.0, hex="ord001")
    assert forecast_overhead([ac], OBS_LAT, OBS_LON, _pref(), notable_only=True) == []


def test_ordinary_airliner_is_included_when_notable_only_is_off():
    ac = _inbound(100.0, hex="ord001")
    entries = forecast_overhead([ac], OBS_LAT, OBS_LON, _pref(), notable_only=False)
    assert [e.aircraft.hex for e in entries] == ["ord001"]


def test_aircraft_already_overhead_is_excluded():
    """The alert path covers these; repeating them buries the new information."""
    ac = _inbound(10.0, hex="here001", is_military=True)
    assert forecast_overhead([ac], OBS_LAT, OBS_LON, _pref(radius_km=30), notable_only=True) == []


def test_aircraft_that_will_miss_the_radius_is_excluded():
    lat, lon = project_position(OBS_LAT, OBS_LON, 0.0, 200.0)
    ac = Aircraft(hex="miss01", lat=lat, lon=lon, track=120.0, ground_speed=450.0,
                  alt_baro=30000, is_military=True)
    entries = forecast_overhead([ac], OBS_LAT, OBS_LON, _pref(radius_km=30), notable_only=True)
    for e in entries:
        assert e.approach.closest_distance_km <= 30


def test_results_are_ordered_by_eta():
    near = _inbound(60.0, hex="near01", is_military=True)
    far = _inbound(200.0, hex="far01", is_military=True)
    entries = forecast_overhead([far, near], OBS_LAT, OBS_LON, _pref(), notable_only=True)
    assert [e.aircraft.hex for e in entries] == ["near01", "far01"]
    assert entries[0].approach.eta_seconds < entries[1].approach.eta_seconds


def test_positionless_contact_is_skipped():
    ac = Aircraft(hex="nopos", lat=None, lon=None, track=180.0, ground_speed=450.0)
    assert forecast_overhead([ac], OBS_LAT, OBS_LON, _pref(), notable_only=False) == []


def test_projection_is_consistent_with_the_reported_eta():
    """The reported closest point must be where the aircraft actually reaches."""
    ac = _inbound(120.0, hex="chk001", is_military=True)
    entries = forecast_overhead([ac], OBS_LAT, OBS_LON, _pref(), notable_only=True)
    assert entries
    approach = entries[0].approach
    measured = haversine_km(OBS_LAT, OBS_LON, approach.closest_lat, approach.closest_lon)
    assert abs(measured - approach.closest_distance_km) < 0.01
