import pytest


@pytest.mark.asyncio
async def test_map_arcs_requires_auth(client):
    response = await client.get("/api/v1/map/arcs")
    assert response.status_code == 401
