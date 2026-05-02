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
    assert body["countries_visited"] == 0
    assert body["cities_visited"] == 0
    assert body["total_nights"] == 0
    assert body["total_distance_km"] == 0.0
    assert body["co2_estimate_kg"] == 0.0
    assert body["longest_trip_nights"] is None
    assert body["most_visited_country"] is None


@pytest.mark.asyncio
@pytest.mark.integration
async def test_stats_with_data(auth_stats_client):
    """Stats aggregate correctly after creating a trip with destinations."""
    trip_resp = await auth_stats_client.post(
        "/api/v1/trips",
        json={"title": "Stats Test Trip", "status": "past"},
    )
    assert trip_resp.status_code == 201
    trip_id = trip_resp.json()["id"]

    await auth_stats_client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={
            "city": "Tokyo",
            "country_code": "JP",
            "country_name": "Japan",
            "arrival_date": "2025-03-10",
            "departure_date": "2025-03-17",
        },
    )

    await auth_stats_client.post(
        f"/api/v1/trips/{trip_id}/transport",
        json={"type": "flight", "distance_km": "5560"},
    )

    # Refresh materialized view so most_visited_country is current
    from app.database import get_db
    from sqlalchemy import text
    async for db in get_db():
        await db.execute(text("REFRESH MATERIALIZED VIEW CONCURRENTLY country_visits"))
        await db.commit()
        break

    resp = await auth_stats_client.get("/api/v1/stats")
    assert resp.status_code == 200
    body = resp.json()
    assert body["countries_visited"] == 1
    assert body["cities_visited"] == 1
    assert body["total_nights"] == 7
    assert body["total_distance_km"] == 5560.0
    assert abs(body["co2_estimate_kg"] - 5560.0 * 0.115) < 0.01
    assert body["most_visited_country"] == "Japan"


@pytest.mark.asyncio
@pytest.mark.integration
async def test_stats_heatmap(auth_stats_client):
    trip_resp = await auth_stats_client.post(
        "/api/v1/trips",
        json={"title": "Heatmap Trip", "status": "past"},
    )
    trip_id = trip_resp.json()["id"]
    await auth_stats_client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={"city": "Paris", "country_code": "FR", "country_name": "France"},
    )
    # Refresh materialized view so heatmap query sees the data
    from app.database import get_db
    from sqlalchemy import text
    async for db in get_db():
        await db.execute(text("REFRESH MATERIALIZED VIEW CONCURRENTLY country_visits"))
        await db.commit()
        break

    resp = await auth_stats_client.get("/api/v1/stats/heatmap")
    assert resp.status_code == 200
    body = resp.json()
    assert any(e["country_code"] == "FR" for e in body)


@pytest.mark.asyncio
@pytest.mark.integration
async def test_stats_timeline_empty(auth_stats_client):
    resp = await auth_stats_client.get("/api/v1/stats/timeline")
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
@pytest.mark.integration
async def test_stats_timeline_with_trip(auth_stats_client):
    trip_resp = await auth_stats_client.post(
        "/api/v1/trips",
        json={"title": "Timeline Trip", "status": "past", "start_date": "2025-01-01"},
    )
    trip_id = trip_resp.json()["id"]

    resp = await auth_stats_client.get("/api/v1/stats/timeline")
    assert resp.status_code == 200
    body = resp.json()
    assert len(body) >= 1
    trip_entry = next(e for e in body if e["id"] == trip_id)
    assert trip_entry["title"] == "Timeline Trip"
    assert trip_entry["destination_count"] == 0
    assert trip_entry["transport_count"] == 0
