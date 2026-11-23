"""Real round-trip against object storage — no mocks.

Run: pytest tests/test_storage_roundtrip.py -v -m integration
Requires: a reachable MinIO/S3 with credentials in the environment.

Everything else in the suite mocks storage: `test_storage.py` asserts that
`upload_file` calls `put_object`, and `test_photos.py` says so in its own
docstring ("MinIO is mocked — no real storage calls"). Both are the right shape
for unit tests and neither can tell you whether a photo actually lands in a
bucket and comes back out, which is the thing that has been "blocked" on this
project for months.

These tests go through the public URL rather than a credentialed GET on purpose.
`PhotoRead` hands clients a `public_url`, so a bucket whose policy denies
anonymous `s3:GetObject` would serve nothing — and a credentialed read would
pass anyway, hiding it.
"""
import uuid

import httpx
import pytest

from app.config import settings
from app.services.storage import StorageService

pytestmark = pytest.mark.integration

PNG_1PX = bytes.fromhex(
    "89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4"
    "890000000a49444154789c63000100000500010d0a2db40000000049454e44ae426082"
)


def _storage_configured() -> bool:
    return bool(
        settings.minio_endpoint
        and settings.minio_access_key
        and settings.minio_secret_key
    )


requires_storage = pytest.mark.skipif(
    not _storage_configured(),
    reason="object storage not configured (minio_endpoint / access key / secret key)",
)


@pytest.fixture
def key() -> str:
    return f"tests/roundtrip/{uuid.uuid4()}.png"


@requires_storage
async def test_object_survives_upload_and_is_publicly_readable(key: str):
    """Upload, then fetch over HTTP exactly as a client would."""
    storage = StorageService()
    await storage.ensure_bucket_exists()
    await storage.upload_file(key, PNG_1PX, "image/png")

    try:
        url = storage.public_url(key)
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(url)

        assert resp.status_code == 200, (
            f"{url} returned {resp.status_code}. A 403 here means the bucket policy "
            f"does not grant anonymous s3:GetObject, so photo URLs will not serve."
        )
        assert resp.content == PNG_1PX, "bytes differ from what was uploaded"
        assert resp.headers.get("content-type") == "image/png"
    finally:
        await storage.delete_file(key)


@requires_storage
async def test_delete_actually_removes_the_object(key: str):
    """Deleting a photo record must not leave the object behind."""
    storage = StorageService()
    await storage.ensure_bucket_exists()
    await storage.upload_file(key, PNG_1PX, "image/png")
    url = storage.public_url(key)

    async with httpx.AsyncClient(timeout=15) as client:
        assert (await client.get(url)).status_code == 200, "setup failed: not readable"
        await storage.delete_file(key)
        after = await client.get(url)

    assert after.status_code in (403, 404), (
        f"object still served {after.status_code} after delete_file; orphaned objects "
        f"accumulate and CLAUDE.md requires storage and DB to stay in step"
    )


@requires_storage
async def test_ensure_bucket_exists_is_idempotent():
    """It runs on every boot, so a second call must not fail."""
    storage = StorageService()
    await storage.ensure_bucket_exists()
    await storage.ensure_bucket_exists()
