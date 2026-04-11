import pytest

# NOTE: Requires running PostgreSQL+PostGIS. Run in Docker via BE Task 10.

TEST_USER_ID = "user_test_atlas_001"
OTHER_USER_ID = "user_test_other_002"


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


async def create_test_trip(client) -> str:
    resp = await client.post("/api/v1/trips", json={"title": "Test Trip"})
    assert resp.status_code == 201
    return resp.json()["id"]


async def create_test_destination(client, trip_id: str) -> str:
    resp = await client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={"city": "Tokyo", "country_code": "JP", "country_name": "Japan"},
    )
    assert resp.status_code == 201
    return resp.json()["id"]


@pytest.mark.asyncio
@pytest.mark.integration
async def test_add_destination(authed_client):
    trip_id = await create_test_trip(authed_client)
    response = await authed_client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={
            "city": "Tokyo",
            "country_code": "JP",
            "country_name": "Japan",
            "arrival_date": "2025-03-15",
            "departure_date": "2025-03-22",
        },
    )
    assert response.status_code == 201
    body = response.json()
    assert body["city"] == "Tokyo"
    assert body["nights"] == 7


@pytest.mark.asyncio
@pytest.mark.integration
async def test_add_destination_with_coordinates(authed_client):
    trip_id = await create_test_trip(authed_client)
    response = await authed_client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={
            "city": "Paris",
            "country_code": "FR",
            "country_name": "France",
            "latitude": 48.8566,
            "longitude": 2.3522,
        },
    )
    assert response.status_code == 201
    body = response.json()
    assert abs(body["latitude"] - 48.8566) < 0.001


@pytest.mark.asyncio
@pytest.mark.integration
async def test_destination_belongs_to_trip(authed_client):
    trip_id = await create_test_trip(authed_client)
    await authed_client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={"city": "Osaka", "country_code": "JP", "country_name": "Japan"},
    )
    response = await authed_client.get(f"/api/v1/trips/{trip_id}/destinations")
    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["city"] == "Osaka"


@pytest.mark.asyncio
@pytest.mark.integration
async def test_update_destination(authed_client):
    trip_id = await create_test_trip(authed_client)
    dest_id = await create_test_destination(authed_client, trip_id)
    response = await authed_client.put(
        f"/api/v1/destinations/{dest_id}",
        json={"city": "Kyoto", "notes": "Beautiful temples"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["city"] == "Kyoto"
    assert body["notes"] == "Beautiful temples"


@pytest.mark.asyncio
@pytest.mark.integration
async def test_delete_destination(authed_client):
    trip_id = await create_test_trip(authed_client)
    dest_id = await create_test_destination(authed_client, trip_id)
    response = await authed_client.delete(f"/api/v1/destinations/{dest_id}")
    assert response.status_code == 204
    # Verify it's gone
    list_resp = await authed_client.get(f"/api/v1/trips/{trip_id}/destinations")
    assert list_resp.json() == []


@pytest.mark.asyncio
@pytest.mark.integration
async def test_cannot_access_another_users_destination(authed_client):
    """User B cannot read destinations for user A's trip."""
    from app.main import app
    from app.auth import get_current_user_id

    trip_id = await create_test_trip(authed_client)
    await create_test_destination(authed_client, trip_id)

    # Switch to different user
    app.dependency_overrides[get_current_user_id] = lambda: OTHER_USER_ID
    try:
        response = await authed_client.get(f"/api/v1/trips/{trip_id}/destinations")
    finally:
        app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    assert response.status_code == 404


@pytest.mark.asyncio
@pytest.mark.integration
async def test_coordinate_validation_requires_both_or_neither(authed_client):
    """Providing only latitude without longitude must return 422."""
    trip_id = await create_test_trip(authed_client)
    response = await authed_client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={"city": "Berlin", "country_code": "DE", "country_name": "Germany", "latitude": 52.5},
    )
    assert response.status_code == 422
