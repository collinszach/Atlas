import pytest

TEST_USER_ID = "user_test_atlas_001"
OTHER_USER_ID = "user_test_other_002"


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


async def _create_trip(client) -> str:
    resp = await client.post("/api/v1/trips", json={"title": "Transport Test Trip"})
    assert resp.status_code == 201
    return resp.json()["id"]


async def _create_leg(client, trip_id: str, **overrides) -> str:
    payload = {"type": "flight", "origin_city": "JFK", "dest_city": "LHR", **overrides}
    resp = await client.post(f"/api/v1/trips/{trip_id}/transport", json=payload)
    assert resp.status_code == 201
    return resp.json()["id"]


@pytest.mark.asyncio
@pytest.mark.integration
async def test_create_flight_leg(authed_client):
    trip_id = await _create_trip(authed_client)
    resp = await authed_client.post(
        f"/api/v1/trips/{trip_id}/transport",
        json={
            "type": "flight",
            "flight_number": "BA178",
            "airline": "British Airways",
            "origin_iata": "JFK",
            "dest_iata": "LHR",
            "origin_city": "New York",
            "dest_city": "London",
            "departure_at": "2025-06-01T09:00:00Z",
            "arrival_at": "2025-06-01T21:00:00Z",
            "duration_min": 420,
            "seat_class": "economy",
            "origin_lat": 40.6413,
            "origin_lng": -73.7781,
            "dest_lat": 51.4775,
            "dest_lng": -0.4614,
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["flight_number"] == "BA178"
    assert body["duration_min"] == 420
    assert abs(body["origin_lat"] - 40.6413) < 0.001
    assert abs(body["dest_lat"] - 51.4775) < 0.001


@pytest.mark.asyncio
@pytest.mark.integration
async def test_list_transport_legs(authed_client):
    trip_id = await _create_trip(authed_client)
    await _create_leg(authed_client, trip_id)
    await _create_leg(authed_client, trip_id, type="train", origin_city="London", dest_city="Paris")
    resp = await authed_client.get(f"/api/v1/trips/{trip_id}/transport")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


@pytest.mark.asyncio
@pytest.mark.integration
async def test_update_transport_leg(authed_client):
    trip_id = await _create_trip(authed_client)
    leg_id = await _create_leg(authed_client, trip_id)
    resp = await authed_client.put(
        f"/api/v1/transport/{leg_id}",
        json={"flight_number": "AA100", "seat_class": "business"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["flight_number"] == "AA100"
    assert body["seat_class"] == "business"


@pytest.mark.asyncio
@pytest.mark.integration
async def test_delete_transport_leg(authed_client):
    trip_id = await _create_trip(authed_client)
    leg_id = await _create_leg(authed_client, trip_id)
    resp = await authed_client.delete(f"/api/v1/transport/{leg_id}")
    assert resp.status_code == 204
    list_resp = await authed_client.get(f"/api/v1/trips/{trip_id}/transport")
    assert list_resp.json() == []


@pytest.mark.asyncio
@pytest.mark.integration
async def test_transport_user_isolation(authed_client):
    from app.main import app
    from app.auth import get_current_user_id

    trip_id = await _create_trip(authed_client)
    await _create_leg(authed_client, trip_id)

    app.dependency_overrides[get_current_user_id] = lambda: OTHER_USER_ID
    try:
        resp = await authed_client.get(f"/api/v1/trips/{trip_id}/transport")
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
    assert resp.status_code == 404


@pytest.mark.asyncio
@pytest.mark.integration
async def test_invalid_transport_type_rejected(authed_client):
    trip_id = await _create_trip(authed_client)
    resp = await authed_client.post(
        f"/api/v1/trips/{trip_id}/transport",
        json={"type": "teleporter", "origin_city": "A", "dest_city": "B"},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
@pytest.mark.integration
async def test_enrich_flight_no_key_returns_503(authed_client):
    resp = await authed_client.post(
        "/api/v1/transport/enrich-flight",
        json={"flight_number": "AA123", "date": "2026-04-19"},
    )
    assert resp.status_code == 503
    assert "not configured" in resp.json()["detail"]


@pytest.mark.asyncio
@pytest.mark.integration
async def test_enrich_flight_requires_auth(client):
    resp = await client.post(
        "/api/v1/transport/enrich-flight",
        json={"flight_number": "AA123", "date": "2026-04-19"},
    )
    assert resp.status_code == 401
