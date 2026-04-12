import pytest

# NOTE: These tests require a running PostgreSQL+PostGIS instance.
# Run via: docker compose exec atlas-backend pytest tests/test_trips.py
# They are validated in the BE Task 10 integration smoke test.

TEST_USER_ID = "user_test_atlas_001"


@pytest.fixture
async def authed_client(client, seed_test_users):
    """Client with dependency_overrides so FastAPI resolves auth to TEST_USER_ID."""
    from app.main import app
    from app.auth import get_current_user_id

    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


@pytest.mark.asyncio
@pytest.mark.integration
async def test_create_trip(authed_client):
    response = await authed_client.post(
        "/api/v1/trips",
        json={"title": "Japan Spring 2025", "status": "past", "visibility": "private"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["title"] == "Japan Spring 2025"
    assert body["user_id"] == TEST_USER_ID
    assert "id" in body


@pytest.mark.asyncio
@pytest.mark.integration
async def test_list_trips_empty(authed_client):
    response = await authed_client.get("/api/v1/trips")
    assert response.status_code == 200
    assert response.json()["items"] == []


@pytest.mark.asyncio
@pytest.mark.integration
async def test_get_trip_not_found(authed_client):
    response = await authed_client.get("/api/v1/trips/00000000-0000-0000-0000-000000000000")
    assert response.status_code == 404


@pytest.mark.asyncio
@pytest.mark.integration
async def test_cannot_read_another_users_trip(authed_client):
    """User isolation: trip created by user A is not visible to user B."""
    from app.main import app
    from app.auth import get_current_user_id

    create_resp = await authed_client.post(
        "/api/v1/trips",
        json={"title": "Private Trip"},
    )
    trip_id = create_resp.json()["id"]

    # Switch auth to a different user
    app.dependency_overrides[get_current_user_id] = lambda: "user_different_002"
    try:
        response = await authed_client.get(f"/api/v1/trips/{trip_id}")
    finally:
        app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_invalid_status_rejected(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: "user_test_atlas_001"
    try:
        resp = await client.post("/api/v1/trips", json={"title": "T", "status": "canceled"})
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
    assert resp.status_code == 422
