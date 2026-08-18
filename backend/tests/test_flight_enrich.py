"""Tests for flight enrichment services (adsbdb + planespotters) and stats extensions.

All external HTTP calls are mocked — no network access required.
"""
from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, MagicMock, patch


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_response(status_code: int, json_data: dict) -> MagicMock:
    resp = MagicMock()
    resp.status_code = status_code
    resp.json.return_value = json_data
    return resp


# ---------------------------------------------------------------------------
# flightroute service
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_route_success():
    """Happy path: adsbdb returns a valid flightroute."""
    from app.services import flightroute as fr_mod

    # Clear cache so this test is independent
    fr_mod._cache.clear()

    payload = {
        "response": {
            "flightroute": {
                "origin": {"iata_code": "JFK", "municipality": "New York", "icao_code": "KJFK", "name": "JFK"},
                "destination": {"iata_code": "LAX", "municipality": "Los Angeles", "icao_code": "KLAX", "name": "LAX"},
            }
        }
    }

    mock_resp = _make_response(200, payload)
    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    mock_client.get = AsyncMock(return_value=mock_resp)

    with patch("app.services.flightroute.httpx.AsyncClient", return_value=mock_client):
        result = await fr_mod.get_route("JBU1354")

    assert result is not None
    assert result.origin_iata == "JFK"
    assert result.origin_name == "New York"
    assert result.dest_iata == "LAX"
    assert result.dest_name == "Los Angeles"


@pytest.mark.asyncio
async def test_get_route_not_found():
    """adsbdb returns 404 → None, not an exception."""
    from app.services import flightroute as fr_mod
    fr_mod._cache.clear()

    mock_resp = _make_response(404, {})
    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    mock_client.get = AsyncMock(return_value=mock_resp)

    with patch("app.services.flightroute.httpx.AsyncClient", return_value=mock_client):
        result = await fr_mod.get_route("UNKNOWN999")

    assert result is None


@pytest.mark.asyncio
async def test_get_route_network_error():
    """Network exception → None, not propagated."""
    from app.services import flightroute as fr_mod
    fr_mod._cache.clear()

    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    mock_client.get = AsyncMock(side_effect=Exception("connection refused"))

    with patch("app.services.flightroute.httpx.AsyncClient", return_value=mock_client):
        result = await fr_mod.get_route("JBU1354")

    assert result is None


@pytest.mark.asyncio
async def test_get_route_cache_hit():
    """Second call with same callsign uses cache, no HTTP call."""
    from app.services import flightroute as fr_mod
    fr_mod._cache.clear()

    payload = {
        "response": {
            "flightroute": {
                "origin": {"iata_code": "BOS", "municipality": "Boston"},
                "destination": {"iata_code": "SFO", "municipality": "San Francisco"},
            }
        }
    }
    mock_resp = _make_response(200, payload)
    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    mock_client.get = AsyncMock(return_value=mock_resp)

    with patch("app.services.flightroute.httpx.AsyncClient", return_value=mock_client):
        r1 = await fr_mod.get_route("AAL100")
        r2 = await fr_mod.get_route("AAL100")  # should hit cache

    assert mock_client.get.call_count == 1
    assert r1 == r2


# ---------------------------------------------------------------------------
# aircraft_photos service
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_photo_by_hex_success():
    """Happy path: planespotters returns a photo."""
    from app.services import aircraft_photos as ph_mod
    ph_mod._cache.clear()

    payload = {
        "photos": [
            {
                "thumbnail_large": {"src": "https://cdn.planespotters.net/photo.jpg"},
                "link": "https://www.planespotters.net/photo/123",
                "photographer": "J. Doe",
            }
        ]
    }
    mock_resp = _make_response(200, payload)
    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    mock_client.get = AsyncMock(return_value=mock_resp)

    with patch("app.services.aircraft_photos.httpx.AsyncClient", return_value=mock_client):
        result = await ph_mod.get_photo_by_hex("ab6800")

    assert result is not None
    assert result.photo_url == "https://cdn.planespotters.net/photo.jpg"
    assert result.photographer == "J. Doe"


@pytest.mark.asyncio
async def test_get_photo_empty_photos():
    """Empty photos array → None."""
    from app.services import aircraft_photos as ph_mod
    ph_mod._cache.clear()

    mock_resp = _make_response(200, {"photos": []})
    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    mock_client.get = AsyncMock(return_value=mock_resp)

    with patch("app.services.aircraft_photos.httpx.AsyncClient", return_value=mock_client):
        result = await ph_mod.get_photo_by_hex("000000")

    assert result is None


@pytest.mark.asyncio
async def test_get_photo_network_error():
    """Network error → None."""
    from app.services import aircraft_photos as ph_mod
    ph_mod._cache.clear()

    mock_client = AsyncMock()
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=False)
    mock_client.get = AsyncMock(side_effect=Exception("timeout"))

    with patch("app.services.aircraft_photos.httpx.AsyncClient", return_value=mock_client):
        result = await ph_mod.get_photo_by_hex("ab6800")

    assert result is None


