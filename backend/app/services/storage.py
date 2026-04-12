import json
import logging
from typing import AsyncContextManager

import aiobotocore.session

from app.config import settings

logger = logging.getLogger(__name__)

_storage: "StorageService | None" = None


def get_storage() -> "StorageService":
    global _storage
    if _storage is None:
        _storage = StorageService()
    return _storage


class StorageService:
    """MinIO/S3-compatible object storage abstraction."""

    def __init__(self) -> None:
        self._aioboto_session = aiobotocore.session.get_session()

    def _make_client(self) -> AsyncContextManager:
        return self._aioboto_session.create_client(
            "s3",
            endpoint_url=f"http://{settings.minio_endpoint}",
            aws_access_key_id=settings.minio_access_key,
            aws_secret_access_key=settings.minio_secret_key,
            region_name="us-east-1",
        )

    def public_url(self, key: str) -> str:
        return f"{settings.minio_public_url}/{settings.minio_bucket_photos}/{key}"

    async def ensure_bucket_exists(self) -> None:
        """Create bucket and set public-read policy if it doesn't exist."""
        bucket = settings.minio_bucket_photos
        policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Principal": {"AWS": "*"},
                    "Action": "s3:GetObject",
                    "Resource": f"arn:aws:s3:::{bucket}/*",
                }
            ],
        }
        async with self._make_client() as client:
            try:
                await client.head_bucket(Bucket=bucket)
            except Exception:
                await client.create_bucket(Bucket=bucket)
                logger.info("Created MinIO bucket: %s", bucket)
            try:
                await client.put_bucket_policy(
                    Bucket=bucket, Policy=json.dumps(policy)
                )
            except Exception as exc:
                logger.warning("Could not set bucket policy on %s: %s", bucket, exc)

    async def upload_file(self, key: str, data: bytes, content_type: str) -> None:
        async with self._make_client() as client:
            await client.put_object(
                Bucket=settings.minio_bucket_photos,
                Key=key,
                Body=data,
                ContentType=content_type,
            )

    async def delete_file(self, key: str) -> None:
        async with self._make_client() as client:
            await client.delete_object(
                Bucket=settings.minio_bucket_photos,
                Key=key,
            )
