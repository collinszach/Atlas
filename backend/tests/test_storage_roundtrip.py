"""Real round-trip against object storage — no mocks.

Run: pytest tests/test_storage_roundtrip.py -v -m integration
Requires: a reachable MinIO/S3 with credentials in the environment.

Everything else in the suite mocks storage: `test_storage.py` asserts that
`upload_file` calls `put_object`, and `test_photos.py` says so in its own
docstring ("MinIO is mocked — no real storage calls"). Both are the right shape
for unit tests and neither can tell you whether a photo actually lands in a
bucket and comes back out, which is the thing that has been "blocked" on this
project for months.

The two halves are separate tests because they are reachable from different
places, which one combined test cannot express:

* the credentialed round-trip needs `minio_endpoint`, which is `atlas-minio:9000`
  — container-internal, so this runs inside `atlas-backend`;
* the public-URL check needs `minio_public_url`, the tailnet address clients
  fetch from — which the container cannot route to, so it skips there and runs
  from a tailnet host instead.

The public check exists because `PhotoRead` hands clients a `public_url`: a
bucket whose policy denied anonymous `s3:GetObject` would serve nothing, and a
credentialed read would pass anyway and hide it.

Verified across both on 2026-11-23: uploaded from the container, fetched from a
tailnet Mac (200, bytes and content-type intact), deleted, then 404.
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


def _public_url_reachable() -> bool:
    try:
        httpx.get(f"{settings.minio_public_url}/minio/health/live", timeout=3)
        return True
    except Exception:
        return False


@requires_storage
async def test_credentialed_round_trip(key: str):
    """Put, read back, delete, confirm gone — over the S3 API the backend uses."""
    storage = StorageService()
    await storage.ensure_bucket_exists()
    await storage.upload_file(key, PNG_1PX, "image/png")

    # StorageService has no download method; this is the client it uploads with.
    async with storage._make_client() as client:
        obj = await client.get_object(Bucket=settings.minio_bucket_photos, Key=key)
        body = await obj["Body"].read()
    assert body == PNG_1PX, "bytes differ from what was uploaded"

    await storage.delete_file(key)

    with pytest.raises(Exception):
        async with storage._make_client() as client:
            await client.get_object(Bucket=settings.minio_bucket_photos, Key=key)


@requires_storage
@pytest.mark.skipif(
    not _public_url_reachable(),
    reason="minio_public_url not reachable from here (expected inside atlas-backend; "
           "run from a tailnet host to exercise it)",
)
async def test_public_url_serves_the_object(key: str):
    """What a client actually does: fetch the URL PhotoRead hands out."""
    storage = StorageService()
    await storage.ensure_bucket_exists()
    await storage.upload_file(key, PNG_1PX, "image/png")

    try:
        url = storage.public_url(key)
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.get(url)
        assert resp.status_code == 200, (
            f"{url} returned {resp.status_code}. A 403 means the bucket policy does "
            f"not grant anonymous s3:GetObject, so photo URLs will not serve."
        )
        assert resp.content == PNG_1PX
        assert resp.headers.get("content-type") == "image/png"
    finally:
        await storage.delete_file(key)


@requires_storage
async def test_ensure_bucket_exists_is_idempotent():
    """It runs on every boot, so a second call must not fail."""
    storage = StorageService()
    await storage.ensure_bucket_exists()
    await storage.ensure_bucket_exists()
