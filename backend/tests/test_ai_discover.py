import pytest
from unittest.mock import AsyncMock, patch
from httpx import AsyncClient

from app.main import app

TEST_USER_ID = "user_test_atlas_001"

RECOMMEND_URL = "/api/v1/discover/recommend"
BRIEF_URL = "/api/v1/discover/destination-brief"

SAMPLE_RECOMMENDATIONS = [
    {
        "country": "Portugal",
        "country_code": "PT",
        "city": "Lisbon",
        "why_youll_love_it": "Great food, similar vibe to cities you loved",
        "best_time": "April–June",
        "rough_cost": "moderate",
        "getting_there": "Direct flights from most US hubs",
    }
]

SAMPLE_BRIEF = {
    "destination": "Japan",
    "overview": "Island nation in East Asia",
    "best_months": [3, 4, 10, 11],
    "visa_notes": "Visa-free for US passport holders",
    "rough_costs": "moderate–high",
    "must_do": ["Kyoto temples", "Tokyo street food"],
    "food_highlights": ["Ramen", "Sushi", "Yakitori"],
    "transport_within": "JR Pass covers bullet trains",
}


@pytest.fixture
async def auth_client(client):
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


@pytest.mark.asyncio
async def test_recommend_requires_auth(client: AsyncClient):
    res = await client.post(RECOMMEND_URL, json={"preferences": {}, "already_visited": []})
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_destination_brief_requires_auth(client: AsyncClient):
    res = await client.post(BRIEF_URL, json={"country": "JP", "city": None})
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_recommend_returns_list(auth_client: AsyncClient):
    with patch(
        "app.routers.discover.ai_service.get_recommendations",
        new=AsyncMock(return_value=SAMPLE_RECOMMENDATIONS),
    ):
        res = await auth_client.post(
            RECOMMEND_URL,
            json={
                "preferences": {
                    "climate": "warm",
                    "duration_days": 10,
                    "budget": "moderate",
                    "interests": ["food", "history"],
                    "avoid_crowds": False,
                    "departure_region": "North America",
                    "travel_month": "October",
                },
                "already_visited": ["FR", "JP"],
            },
        )
    assert res.status_code == 200
    data = res.json()
    assert isinstance(data, list)
    assert data[0]["country"] == "Portugal"


@pytest.mark.asyncio
async def test_destination_brief_returns_brief(auth_client: AsyncClient):
    with patch(
        "app.routers.discover.ai_service.get_destination_brief",
        new=AsyncMock(return_value=SAMPLE_BRIEF),
    ):
        res = await auth_client.post(
            BRIEF_URL,
            json={"country": "Japan", "country_code": "JP", "city": None},
        )
    assert res.status_code == 200
    data = res.json()
    assert data["destination"] == "Japan"
    assert "best_months" in data
