import pytest
from unittest.mock import AsyncMock, MagicMock, patch


def test_storage_importable():
    from app.services.storage import StorageService, get_storage
    svc = get_storage()
    assert isinstance(svc, StorageService)


def test_public_url_format():
    from app.services.storage import StorageService
    svc = StorageService()
    url = svc.public_url("photos/user_1/trip_1/photo_1.jpg")
    assert "photos/user_1/trip_1/photo_1.jpg" in url


@pytest.mark.asyncio
async def test_upload_file_calls_put_object():
    from app.services.storage import StorageService

    svc = StorageService()
    mock_client = AsyncMock()
    mock_client.put_object = AsyncMock(return_value={})

    with patch.object(svc, "_make_client") as mock_make:
        mock_ctx = MagicMock()
        mock_ctx.__aenter__ = AsyncMock(return_value=mock_client)
        mock_ctx.__aexit__ = AsyncMock(return_value=False)
        mock_make.return_value = mock_ctx

        await svc.upload_file("photos/test.jpg", b"data", "image/jpeg")
        mock_client.put_object.assert_called_once()
        call_kwargs = mock_client.put_object.call_args[1]
        assert call_kwargs["Key"] == "photos/test.jpg"
        assert call_kwargs["Body"] == b"data"


def test_photo_schema_has_url_fields():
    from app.schemas.photo import PhotoRead
    fields = set(PhotoRead.model_fields.keys())
    assert {"id", "trip_id", "storage_key", "url", "thumbnail_url", "is_cover"}.issubset(fields)
