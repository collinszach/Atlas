from unittest.mock import AsyncMock, patch

import pytest

from app.models.skywatch import SkywatchPreference
from app.services.adsb.models import Aircraft
from app.services.llm import LocalLLMError
from app.services.skywatch.copy import alert_copy
from app.services.skywatch.nl_prefs import compile_preferences
from app.services.skywatch.rules import Match


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
        type="AN124",
        lat=37.8,
        lon=-122.4,
        alt_baro=31000,
        ground_speed=450.0,
        track=10.0,
        squawk="1200",
        is_military=False,
        distance_km=8.0,
    )
    defaults.update(overrides)
    return Aircraft(**defaults)


# --- compile_preferences ---

@pytest.mark.asyncio
async def test_compile_preferences_maps_fields_and_clamps_radius():
    preference = make_preference()
    llm_response = {
        "rare_types": True,
        "military": True,
        "emergencies": False,
        "radius_km": 999,  # over max, should clamp to 250
        "watchlist": [{"kind": "airline", "value": "Antonov Airlines"}],
    }

    with patch(
        "app.services.skywatch.nl_prefs.OllamaClient.chat_json",
        new=AsyncMock(return_value=llm_response),
    ):
        updates = await compile_preferences("alert me for anything old or military", preference)

    assert updates["notable_types_enabled"] is True
    assert updates["military_enabled"] is True
    assert updates["emergency_enabled"] is False
    assert updates["radius_km"] == 250
    assert updates["watchlist"] == [{"kind": "airline", "value": "Antonov Airlines"}]
    assert updates["watchlist_enabled"] is True


@pytest.mark.asyncio
async def test_compile_preferences_clamps_radius_below_minimum():
    preference = make_preference(radius_km=30)
    llm_response = {"rare_types": False, "military": False, "emergencies": True, "radius_km": 1}

    with patch(
        "app.services.skywatch.nl_prefs.OllamaClient.chat_json",
        new=AsyncMock(return_value=llm_response),
    ):
        updates = await compile_preferences("alert me if anything is in trouble nearby", preference)

    assert updates["radius_km"] == 5
    assert updates["emergency_enabled"] is True


@pytest.mark.asyncio
async def test_compile_preferences_raises_on_llm_error():
    preference = make_preference()

    with patch(
        "app.services.skywatch.nl_prefs.OllamaClient.chat_json",
        new=AsyncMock(side_effect=LocalLLMError("unreachable")),
    ):
        with pytest.raises(LocalLLMError):
            await compile_preferences("anything", preference)


@pytest.mark.asyncio
async def test_compile_preferences_raises_on_junk_output():
    preference = make_preference()

    with patch(
        "app.services.skywatch.nl_prefs.OllamaClient.chat_json",
        new=AsyncMock(return_value={"unexpected": "garbage"}),
    ):
        with pytest.raises(LocalLLMError):
            await compile_preferences("anything", preference)


@pytest.mark.asyncio
async def test_compile_preferences_non_object_output_raises():
    preference = make_preference()

    with patch(
        "app.services.skywatch.nl_prefs.OllamaClient.chat_json",
        new=AsyncMock(return_value=["not", "a", "dict"]),
    ):
        with pytest.raises(LocalLLMError):
            await compile_preferences("anything", preference)


# --- alert_copy ---

@pytest.mark.asyncio
async def test_alert_copy_returns_none_when_disabled():
    aircraft = make_aircraft()
    match = Match(trigger="notable_type", score=8, message="A rare type is overhead.")

    with patch("app.services.skywatch.copy.is_enabled", return_value=False):
        result = await alert_copy(aircraft, match)

    assert result is None


@pytest.mark.asyncio
async def test_alert_copy_returns_title_and_body_when_enabled():
    aircraft = make_aircraft()
    match = Match(trigger="notable_type", score=8, message="An Antonov An-124 is overhead.")
    llm_response = {"title": "Antonov An-124 overhead", "body": "Soviet-era heavy freighter · 8 km north · FL310"}

    with patch("app.services.skywatch.copy.is_enabled", return_value=True), patch(
        "app.services.skywatch.copy.OllamaClient.chat_json",
        new=AsyncMock(return_value=llm_response),
    ):
        result = await alert_copy(aircraft, match)

    assert result == ("Antonov An-124 overhead", "Soviet-era heavy freighter · 8 km north · FL310")


@pytest.mark.asyncio
async def test_alert_copy_returns_none_on_llm_error():
    aircraft = make_aircraft()
    match = Match(trigger="military", score=7, message="A military aircraft is overhead.")

    with patch("app.services.skywatch.copy.is_enabled", return_value=True), patch(
        "app.services.skywatch.copy.OllamaClient.chat_json",
        new=AsyncMock(side_effect=LocalLLMError("timeout")),
    ):
        result = await alert_copy(aircraft, match)

    assert result is None


@pytest.mark.asyncio
async def test_alert_copy_returns_none_on_malformed_output():
    aircraft = make_aircraft()
    match = Match(trigger="military", score=7, message="A military aircraft is overhead.")

    with patch("app.services.skywatch.copy.is_enabled", return_value=True), patch(
        "app.services.skywatch.copy.OllamaClient.chat_json",
        new=AsyncMock(return_value={"title": "Only a title"}),
    ):
        result = await alert_copy(aircraft, match)

    assert result is None


# --- /skywatch/preferences/from-text endpoint ---

@pytest.mark.asyncio
async def test_from_text_endpoint_persists_preferences(auth_client):
    llm_response = {
        "rare_types": True,
        "military": False,
        "emergencies": True,
        "radius_km": 50,
        "watchlist": [],
    }

    with patch(
        "app.services.skywatch.nl_prefs.OllamaClient.chat_json",
        new=AsyncMock(return_value=llm_response),
    ):
        resp = await auth_client.post(
            "/api/v1/skywatch/preferences/from-text",
            json={"text": "alert me for anything old or in trouble within 50km"},
        )

    assert resp.status_code == 200
    body = resp.json()
    assert body["notable_types_enabled"] is True
    assert body["emergency_enabled"] is True
    assert float(body["radius_km"]) == 50.0
    assert body["nl_prompt"] == "alert me for anything old or in trouble within 50km"


@pytest.mark.asyncio
async def test_from_text_endpoint_maps_llm_error_to_503(auth_client):
    with patch(
        "app.services.skywatch.nl_prefs.OllamaClient.chat_json",
        new=AsyncMock(side_effect=LocalLLMError("unreachable")),
    ):
        resp = await auth_client.post(
            "/api/v1/skywatch/preferences/from-text",
            json={"text": "alert me for anything interesting"},
        )

    assert resp.status_code == 503


@pytest.mark.asyncio
async def test_from_text_endpoint_rejects_empty_text(auth_client):
    resp = await auth_client.post(
        "/api/v1/skywatch/preferences/from-text",
        json={"text": "   "},
    )
    assert resp.status_code == 422
