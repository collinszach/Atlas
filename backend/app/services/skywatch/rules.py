from __future__ import annotations
from dataclasses import dataclass

from app.models.skywatch import MilCallsignPrefix, NotableType, SkywatchPreference
from app.services.adsb.geo import haversine_km
from app.services.adsb.models import Aircraft
from app.services.skywatch.airlines import is_commercial_airline, resolve_airline

EMERGENCY_SQUAWKS = {"7700": "general emergency", "7600": "radio failure", "7500": "hijack"}

LOW_ALTITUDE_FT = 500

# Government / VIP registration prefixes not covered by the military dbFlags bit
# (e.g. head-of-state and government transport aircraft).
GOV_REGISTRATION_PREFIXES: tuple[str, ...] = (
    "VC-", "VH-VIP", "VP-C", "VP-B", "HZ-HM", "HZ-WBG", "A6-HRS",
)


@dataclass
class Match:
    trigger: str
    score: int
    message: str


def _within_radius(aircraft: Aircraft, lat: float, lon: float, radius_km: float) -> bool:
    distance = aircraft.distance_km
    if distance is None:
        if aircraft.lat is None or aircraft.lon is None:
            return False
        distance = haversine_km(lat, lon, aircraft.lat, aircraft.lon)
    return distance <= radius_km


def _within_ceiling(aircraft: Aircraft, alt_ceiling_ft: int | None) -> bool:
    if alt_ceiling_ft is None:
        return True
    if aircraft.alt_baro is None:
        return True
    return aircraft.alt_baro <= alt_ceiling_ft


def _check_notable_types(aircraft: Aircraft, notable_types: dict[str, NotableType]) -> Match | None:
    if not aircraft.type:
        return None
    notable = notable_types.get(aircraft.type.upper())
    if notable is None:
        return None
    score = max(1, 10 - notable.rarity_tier)
    return Match(
        trigger="notable_type",
        score=score,
        message=f"A {notable.description} ({aircraft.type}) is overhead.",
    )


def _check_military(
    aircraft: Aircraft,
    mil_prefixes: dict[str, MilCallsignPrefix],
) -> Match | None:
    # A scheduled commercial flight (known airline callsign) is never military —
    # guards against noisy dbFlags / prefix collisions on airline callsigns.
    if is_commercial_airline(aircraft.flight):
        return None

    if aircraft.is_military:
        return Match(
            trigger="military",
            score=7,
            message=f"A military aircraft ({aircraft.type or 'unknown type'}) is overhead.",
        )

    if aircraft.flight:
        callsign = aircraft.flight.upper()
        for prefix, info in mil_prefixes.items():
            if callsign.startswith(prefix.upper()):
                return Match(
                    trigger="military",
                    score=7,
                    message=f"A military flight ({info.description}, callsign {aircraft.flight.strip()}) is overhead.",
                )

    if aircraft.registration:
        reg = aircraft.registration.upper()
        for prefix in GOV_REGISTRATION_PREFIXES:
            if reg.startswith(prefix.upper()):
                return Match(
                    trigger="military",
                    score=8,
                    message=f"A government/VIP aircraft ({aircraft.registration}) is overhead.",
                )

    return None


def _check_emergency(aircraft: Aircraft) -> Match | None:
    if aircraft.squawk in EMERGENCY_SQUAWKS:
        description = EMERGENCY_SQUAWKS[aircraft.squawk]
        return Match(
            trigger="emergency",
            score=10,
            message=f"Aircraft {aircraft.flight or aircraft.hex} is squawking {aircraft.squawk} ({description}).",
        )

    if aircraft.alt_baro is not None and 0 < aircraft.alt_baro <= LOW_ALTITUDE_FT:
        return Match(
            trigger="emergency",
            score=6,
            message=f"Aircraft {aircraft.flight or aircraft.hex} is at an unusually low altitude ({aircraft.alt_baro} ft).",
        )

    return None


def _check_watchlist(aircraft: Aircraft, watchlist: list[dict]) -> Match | None:
    for entry in watchlist:
        hex_match = entry.get("hex") and entry["hex"].lower() == aircraft.hex.lower()
        reg_match = (
            entry.get("registration")
            and aircraft.registration
            and entry["registration"].upper() == aircraft.registration.upper()
        )
        type_match = (
            entry.get("type")
            and aircraft.type
            and entry["type"].upper() == aircraft.type.upper()
        )
        flight_match = (
            entry.get("flight")
            and aircraft.flight
            and entry["flight"].upper() == aircraft.flight.upper().strip()
        )
        if hex_match or reg_match or type_match or flight_match:
            label = entry.get("label", aircraft.flight or aircraft.hex)
            return Match(
                trigger="watchlist",
                score=5,
                message=f"Watchlist match: {label} is overhead.",
            )
    return None


def evaluate_aircraft(
    aircraft: Aircraft,
    lat: float,
    lon: float,
    preference: SkywatchPreference,
    notable_types: dict[str, NotableType] | None = None,
    mil_prefixes: dict[str, MilCallsignPrefix] | None = None,
) -> list[Match]:
    """Evaluate an aircraft against a user's Skywatch preferences.

    `notable_types` and `mil_prefixes` should be keyed by `type_code` and
    `prefix` respectively (both uppercase). Returns a list of triggered
    matches; empty if nothing fires or the aircraft is outside radius/ceiling.
    """
    radius_km = float(preference.radius_km)
    if not _within_radius(aircraft, lat, lon, radius_km):
        return []
    if not _within_ceiling(aircraft, preference.alt_ceiling_ft):
        return []

    matches: list[Match] = []

    if preference.notable_types_enabled:
        match = _check_notable_types(aircraft, notable_types or {})
        if match:
            matches.append(match)

    if preference.military_enabled:
        match = _check_military(aircraft, mil_prefixes or {})
        if match:
            matches.append(match)

    if preference.emergency_enabled:
        match = _check_emergency(aircraft)
        if match:
            matches.append(match)

    if preference.watchlist_enabled:
        match = _check_watchlist(aircraft, preference.watchlist or [])
        if match:
            matches.append(match)

    return matches
