import pytest
from unittest.mock import AsyncMock, patch


TEST_USER_ID = "user_test_atlas_001"

# Fake monthly climate data: 12 entries (one per month averaged across years)
FAKE_MONTHLY = [
    {"month": i, "avg_max_temp_c": 20.0 + i, "avg_precipitation_mm": 40.0}
    for i in range(1, 13)
]


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


@pytest.mark.asyncio
async def test_best_time_requires_auth(client):
    resp = await client.get("/api/v1/discover/best-time/JP")
    assert resp.status_code == 401


@pytest.mark.asyncio
@pytest.mark.integration
async def test_best_time_returns_data(authed_client):
    from app.services import open_meteo

    async def fake_geocode(name: str) -> tuple[float, float, str]:
        return (35.6895, 139.6917, "Tokyo, Japan")

    async def fake_fetch_climate(lat: float, lng: float) -> list[dict]:
        return FAKE_MONTHLY

    with patch.object(open_meteo, "geocode", fake_geocode), \
         patch.object(open_meteo, "fetch_monthly_averages", fake_fetch_climate):
        resp = await authed_client.get("/api/v1/discover/best-time/JP?city=Tokyo")

    assert resp.status_code == 200
    body = resp.json()
    assert body["location"] == "Tokyo, Japan"
    assert abs(body["latitude"] - 35.6895) < 0.001
    assert len(body["monthly"]) == 12
    assert isinstance(body["best_months"], list)
    assert body["monthly"][0]["month"] == 1
