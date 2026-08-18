import pytest

TEST_USER_ID = "user_test_atlas_001"
OTHER_USER_ID = "user_test_other_002"


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    import redis.asyncio as aioredis
    from app.config import settings
    # Fresh connection per fixture invocation to avoid singleton event-loop issues
    fresh_redis = aioredis.from_url(settings.redis_url, decode_responses=True)
    await fresh_redis.delete(f"map:arcs:{TEST_USER_ID}")
    await fresh_redis.delete(f"map:arcs:{OTHER_USER_ID}")
    await fresh_redis.aclose()
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


async def _seed_flight(client, with_geo: bool = True) -> None:
    payload = {
        "flight_number": "UA900",
        "origin_city": "San Francisco",
        "dest_city": "Tokyo",
    }
    if with_geo:
        payload.update(
            origin_lat=37.6213,
            origin_lng=-122.379,
            dest_lat=35.5494,
            dest_lng=139.7798,
        )
    await client.post("/api/v1/flights", json=payload)


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_arcs_returns_flight_with_geo(authed_client):
    await _seed_flight(authed_client, with_geo=True)
    resp = await authed_client.get("/api/v1/map/arcs")
    assert resp.status_code == 200
    arcs = resp.json()
    assert len(arcs) >= 1
    arc = next(a for a in arcs if a["flight_number"] == "UA900")
    assert arc["origin_city"] == "San Francisco"
    assert abs(arc["origin_lat"] - 37.6213) < 0.001
    assert abs(arc["dest_lat"] - 35.5494) < 0.001


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_arcs_excludes_flights_without_geo(authed_client):
    await _seed_flight(authed_client, with_geo=False)
    resp = await authed_client.get("/api/v1/map/arcs")
    assert resp.status_code == 200
    # The no-geo flight should not appear in the arc list at all
    arcs = resp.json()
    ua900_arcs = [a for a in arcs if a.get("flight_number") == "UA900"]
    assert len(ua900_arcs) == 0


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_arcs_user_isolation(client, seed_test_users):
    """User B's flights do not appear in User A's arc response."""
    import redis.asyncio as aioredis
    from app.config import settings
    from app.main import app
    from app.auth import get_current_user_id

    # Clear cache for both users so we don't read stale results
    r = aioredis.from_url(settings.redis_url, decode_responses=True)
    await r.delete(f"map:arcs:{TEST_USER_ID}")
    await r.delete(f"map:arcs:{OTHER_USER_ID}")
    await r.aclose()

    # User B seeds a flight
    app.dependency_overrides[get_current_user_id] = lambda: OTHER_USER_ID
    await client.post(
        "/api/v1/flights",
        json={
            "flight_number": "XY999",
            "origin_city": "Berlin",
            "dest_city": "Rome",
            "origin_lat": 52.3667,
            "origin_lng": 13.5033,
            "dest_lat": 41.8003,
            "dest_lng": 12.2389,
        },
    )

    # User A sees no arcs
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    try:
        resp = await client.get("/api/v1/map/arcs")
        arcs = resp.json()
        berlin_arcs = [a for a in arcs if a.get("origin_city") == "Berlin"]
        assert len(berlin_arcs) == 0
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
