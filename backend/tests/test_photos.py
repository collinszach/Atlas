"""Integration tests for photo upload, list, delete, and cover endpoints.

Run: docker compose exec atlas-backend pytest tests/test_photos.py -v -m integration
Requires: running PostgreSQL with migration 004 applied.
MinIO is mocked — no real storage calls.
"""
import io
import uuid

import pytest
from PIL import Image
from unittest.mock import AsyncMock, MagicMock, patch

TEST_USER_ID = "user_test_atlas_001"


def _make_jpeg(width: int = 200, height: int = 150) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (width, height), color=(100, 150, 200)).save(buf, format="JPEG")
    return buf.getvalue()


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id

    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


@pytest.fixture
async def trip_id(authed_client) -> str:
    resp = await authed_client.post(
        "/api/v1/trips",
        json={"title": "Photo Test Trip", "status": "past"},
    )
    assert resp.status_code == 201
    return resp.json()["id"]


def _mock_storage():
    mock = MagicMock()
    mock.upload_file = AsyncMock(return_value=None)
    mock.delete_file = AsyncMock(return_value=None)
    mock.public_url = lambda key: f"http://localhost:9000/atlas-photos/{key}"
    return mock


@pytest.mark.asyncio
@pytest.mark.integration
async def test_upload_photo(authed_client, trip_id):
    from app.main import app
    from app.services.storage import get_storage

    mock_storage = _mock_storage()
    app.dependency_overrides[get_storage] = lambda: mock_storage

    with patch("app.routers.photos._generate_and_upload_thumbnail", new_callable=AsyncMock):
        response = await authed_client.post(
            f"/api/v1/trips/{trip_id}/photos/upload",
            files={"file": ("test.jpg", _make_jpeg(), "image/jpeg")},
            data={"caption": "Test photo"},
        )

    app.dependency_overrides.pop(get_storage, None)

    assert response.status_code == 201
    body = response.json()
    assert body["trip_id"] == trip_id
    assert body["caption"] == "Test photo"
    assert body["width"] == 200
    assert body["height"] == 150
    assert "url" in body
    assert body["is_cover"] is False


@pytest.mark.asyncio
@pytest.mark.integration
async def test_upload_rejects_unsupported_type(authed_client, trip_id):
    from app.main import app
    from app.services.storage import get_storage

    app.dependency_overrides[get_storage] = lambda: _mock_storage()
    response = await authed_client.post(
        f"/api/v1/trips/{trip_id}/photos/upload",
        files={"file": ("test.txt", b"not an image", "text/plain")},
    )
    app.dependency_overrides.pop(get_storage, None)
    assert response.status_code == 422


@pytest.mark.asyncio
@pytest.mark.integration
async def test_list_photos_empty(authed_client, trip_id):
    response = await authed_client.get(f"/api/v1/trips/{trip_id}/photos")
    assert response.status_code == 200
    assert response.json()["items"] == []
    assert response.json()["total"] == 0


@pytest.mark.asyncio
@pytest.mark.integration
async def test_list_photos_after_upload(authed_client, trip_id):
    from app.main import app
    from app.services.storage import get_storage

    mock_storage = _mock_storage()
    app.dependency_overrides[get_storage] = lambda: mock_storage

    with patch("app.routers.photos._generate_and_upload_thumbnail", new_callable=AsyncMock):
        await authed_client.post(
            f"/api/v1/trips/{trip_id}/photos/upload",
            files={"file": ("a.jpg", _make_jpeg(), "image/jpeg")},
        )
        await authed_client.post(
            f"/api/v1/trips/{trip_id}/photos/upload",
            files={"file": ("b.jpg", _make_jpeg(), "image/jpeg")},
        )

    response = await authed_client.get(f"/api/v1/trips/{trip_id}/photos")
    app.dependency_overrides.pop(get_storage, None)

    assert response.status_code == 200
    assert response.json()["total"] == 2


@pytest.mark.asyncio
@pytest.mark.integration
async def test_delete_photo(authed_client, trip_id):
    from app.main import app
    from app.services.storage import get_storage

    mock_storage = _mock_storage()
    app.dependency_overrides[get_storage] = lambda: mock_storage

    with patch("app.routers.photos._generate_and_upload_thumbnail", new_callable=AsyncMock):
        upload_resp = await authed_client.post(
            f"/api/v1/trips/{trip_id}/photos/upload",
            files={"file": ("del.jpg", _make_jpeg(), "image/jpeg")},
        )
    photo_id = upload_resp.json()["id"]

    delete_resp = await authed_client.delete(f"/api/v1/photos/{photo_id}")
    app.dependency_overrides.pop(get_storage, None)

    assert delete_resp.status_code == 204
    mock_storage.delete_file.assert_called()


@pytest.mark.asyncio
@pytest.mark.integration
async def test_set_cover_photo(authed_client, trip_id):
    from app.main import app
    from app.services.storage import get_storage

    mock_storage = _mock_storage()
    app.dependency_overrides[get_storage] = lambda: mock_storage

    with patch("app.routers.photos._generate_and_upload_thumbnail", new_callable=AsyncMock):
        upload_resp = await authed_client.post(
            f"/api/v1/trips/{trip_id}/photos/upload",
            files={"file": ("cover.jpg", _make_jpeg(), "image/jpeg")},
        )
    photo_id = upload_resp.json()["id"]

    cover_resp = await authed_client.post(f"/api/v1/photos/{photo_id}/set-cover")
    app.dependency_overrides.pop(get_storage, None)

    assert cover_resp.status_code == 200
    assert cover_resp.json()["cover_photo_id"] == photo_id


@pytest.mark.asyncio
@pytest.mark.integration
async def test_cannot_upload_to_another_users_trip(authed_client, trip_id):
    from app.main import app
    from app.auth import get_current_user_id
    from app.services.storage import get_storage

    app.dependency_overrides[get_current_user_id] = lambda: "user_test_other_002"
    app.dependency_overrides[get_storage] = lambda: _mock_storage()

    response = await authed_client.post(
        f"/api/v1/trips/{trip_id}/photos/upload",
        files={"file": ("x.jpg", _make_jpeg(), "image/jpeg")},
    )
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    app.dependency_overrides.pop(get_storage, None)

    assert response.status_code == 404