# ---------------------------------------------------------------------------
# /overhead still works when enrichment fails
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
@pytest.mark.integration
async def test_overhead_resilient_to_enrichment_failures(client, seed_test_users):
    """Overhead endpoint returns aircraft even when route/photo enrichment raises."""
    from app.main import app
    from app.auth import get_current_user_id
    from app.services.adsb.models import Aircraft
    from app.services import flightroute as fr_mod
    from app.services import aircraft_photos as ph_mod

    fr_mod._cache.clear()
    ph_mod._cache.clear()

    app.dependency_overrides[get_current_user_id] = lambda: "user_test_atlas_001"

    mock_aircraft = [
        Aircraft(
            hex="ab6800",
            flight="JBU1354",
            registration="N804JB",
            type="A320",
            lat=37.7749,
            lon=-122.4194,
            alt_baro=35000,
            ground_speed=480.0,
            track=270.0,
            squawk="1200",
            is_military=False,
            distance_km=5.0,
        )
    ]

    with (
        patch("app.routers.skywatch.DataSourceResolver") as MockResolver,
        patch("app.services.flightroute._fetch_route", side_effect=Exception("adsbdb down")),
        patch("app.services.aircraft_photos._fetch_photo", side_effect=Exception("planespotters down")),
    ):
        instance = MockResolver.return_value
        instance.has_local_source = False
        instance.get_aircraft = AsyncMock(return_value=mock_aircraft)

        resp = await client.get("/api/v1/skywatch/overhead?lat=37.7&lon=-122.4")

    app.dependency_overrides.pop(get_current_user_id, None)

    assert resp.status_code == 200
    body = resp.json()
    assert len(body["aircraft"]) == 1
    ac = body["aircraft"][0]
    assert ac["hex"] == "ab6800"
    assert ac["flight"] == "JBU1354"
    # Enrichment failed gracefully — fields are null
    assert ac["origin_iata"] is None
    assert ac["photo_url"] is None


# ---------------------------------------------------------------------------
# /stats new fields
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
@pytest.mark.integration
async def test_stats_new_fields_with_flight_legs(client, seed_test_users, db_session):
    """hours_in_air, top_airline, most_flown_airport are computed from flight legs."""
    import uuid
    from app.models.transport import TransportLeg
    from app.main import app
    from app.auth import get_current_user_id

    TEST_USER_ID = "user_test_atlas_001"
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID

    async with db_session as session:
        # Two JetBlue legs, one Delta leg
        leg1 = TransportLeg(
            user_id=TEST_USER_ID,
            flight_number="JBU100",
            origin_iata="JFK",
            dest_iata="LAX",
            duration_min=360,  # 6h
            distance_km=4000,
        )
        leg2 = TransportLeg(
            user_id=TEST_USER_ID,
            flight_number="JBU200",
            origin_iata="LAX",
            dest_iata="BOS",
            duration_min=300,  # 5h
            distance_km=4200,
        )
        leg3 = TransportLeg(
            user_id=TEST_USER_ID,
            flight_number="DAL50",
            origin_iata="JFK",
            dest_iata="ORD",
            duration_min=120,
            distance_km=1200,
        )
        session.add_all([leg1, leg2, leg3])
        await session.commit()

    resp = await client.get("/api/v1/stats")
    app.dependency_overrides.pop(get_current_user_id, None)

    assert resp.status_code == 200
    body = resp.json()

    # 360 + 300 + 120 = 780 min = 13.0 h
    assert body["hours_in_air"] == pytest.approx(13.0, abs=0.1)
    assert body["top_airline"] == "JetBlue Airways"
    # JFK appears 2× (leg1 origin + leg3 origin), LAX appears 2×
    assert body["most_flown_airport"] in {"JFK", "LAX"}


@pytest.mark.asyncio
@pytest.mark.integration
async def test_stats_hours_fallback_from_distance(client, seed_test_users, db_session):
    """When duration_min is null, fall back to distance_km / 800 km/h estimate."""
    from app.models.transport import TransportLeg
    from app.main import app
    from app.auth import get_current_user_id

    TEST_USER_ID = "user_test_atlas_001"
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID

    async with db_session as session:
        # 1600 km / 800 km·h⁻¹ = 2h
        leg = TransportLeg(
            user_id=TEST_USER_ID,
            flight_number="UAL999",
            origin_iata="SFO",
            dest_iata="SEA",
            duration_min=None,
            distance_km=1600,
        )
        session.add(leg)
        await session.commit()

    resp = await client.get("/api/v1/stats")
    app.dependency_overrides.pop(get_current_user_id, None)

    assert resp.status_code == 200
    body = resp.json()
    assert body["hours_in_air"] is not None
    assert body["hours_in_air"] >= 2.0  # at least the fallback estimate
