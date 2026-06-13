import pytest
from unittest.mock import patch

from app.services.adsb.models import Aircraft

TEST_USER_ID = "user_test_atlas_001"
OTHER_USER_ID = "user_test_other_002"


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


@pytest.mark.asyncio
async def test_skywatch_endpoints_require_auth(client):
    assert (await client.post("/api/v1/skywatch/devices", json={})).status_code == 401
    assert (await client.get("/api/v1/skywatch/preferences")).status_code == 401
    assert (await client.get("/api/v1/skywatch/overhead?lat=37.7&lon=-122.4")).status_code == 401
    assert (await client.get("/api/v1/skywatch/alerts")).status_code == 401


@pytest.mark.asyncio
@pytest.mark.integration
async def test_register_device(authed_client):
    resp = await authed_client.post(
        "/api/v1/skywatch/devices",
        json={"apns_token": "abc123", "platform": "ios", "push_enabled": True},
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["apns_token"] == "abc123"
    assert body["platform"] == "ios"
    assert body["push_enabled"] is True


@pytest.mark.asyncio
@pytest.mark.integration
async def test_update_location_without_device_requires_registration(authed_client):
    resp = await authed_client.post(
        "/api/v1/skywatch/location",
        json={"lat": 37.7749, "lng": -122.4194},
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
@pytest.mark.integration
async def test_update_location_after_device_registration(authed_client):
    register_resp = await authed_client.post(
        "/api/v1/skywatch/devices",
        json={"platform": "ios"},
    )
    device_id = register_resp.json()["id"]

    resp = await authed_client.post(
        "/api/v1/skywatch/location",
        json={"device_id": device_id, "lat": 37.7749, "lng": -122.4194},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert float(body["last_lat"]) == pytest.approx(37.7749)
    assert float(body["last_lng"]) == pytest.approx(-122.4194)
    assert body["last_seen"] is not None


@pytest.mark.asyncio
@pytest.mark.integration
async def test_invalid_location_rejected(authed_client):
    resp = await authed_client.post(
        "/api/v1/skywatch/location",
        json={"lat": 999, "lng": -122.4194},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
@pytest.mark.integration
async def test_get_preferences_creates_defaults(authed_client):
    resp = await authed_client.get("/api/v1/skywatch/preferences")
    assert resp.status_code == 200
    body = resp.json()
    assert body["notable_types_enabled"] is True
    assert body["military_enabled"] is True
    assert body["emergency_enabled"] is True
    assert body["watchlist_enabled"] is False
    assert float(body["radius_km"]) == pytest.approx(30.0)


@pytest.mark.asyncio
@pytest.mark.integration
async def test_update_preferences(authed_client):
    resp = await authed_client.put(
        "/api/v1/skywatch/preferences",
        json={"radius_km": 50, "alt_ceiling_ft": 10000, "military_enabled": False},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert float(body["radius_km"]) == pytest.approx(50.0)
    assert body["alt_ceiling_ft"] == 10000
    assert body["military_enabled"] is False

    # Persisted across requests
    get_resp = await authed_client.get("/api/v1/skywatch/preferences")
    assert float(get_resp.json()["radius_km"]) == pytest.approx(50.0)


@pytest.mark.asyncio
@pytest.mark.integration
async def test_invalid_preference_radius_rejected(authed_client):
    resp = await authed_client.put(
        "/api/v1/skywatch/preferences",
        json={"radius_km": 1000},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
@pytest.mark.integration
async def test_overhead_returns_aircraft_with_matches(authed_client):
    fake_aircraft = [
        Aircraft(
            hex="ae1234", flight="RCH123", registration="12-3456", type="C17",
            lat=37.78, lon=-122.42, alt_baro=28000, ground_speed=400.0, track=90.0,
            squawk="1201", is_military=True, distance_km=5.0,
        ),
        Aircraft(
            hex="a1b2c3", flight="UAL123", registration="N12345", type="B738",
            lat=37.77, lon=-122.41, alt_baro=35000, ground_speed=450.0, track=270.0,
            squawk="1200", is_military=False, distance_km=8.0,
        ),
    ]

    with patch(
        "app.services.adsb.resolver.DataSourceResolver.get_aircraft",
        return_value=fake_aircraft,
    ):
        resp = await authed_client.get("/api/v1/skywatch/overhead?lat=37.7749&lon=-122.4194")

    assert resp.status_code == 200
    body = resp.json()
    assert body["source"] == "network"
    assert len(body["aircraft"]) == 2

    mil = next(a for a in body["aircraft"] if a["hex"] == "ae1234")
    assert mil["is_military"] is True
    assert any(m["trigger"] == "military" for m in mil["matches"])


@pytest.mark.asyncio
@pytest.mark.integration
async def test_overhead_adsb_failure_returns_502(authed_client):
    from app.services.adsb import AdsbServiceError

    with patch(
        "app.services.adsb.resolver.DataSourceResolver.get_aircraft",
        side_effect=AdsbServiceError("network down"),
    ):
        resp = await authed_client.get("/api/v1/skywatch/overhead?lat=37.7749&lon=-122.4194")

    assert resp.status_code == 502


@pytest.mark.asyncio
@pytest.mark.integration
async def test_overhead_invalid_coordinates_rejected(authed_client):
    resp = await authed_client.get("/api/v1/skywatch/overhead?lat=999&lon=-122.4194")
    assert resp.status_code == 422


@pytest.mark.asyncio
@pytest.mark.integration
async def test_alerts_empty_by_default(authed_client):
    resp = await authed_client.get("/api/v1/skywatch/alerts")
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
@pytest.mark.integration
async def test_preferences_user_isolation(authed_client):
    from app.main import app
    from app.auth import get_current_user_id

    # Set radius for TEST_USER_ID
    await authed_client.put("/api/v1/skywatch/preferences", json={"radius_km": 75})

    app.dependency_overrides[get_current_user_id] = lambda: OTHER_USER_ID
    try:
        resp = await authed_client.get("/api/v1/skywatch/preferences")
        assert resp.status_code == 200
        assert float(resp.json()["radius_km"]) == pytest.approx(30.0)
    finally:
        app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
