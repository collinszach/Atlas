import pytest

TEST_USER_ID = "user_test_atlas_001"


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


async def _seed_flight(client, with_geo: bool = True) -> None:
    trip_resp = await client.post("/api/v1/trips", json={"title": "Arc Test Trip"})
    trip_id = trip_resp.json()["id"]
    payload = {
        "type": "flight",
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
    await client.post(f"/api/v1/trips/{trip_id}/transport", json=payload)


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
    # The no-geo flight should not appear
    arcs = resp.json()
    no_geo_arcs = [a for a in arcs if a.get("origin_lat") is None]
    assert len(no_geo_arcs) == 0


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_arcs_excludes_non_flight_legs(authed_client):
    trip_resp = await authed_client.post("/api/v1/trips", json={"title": "Non-flight Trip"})
    trip_id = trip_resp.json()["id"]
    await authed_client.post(
        f"/api/v1/trips/{trip_id}/transport",
        json={
            "type": "train",
            "origin_city": "Paris",
            "dest_city": "Amsterdam",
            "origin_lat": 48.8566,
            "origin_lng": 2.3522,
            "dest_lat": 52.3676,
            "dest_lng": 4.9041,
        },
    )
    resp = await authed_client.get("/api/v1/map/arcs")
    arcs = resp.json()
    paris_arcs = [a for a in arcs if a.get("origin_city") == "Paris"]
    assert len(paris_arcs) == 0
