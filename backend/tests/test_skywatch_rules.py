import pytest

from app.models.skywatch import MilCallsignPrefix, NotableType, SkywatchPreference
from app.services.adsb.models import Aircraft
from app.services.skywatch.rules import evaluate_aircraft

LAT, LON = 37.7749, -122.4194  # San Francisco

NOTABLE_TYPES = {
    "A388": NotableType(type_code="A388", description="Airbus A380-800", rarity_tier=2),
    "AN12": NotableType(type_code="AN12", description="Antonov An-12", rarity_tier=1),
}

MIL_PREFIXES = {
    "RCH": MilCallsignPrefix(prefix="RCH", description="USAF Air Mobility Command"),
    "RRR": MilCallsignPrefix(prefix="RRR", description="RAF"),
}


def make_preference(**overrides) -> SkywatchPreference:
    defaults = dict(
        user_id="user_test_atlas_001",
        notable_types_enabled=True,
        military_enabled=True,
        emergency_enabled=True,
        watchlist_enabled=False,
        radius_km=30,
        alt_ceiling_ft=None,
        cooldown_minutes=360,
        quiet_hours={},
        watchlist=[],
        nl_prompt=None,
    )
    defaults.update(overrides)
    return SkywatchPreference(**defaults)


def make_aircraft(**overrides) -> Aircraft:
    defaults = dict(
        hex="a1b2c3",
        flight="UAL123",
        registration="N12345",
        type="B738",
        lat=LAT + 0.05,  # ~5.5km away
        lon=LON,
        alt_baro=30000,
        ground_speed=450.0,
        track=270.0,
        squawk="1200",
        is_military=False,
    )
    defaults.update(overrides)
    return Aircraft(**defaults)


# --- Rare / unusual types ---

def test_notable_type_triggers():
    preference = make_preference()
    aircraft = make_aircraft(type="A388")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    triggers = [m.trigger for m in matches]
    assert "notable_type" in triggers
    notable_match = next(m for m in matches if m.trigger == "notable_type")
    assert "A380" in notable_match.message
    assert notable_match.score > 0


def test_notable_type_not_in_table_no_match():
    preference = make_preference()
    aircraft = make_aircraft(type="B738")  # not notable
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert all(m.trigger != "notable_type" for m in matches)


def test_notable_type_disabled_flag():
    preference = make_preference(notable_types_enabled=False)
    aircraft = make_aircraft(type="A388")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert all(m.trigger != "notable_type" for m in matches)


def test_rarer_type_scores_higher():
    preference = make_preference()
    a388 = make_aircraft(type="A388")  # rarity tier 2
    an12 = make_aircraft(type="AN12")  # rarity tier 1 (rarer)
    score_a388 = next(m.score for m in evaluate_aircraft(a388, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES) if m.trigger == "notable_type")
    score_an12 = next(m.score for m in evaluate_aircraft(an12, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES) if m.trigger == "notable_type")
    assert score_an12 > score_a388


# --- Military & government ---

def test_military_dbflags_triggers():
    preference = make_preference()
    aircraft = make_aircraft(is_military=True, type="C17")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert any(m.trigger == "military" for m in matches)


def test_military_callsign_prefix_triggers():
    preference = make_preference()
    aircraft = make_aircraft(is_military=False, flight="RCH456  ", type="C17")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    mil_match = next((m for m in matches if m.trigger == "military"), None)
    assert mil_match is not None
    assert "RCH456" in mil_match.message


def test_government_registration_triggers():
    preference = make_preference()
    aircraft = make_aircraft(is_military=False, flight=None, registration="VC-25A")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert any(m.trigger == "military" for m in matches)


def test_civilian_no_military_match():
    preference = make_preference()
    aircraft = make_aircraft(is_military=False, flight="UAL123", registration="N12345")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert all(m.trigger != "military" for m in matches)


def test_military_disabled_flag():
    preference = make_preference(military_enabled=False)
    aircraft = make_aircraft(is_military=True)
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert all(m.trigger != "military" for m in matches)


# --- Emergencies & oddities ---

@pytest.mark.parametrize("squawk", ["7700", "7600", "7500"])
def test_emergency_squawk_triggers(squawk):
    preference = make_preference()
    aircraft = make_aircraft(squawk=squawk)
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    emergency_match = next((m for m in matches if m.trigger == "emergency"), None)
    assert emergency_match is not None
    assert emergency_match.score == 10


