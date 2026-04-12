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


async def _create_item(client, **overrides) -> str:
    payload = {"country_code": "JP", "country_name": "Japan", "city": "Kyoto", **overrides}
    resp = await client.post("/api/v1/bucket-list", json=payload)
    assert resp.status_code == 201
    return resp.json()["id"]


@pytest.mark.asyncio
@pytest.mark.integration
async def test_create_bucket_list_item(authed_client):
    resp = await authed_client.post(
        "/api/v1/bucket-list",
        json={
            "country_code": "IS",
            "country_name": "Iceland",
            "city": "Reykjavik",
            "priority": 4,
            "reason": "Northern lights",
            "ideal_season": "winter",
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["country_code"] == "IS"
    assert body["city"] == "Reykjavik"
    assert body["priority"] == 4
    assert body["ideal_season"] == "winter"


@pytest.mark.asyncio
@pytest.mark.integration
async def test_list_bucket_list(authed_client):
    await _create_item(authed_client, city="Tokyo")
    await _create_item(authed_client, city="Osaka")
    resp = await authed_client.get("/api/v1/bucket-list")
    assert resp.status_code == 200
    assert len(resp.json()) >= 2


@pytest.mark.asyncio
@pytest.mark.integration
async def test_update_bucket_list_item(authed_client):
    item_id = await _create_item(authed_client)
    resp = await authed_client.put(
        f"/api/v1/bucket-list/{item_id}",
        json={"priority": 5, "reason": "Updated reason"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["priority"] == 5
    assert body["reason"] == "Updated reason"


@pytest.mark.asyncio
@pytest.mark.integration
async def test_delete_bucket_list_item(authed_client):
    item_id = await _create_item(authed_client)
    resp = await authed_client.delete(f"/api/v1/bucket-list/{item_id}")
    assert resp.status_code == 204
    list_resp = await authed_client.get("/api/v1/bucket-list")
    ids = [i["id"] for i in list_resp.json()]
    assert item_id not in ids


@pytest.mark.asyncio
@pytest.mark.integration
async def test_bucket_list_user_isolation(authed_client):
    from app.main import app
    from app.auth import get_current_user_id
    item_id = await _create_item(authed_client)
    app.dependency_overrides[get_current_user_id] = lambda: OTHER_USER_ID
    try:
        resp = await authed_client.put(
            f"/api/v1/bucket-list/{item_id}",
            json={"priority": 1},
        )
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
    assert resp.status_code == 404


@pytest.mark.asyncio
@pytest.mark.integration
async def test_invalid_priority_rejected(authed_client):
    resp = await authed_client.post(
        "/api/v1/bucket-list",
        json={"country_code": "DE", "country_name": "Germany", "city": "Berlin", "priority": 9},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
@pytest.mark.integration
async def test_invalid_season_rejected(authed_client):
    resp = await authed_client.post(
        "/api/v1/bucket-list",
        json={"country_code": "DE", "country_name": "Germany", "city": "Berlin", "ideal_season": "monsoon"},
    )
    assert resp.status_code == 422
