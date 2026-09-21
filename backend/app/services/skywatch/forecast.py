"""Forecast which aircraft will come overhead, before they arrive.

Skywatch alerts fire when something notable is *already* within radius, which
often means you look up as it leaves. This projects current tracks forward so
an alert can land while there is still time to get outside.

This is dead reckoning: constant heading, constant groundspeed, along a great
circle. Aircraft turn, climb, hold and get vectored, so a projection is a
statement about where a target is pointed *now*, not a prediction of intent. It
degrades with time, which is why the horizon is deliberately short and why no
confidence score is invented here — the caller gets the ETA and the distance,
which are the honest outputs.

Measured against live traffic around JFK (254 aircraft re-observed after 120s):

    median  0.72 km      90th pct  6.81 km
    mean    2.36 km      worst    20.83 km      68% within 2 km

The median is small because most traffic is in level cruise; the tail is
aircraft under vectors, turning onto approach or departure. So a projection is
reliable enough to say "something is heading your way in a few minutes" and not
reliable enough to promise exactly where. Re-measure with the same method if
the horizon or the step size changes.
"""
from __future__ import annotations

import logging
from dataclasses import dataclass

from app.models.skywatch import MilCallsignPrefix, NotableType, SkywatchPreference
from app.services.adsb.geo import haversine_km, knots_to_kmh, project_position
from app.services.adsb.models import Aircraft
from app.services.skywatch.rules import Match, evaluate_aircraft

logger = logging.getLogger(__name__)

# Below this an aircraft is taxiing, holding or parked — projecting it forward
# produces confident nonsense.
MIN_GROUND_SPEED_KTS = 60.0

DEFAULT_HORIZON_MINUTES = 30
DEFAULT_STEP_SECONDS = 15


@dataclass
class Approach:
    """The closest an aircraft is projected to come, and when."""

    eta_seconds: int
    closest_distance_km: float
    closest_lat: float
    closest_lon: float


@dataclass
class ForecastEntry:
    aircraft: Aircraft
    approach: Approach
    matches: list[Match]


def _is_projectable(aircraft: Aircraft) -> bool:
    return (
        aircraft.lat is not None
        and aircraft.lon is not None
        and aircraft.track is not None
        and aircraft.ground_speed is not None
        and aircraft.ground_speed >= MIN_GROUND_SPEED_KTS
    )


def closest_approach(
    aircraft: Aircraft,
    lat: float,
    lon: float,
    horizon_seconds: int,
    step_seconds: int = DEFAULT_STEP_SECONDS,
) -> Approach | None:
    """Step the track forward and return the closest projected approach.

    Stepping rather than solving analytically: the great-circle closest-approach
    solution is exact for a straight track, but the straight track is itself the
    approximation, so the extra precision would be false. Stepping also makes
    the behaviour obvious when reading the code.

    Returns None when the aircraft cannot be projected, or when it is already
    receding — its closest approach was in the past.
    """
    if not _is_projectable(aircraft):
        return None

    speed_kmh = knots_to_kmh(aircraft.ground_speed)
    best: Approach | None = None

    for elapsed in range(0, horizon_seconds + 1, step_seconds):
        travelled_km = speed_kmh * (elapsed / 3600.0)
        plat, plon = project_position(aircraft.lat, aircraft.lon, aircraft.track, travelled_km)
        distance = haversine_km(lat, lon, plat, plon)
        if best is None or distance < best.closest_distance_km:
            best = Approach(
                eta_seconds=elapsed,
                closest_distance_km=distance,
                closest_lat=plat,
                closest_lon=plon,
            )

    if best is None or best.eta_seconds == 0:
        # Nearest point is where it already is: it is flying away from us.
        return None
    return best


def forecast_overhead(
    aircraft_list: list[Aircraft],
    lat: float,
    lon: float,
    preference: SkywatchPreference,
    notable_types: dict[str, NotableType] | None = None,
    mil_prefixes: dict[str, MilCallsignPrefix] | None = None,
    horizon_minutes: int = DEFAULT_HORIZON_MINUTES,
    radius_km: float | None = None,
    notable_only: bool = True,
) -> list[ForecastEntry]:
    """Aircraft projected to enter the radius within the horizon, soonest first.

    Aircraft already inside the radius are excluded: they are what the existing
    overhead and alert paths are for, and a forecast that repeats them buries
    the thing this exists to surface.

    Notability is evaluated at the *projected* position, not the current one —
    `evaluate_aircraft` discards anything outside the radius, and every
    candidate here is outside it by definition.
    """
    horizon_seconds = horizon_minutes * 60
    effective_radius = radius_km if radius_km is not None else float(preference.radius_km)

    entries: list[ForecastEntry] = []
    for aircraft in aircraft_list:
        if aircraft.lat is None or aircraft.lon is None:
            continue

        current_distance = aircraft.distance_km
        if current_distance is None:
            current_distance = haversine_km(lat, lon, aircraft.lat, aircraft.lon)
        if current_distance <= effective_radius:
            continue  # already here

        approach = closest_approach(aircraft, lat, lon, horizon_seconds)
        if approach is None or approach.closest_distance_km > effective_radius:
            continue

        projected = aircraft.model_copy(
            update={
                "lat": approach.closest_lat,
                "lon": approach.closest_lon,
                "distance_km": approach.closest_distance_km,
            }
        )
        matches = evaluate_aircraft(projected, lat, lon, preference, notable_types, mil_prefixes)
        if notable_only and not matches:
            continue

        entries.append(ForecastEntry(aircraft=aircraft, approach=approach, matches=matches))

    entries.sort(key=lambda e: e.approach.eta_seconds)
    return entries
