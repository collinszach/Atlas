import pytest

TEST_USER_ID = "user_test_atlas_001"


@pytest.fixture
async def auth_stats_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


@pytest.mark.asyncio
@pytest.mark.integration
async def test_stats_empty_user(auth_stats_client):
    """New user with no data returns zeroed stats."""
    resp = await auth_stats_client.get("/api/v1/stats")
    assert resp.status_code == 200
    body = resp.json()
    assert body["flights_count"] == 0
    assert body["total_distance_km"] == 0.0
    assert body["co2_kg_estimate"] == 0.0
    assert body["hours_in_air"] is None
    assert body["top_airline"] is None


@pytest.mark.asyncio
@pytest.mark.integration
async def test_stats_with_data(auth_stats_client):
    """Stats aggregate correctly after logging a flight."""
    resp = await auth_stats_client.post(
        "/api/v1/flights",
        json={"distance_km": "5560", "origin_iata": "NRT", "dest_iata": "SFO"},
    )
    assert resp.status_code == 201

    resp = await auth_stats_client.get("/api/v1/stats")
    assert resp.status_code == 200
    body = resp.json()
    assert body["flights_count"] == 1
    assert body["total_distance_km"] == 5560.0
    assert abs(body["co2_kg_estimate"] - 5560.0 * 0.115) < 0.01