def test_normal_squawk_no_emergency():
    preference = make_preference()
    aircraft = make_aircraft(squawk="1200")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert all(m.trigger != "emergency" for m in matches)


def test_low_altitude_triggers_emergency_heuristic():
    preference = make_preference()
    aircraft = make_aircraft(squawk="1200", alt_baro=200)
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert any(m.trigger == "emergency" for m in matches)


def test_ground_altitude_does_not_trigger_emergency():
    preference = make_preference()
    aircraft = make_aircraft(squawk="1200", alt_baro=0)
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert all(m.trigger != "emergency" for m in matches)


def test_emergency_disabled_flag():
    preference = make_preference(emergency_enabled=False)
    aircraft = make_aircraft(squawk="7700")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert all(m.trigger != "emergency" for m in matches)


# --- Radius & altitude ceiling ---

def test_outside_radius_no_matches():
    preference = make_preference(radius_km=1)  # 1km, aircraft ~5.5km away
    aircraft = make_aircraft(type="A388", is_military=True, squawk="7700")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert matches == []


def test_within_radius_matches():
    preference = make_preference(radius_km=10)  # aircraft ~5.5km away
    aircraft = make_aircraft(type="A388")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert len(matches) >= 1


def test_above_altitude_ceiling_no_matches():
    preference = make_preference(alt_ceiling_ft=10000)
    aircraft = make_aircraft(type="A388", alt_baro=35000)
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert matches == []


def test_within_altitude_ceiling_matches():
    preference = make_preference(alt_ceiling_ft=10000)
    aircraft = make_aircraft(type="A388", alt_baro=8000)
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert len(matches) >= 1


def test_no_ceiling_means_unbounded():
    preference = make_preference(alt_ceiling_ft=None)
    aircraft = make_aircraft(type="A388", alt_baro=40000)
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert len(matches) >= 1


def test_outside_radius_when_distance_km_unset_falls_back_to_haversine():
    preference = make_preference(radius_km=10)
    aircraft = make_aircraft(type="A388", lat=LAT + 0.05, lon=LON, distance_km=None)
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert len(matches) >= 1


def test_no_position_data_excluded():
    preference = make_preference(radius_km=30)
    aircraft = make_aircraft(type="A388", lat=None, lon=None, distance_km=None)
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert matches == []


# --- Watchlist (default-off but functional) ---

def test_watchlist_disabled_by_default():
    preference = make_preference()
    aircraft = make_aircraft(hex="cafe01")
    assert preference.watchlist_enabled is False
    matches = evaluate_aircraft(
        aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES,
    )
    assert all(m.trigger != "watchlist" for m in matches)


def test_watchlist_matches_by_hex_when_enabled():
    preference = make_preference(
        watchlist_enabled=True,
        watchlist=[{"hex": "cafe01", "label": "My favorite jet"}],
    )
    aircraft = make_aircraft(hex="cafe01", type="B738")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    watch_match = next((m for m in matches if m.trigger == "watchlist"), None)
    assert watch_match is not None
    assert "My favorite jet" in watch_match.message


def test_watchlist_matches_by_registration():
    preference = make_preference(
        watchlist_enabled=True,
        watchlist=[{"registration": "N12345", "label": "Tail N12345"}],
    )
    aircraft = make_aircraft(registration="N12345")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert any(m.trigger == "watchlist" for m in matches)


def test_watchlist_no_match_when_not_listed():
    preference = make_preference(
        watchlist_enabled=True,
        watchlist=[{"hex": "ffffff", "label": "Not this one"}],
    )
    aircraft = make_aircraft(hex="cafe01")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    assert all(m.trigger != "watchlist" for m in matches)


# --- Multiple triggers ---

def test_multiple_triggers_can_fire_simultaneously():
    preference = make_preference()
    aircraft = make_aircraft(type="A388", is_military=True, squawk="7700")
    matches = evaluate_aircraft(aircraft, LAT, LON, preference, NOTABLE_TYPES, MIL_PREFIXES)
    triggers = {m.trigger for m in matches}
    assert {"notable_type", "military", "emergency"}.issubset(triggers)
