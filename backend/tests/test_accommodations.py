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
    resp = await client.post("/api/v1/trips", json={"title": "Accommodation Test Trip"})
    assert resp.status_code == 201
    return resp.json()["id"]


async def _create_accommodation(client, trip_id: str) -> str:
    resp = await client.post(
        f"/api/v1/trips/{trip_id}/accommodations",
        json={"name": "The Savoy", "type": "hotel"},
    )
    assert resp.status_code == 201
    return resp.json()["id"]


@pytest.mark.asyncio
@pytest.mark.integration
async def test_create_accommodation(authed_client):
    trip_id = await _create_trip(authed_client)
    resp = await authed_client.post(
        f"/api/v1/trips/{trip_id}/accommodations",
        json={
            "name": "Hotel de Crillon",
            "type": "hotel",
            "address": "10 Place de la Concorde, Paris",
            "cost_per_night": 850.00,
            "currency": "EUR",
            "check_in": "2025-06-15T15:00:00Z",
            "check_out": "2025-06-18T11:00:00Z",
            "confirmation": "CONF-12345",
            "rating": 5,
            "latitude": 48.8656,
            "longitude": 2.3212,
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["name"] == "Hotel de Crillon"
    assert body["currency"] == "EUR"
    assert abs(body["latitude"] - 48.8656) < 0.001


@pytest.mark.asyncio
@pytest.mark.integration
async def test_list_accommodations(authed_client):
    trip_id = await _create_trip(authed_client)
    await _create_accommodation(authed_client, trip_id)
    await _create_accommodation(authed_client, trip_id)
    resp = await authed_client.get(f"/api/v1/trips/{trip_id}/accommodations")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


@pytest.mark.asyncio
@pytest.mark.integration
async def test_update_accommodation(authed_client):
    trip_id = await _create_trip(authed_client)
    acc_id = await _create_accommodation(authed_client, trip_id)
    resp = await authed_client.put(
        f"/api/v1/accommodations/{acc_id}",
        json={"rating": 4, "notes": "Great breakfast"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["rating"] == 4
    assert body["notes"] == "Great breakfast"


@pytest.mark.asyncio
@pytest.mark.integration
async def test_delete_accommodation(authed_client):
    trip_id = await _create_trip(authed_client)
    acc_id = await _create_accommodation(authed_client, trip_id)
    resp = await authed_client.delete(f"/api/v1/accommodations/{acc_id}")
    assert resp.status_code == 204
    list_resp = await authed_client.get(f"/api/v1/trips/{trip_id}/accommodations")
    assert list_resp.json() == []


@pytest.mark.asyncio
@pytest.mark.integration
async def test_accommodation_user_isolation(authed_client):
    from app.main import app
    from app.auth import get_current_user_id

    trip_id = await _create_trip(authed_client)
    await _create_accommodation(authed_client, trip_id)

    app.dependency_overrides[get_current_user_id] = lambda: OTHER_USER_ID
    try:
        resp = await authed_client.get(f"/api/v1/trips/{trip_id}/accommodations")
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
    assert resp.status_code == 404
