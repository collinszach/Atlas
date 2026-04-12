import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, patch
from httpx import AsyncClient

from tests.conftest import TEST_USER_ID, OTHER_USER_ID

ENRICH_SUMMARY = "Tokyo is a dazzling collision of ancient temples and neon-lit skyscrapers. The city rewards explorers with world-class ramen, bullet trains, and a culture of extraordinary craftsmanship."


@pytest.mark.asyncio
async def test_enrich_requires_auth(client: AsyncClient, db_session, seed_test_users):
    from app.models.bucket_list import BucketList
    item = BucketList(
        user_id=TEST_USER_ID,
        country_name="Japan",
        country_code="JP",
        city="Tokyo",
        priority=3,
    )
    db_session.add(item)
    await db_session.flush()
    res = await client.post(f"/api/v1/bucket-list/{item.id}/enrich")
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_enrich_sets_ai_summary(auth_client: AsyncClient, db_session):
    from app.models.bucket_list import BucketList
    item = BucketList(
        user_id=TEST_USER_ID,
        country_name="Japan",
        country_code="JP",
        city="Tokyo",
        priority=3,
    )
    db_session.add(item)
    await db_session.flush()

    with patch(
        "app.routers.bucket_list.ai_service.enrich_bucket_list_item",
        new=AsyncMock(return_value=ENRICH_SUMMARY),
    ):
        res = await auth_client.post(f"/api/v1/bucket-list/{item.id}/enrich")

    assert res.status_code == 200
    data = res.json()
    assert data["ai_summary"] == ENRICH_SUMMARY
    assert data["id"] == str(item.id)


@pytest.mark.asyncio
async def test_enrich_wrong_user_returns_404(auth_client: AsyncClient, db_session):
    from app.models.bucket_list import BucketList
    item = BucketList(
        user_id=OTHER_USER_ID,
        country_name="Brazil",
        country_code="BR",
        priority=2,
    )
    db_session.add(item)
    await db_session.flush()

    with patch(
        "app.routers.bucket_list.ai_service.enrich_bucket_list_item",
        new=AsyncMock(return_value="Should not be called"),
    ):
        res = await auth_client.post(f"/api/v1/bucket-list/{item.id}/enrich")

    assert res.status_code == 404
