import pytest

TEST_USER_ID = "user_test_atlas_001"
OTHER_USER_ID = "user_test_other_002"


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    import redis.asyncio as aioredis
    from app.config import settings
    fresh_redis = aioredis.from_url(settings.redis_url, decode_responses=True)
    await fresh_redis.delete(f"map:planned:{TEST_USER_ID}")
    await fresh_redis.delete(f"map:planned:{OTHER_USER_ID}")
    await fresh_redis.aclose()
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


async def _seed_planned_destination(client) -> None:
    trip_resp = await client.post(
        "/api/v1/trips",
        json={"title": "Planned Trip", "status": "planned"},
    )
    trip_id = trip_resp.json()["id"]
    await client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={
            "city": "Lisbon",
            "country_code": "PT",
            "country_name": "Portugal",
            "latitude": 38.7169,
            "longitude": -9.1395,
        },
    )


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_planned_returns_list(authed_client):
    await _seed_planned_destination(authed_client)
    resp = await authed_client.get("/api/v1/map/planned")
    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body, list)
    lisbon = next((c for c in body if c["city"] == "Lisbon"), None)
    assert lisbon is not None
    assert abs(lisbon["latitude"] - 38.7169) < 0.001


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_planned_excludes_past_trips(authed_client):
    trip_resp = await authed_client.post(
        "/api/v1/trips",
        json={"title": "Past Trip", "status": "past"},
    )
    trip_id = trip_resp.json()["id"]
    await authed_client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={
            "city": "Berlin",
            "country_code": "DE",
            "country_name": "Germany",
            "latitude": 52.52,
            "longitude": 13.405,
        },
    )
    resp = await authed_client.get("/api/v1/map/planned")
    body = resp.json()
    berlin = [c for c in body if c["city"] == "Berlin"]
    assert len(berlin) == 0


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_planned_user_isolation(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    import redis.asyncio as aioredis
    from app.config import settings

    r = aioredis.from_url(settings.redis_url, decode_responses=True)
    await r.delete(f"map:planned:{TEST_USER_ID}")
    await r.delete(f"map:planned:{OTHER_USER_ID}")
    await r.aclose()

    app.dependency_overrides[get_current_user_id] = lambda: OTHER_USER_ID
    trip_resp = await client.post("/api/v1/trips", json={"title": "Other Planned", "status": "planned"})
    trip_id = trip_resp.json()["id"]
    await client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={"city": "Seoul", "country_code": "KR", "country_name": "South Korea",
              "latitude": 37.5665, "longitude": 126.978},
    )

    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    try:
        resp = await client.get("/api/v1/map/planned")
        body = resp.json()
        seoul = [c for c in body if c["city"] == "Seoul"]
        assert len(seoul) == 0
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
