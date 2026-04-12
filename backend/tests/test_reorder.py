import pytest

TEST_USER_ID = "user_test_atlas_001"


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


async def _create_trip_with_destinations(client) -> tuple[str, list[str]]:
    trip_resp = await client.post("/api/v1/trips", json={"title": "Reorder Test Trip"})
    assert trip_resp.status_code == 201
    trip_id = trip_resp.json()["id"]
    dest_ids = []
    for city, cc, cn in [("Rome", "IT", "Italy"), ("Florence", "IT", "Italy"), ("Venice", "IT", "Italy")]:
        r = await client.post(
            f"/api/v1/trips/{trip_id}/destinations",
            json={"city": city, "country_code": cc, "country_name": cn, "order_index": len(dest_ids)},
        )
        assert r.status_code == 201
        dest_ids.append(r.json()["id"])
    return trip_id, dest_ids


@pytest.mark.asyncio
@pytest.mark.integration
async def test_reorder_destinations(authed_client):
    trip_id, dest_ids = await _create_trip_with_destinations(authed_client)
    new_order = [{"id": dest_ids[2], "order_index": 0},
                 {"id": dest_ids[1], "order_index": 1},
                 {"id": dest_ids[0], "order_index": 2}]
    resp = await authed_client.patch(
        f"/api/v1/trips/{trip_id}/destinations/reorder",
        json=new_order,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body[0]["id"] == dest_ids[2]
    assert body[0]["order_index"] == 0
    assert body[2]["id"] == dest_ids[0]
    assert body[2]["order_index"] == 2


@pytest.mark.asyncio
@pytest.mark.integration
async def test_reorder_wrong_trip_ignored(authed_client):
    trip_id1, dest_ids1 = await _create_trip_with_destinations(authed_client)
    trip_id2, dest_ids2 = await _create_trip_with_destinations(authed_client)
    new_order = [{"id": dest_ids2[0], "order_index": 0}]
    resp = await authed_client.patch(
        f"/api/v1/trips/{trip_id1}/destinations/reorder",
        json=new_order,
    )
    assert resp.status_code == 200
    list_resp = await authed_client.get(f"/api/v1/trips/{trip_id1}/destinations")
    assert len(list_resp.json()) == 3
