import pytest

# NOTE: test_map_countries_returns_list and test_map_cities_returns_list
# require running PostgreSQL+PostGIS+Redis. Validated in BE Task 10.

TEST_USER_ID = "user_test_atlas_001"


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


@pytest.mark.asyncio
async def test_map_countries_requires_auth(client):
    response = await client.get("/api/v1/map/countries")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_map_cities_requires_auth(client):
    response = await client.get("/api/v1/map/cities")
    assert response.status_code == 401


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_countries_returns_list(authed_client):
    response = await authed_client.get("/api/v1/map/countries")
    assert response.status_code == 200
    body = response.json()
    assert isinstance(body, list)


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_cities_returns_list(authed_client):
    response = await authed_client.get("/api/v1/map/cities")
    assert response.status_code == 200
    body = response.json()
    assert isinstance(body, list)
