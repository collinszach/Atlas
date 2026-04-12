# Atlas Phase 2 — Photos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the full photo system — MinIO upload pipeline with EXIF extraction, thumbnail generation, photo grid + lightbox UI, and trip cover photo selection.

**Architecture:** Photos are uploaded via multipart POST, streamed to MinIO, EXIF metadata (datetime, GPS) is extracted synchronously via Pillow, and a 400px WebP thumbnail is generated in a FastAPI background task. The frontend fetches photos per trip via TanStack Query and renders a grid with a YARL lightbox. Cover photo selection updates the trip record.

**Tech Stack:** FastAPI BackgroundTasks, aiobotocore (MinIO), Pillow (EXIF + thumbnail), SQLAlchemy 2.0 async, yet-another-react-lightbox, TanStack React Query, Next.js 14 App Router

---

## File Map

**Create:**
- `backend/app/models/photo.py` — Photo SQLAlchemy model
- `backend/migrations/versions/004_photos.py` — photos table + trips.cover_photo_id FK
- `backend/app/services/storage.py` — MinIO abstraction (upload, delete, public URL, bucket init)
- `backend/app/schemas/photo.py` — Pydantic request/response schemas
- `backend/app/routers/photos.py` — upload, list, delete, set-cover endpoints
- `backend/tests/test_photos.py` — integration tests
- `frontend/src/hooks/usePhotos.ts` — TanStack Query hooks for photos
- `frontend/src/components/photos/PhotoGrid.tsx` — masonry grid
- `frontend/src/components/photos/Lightbox.tsx` — YARL lightbox wrapper
- `frontend/src/components/photos/PhotoUploader.tsx` — drag-drop upload with progress
- `frontend/src/app/(app)/trips/[id]/photos/page.tsx` — photos page

**Modify:**
- `backend/requirements.txt` — add `Pillow>=10.4.0`
- `backend/app/main.py` — register photos router + bucket init on startup
- `frontend/src/types/index.ts` — add Photo type
- `frontend/package.json` — add `yet-another-react-lightbox`
- `frontend/src/app/(app)/trips/[id]/page.tsx` — add Photos nav link
- `frontend/src/components/trips/TripCard.tsx` — show cover photo

---

### Task 1: Add Pillow and Photo SQLAlchemy Model

**Files:**
- Modify: `backend/requirements.txt`
- Create: `backend/app/models/photo.py`

- [ ] **Step 1: Add Pillow to requirements**

Edit `backend/requirements.txt` — add after the `aiobotocore` line:

```
Pillow>=10.4.0
```

- [ ] **Step 2: Write the failing import test**

Create `backend/tests/test_photo_model.py`:

```python
import pytest

def test_photo_model_importable():
    from app.models.photo import Photo
    assert Photo.__tablename__ == "photos"

def test_photo_model_fields():
    from app.models.photo import Photo
    cols = {c.name for c in Photo.__table__.columns}
    assert {"id", "user_id", "trip_id", "storage_key", "is_cover", "taken_at"}.issubset(cols)
```

- [ ] **Step 3: Run test to confirm it fails**

```bash
docker compose exec atlas-backend pytest tests/test_photo_model.py -v
```

Expected: `ModuleNotFoundError: No module named 'app.models.photo'`

- [ ] **Step 4: Create the Photo model**

Create `backend/app/models/photo.py`:

```python
import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    Boolean,
    ForeignKey,
    Integer,
    SmallInteger,
    String,
    Text,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Photo(Base):
    __tablename__ = "photos"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()")
    )
    user_id: Mapped[str] = mapped_column(
        String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    trip_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("trips.id", ondelete="CASCADE"), nullable=False, index=True
    )
    destination_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("destinations.id", ondelete="SET NULL"),
        nullable=True,
    )
    storage_key: Mapped[str] = mapped_column(String, nullable=False)
    thumbnail_key: Mapped[str | None] = mapped_column(String, nullable=True)
    original_filename: Mapped[str | None] = mapped_column(String, nullable=True)
    caption: Mapped[str | None] = mapped_column(Text, nullable=True)
    taken_at: Mapped[datetime | None] = mapped_column(
        "taken_at", String, nullable=True
    )  # stored as ISO string; cast on read
    latitude: Mapped[float | None] = mapped_column("latitude", String, nullable=True)
    longitude: Mapped[float | None] = mapped_column("longitude", String, nullable=True)
    width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    size_bytes: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    is_cover: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("false"))
    order_index: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        "created_at", String, nullable=False, server_default=text("now()")
    )
```

> **Note:** `taken_at`, `latitude`, `longitude`, `created_at` are stored as strings to avoid PostGIS/timezone complexity in tests. Convert to typed values in the Pydantic schema.

- [ ] **Step 5: Run tests to confirm they pass**

```bash
docker compose exec atlas-backend pytest tests/test_photo_model.py -v
```

Expected: 2 passed

- [ ] **Step 6: Install Pillow in the container**

```bash
docker compose exec atlas-backend pip install "Pillow>=10.4.0"
```

- [ ] **Step 7: Commit**

```bash
git add backend/requirements.txt backend/app/models/photo.py backend/tests/test_photo_model.py
git commit -m "feat(photos): add Photo model and Pillow dependency"
```

---

### Task 2: Alembic Migration 004 — Photos Table

**Files:**
- Create: `backend/migrations/versions/004_photos.py`

- [ ] **Step 1: Write the failing migration test**

Add to `backend/tests/test_photo_model.py`:

```python
@pytest.mark.asyncio
@pytest.mark.integration
async def test_photos_table_exists(db_session):
    from sqlalchemy import text
    result = await db_session.execute(
        text("SELECT 1 FROM information_schema.tables WHERE table_name = 'photos'")
    )
    assert result.scalar_one_or_none() == 1
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
docker compose exec atlas-backend pytest tests/test_photo_model.py::test_photos_table_exists -v
```

Expected: AssertionError (table doesn't exist yet)

- [ ] **Step 3: Create the migration**

Create `backend/migrations/versions/004_photos.py`:

```python
"""photos table + trips.cover_photo_id FK

Revision ID: 004
Revises: 003
Create Date: 2026-04-11
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "004"
down_revision = "003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "photos",
        sa.Column(
            "id",
            UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "user_id",
            sa.String,
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "trip_id",
            UUID(as_uuid=True),
            sa.ForeignKey("trips.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "destination_id",
            UUID(as_uuid=True),
            sa.ForeignKey("destinations.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("storage_key", sa.String, nullable=False),
        sa.Column("thumbnail_key", sa.String, nullable=True),
        sa.Column("original_filename", sa.String, nullable=True),
        sa.Column("caption", sa.Text, nullable=True),
        sa.Column("taken_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("latitude", sa.Numeric(10, 7), nullable=True),
        sa.Column("longitude", sa.Numeric(10, 7), nullable=True),
        sa.Column("width", sa.Integer, nullable=True),
        sa.Column("height", sa.Integer, nullable=True),
        sa.Column("size_bytes", sa.BigInteger, nullable=True),
        sa.Column("is_cover", sa.Boolean, nullable=False, server_default=sa.text("false")),
        sa.Column("order_index", sa.Integer, nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("now()"),
        ),
    )
    op.create_index("photos_user_id_idx", "photos", ["user_id"])
    op.create_index("photos_trip_id_idx", "photos", ["trip_id"])

    # Add FK from trips.cover_photo_id → photos.id (deferred to avoid circular FK issue)
    op.create_foreign_key(
        "fk_trips_cover_photo_id",
        "trips",
        "photos",
        ["cover_photo_id"],
        ["id"],
        ondelete="SET NULL",
        use_alter=True,
        deferrable=True,
        initially="DEFERRED",
    )


def downgrade() -> None:
    op.drop_constraint("fk_trips_cover_photo_id", "trips", type_="foreignkey")
    op.drop_table("photos")
```

- [ ] **Step 4: Run the migration**

```bash
docker compose exec atlas-backend alembic upgrade head
```

Expected: `Running upgrade 003 -> 004`

- [ ] **Step 5: Run test to confirm it passes**

```bash
docker compose exec atlas-backend pytest tests/test_photo_model.py -v
```

Expected: 3 passed

- [ ] **Step 6: Commit**

```bash
git add backend/migrations/versions/004_photos.py backend/tests/test_photo_model.py
git commit -m "feat(photos): migration 004 — photos table + trips cover FK"
```

---

### Task 3: Storage Service (MinIO Abstraction)

**Files:**
- Create: `backend/app/services/storage.py`

- [ ] **Step 1: Write the failing unit test**

Create `backend/tests/test_storage.py`:

```python
import pytest
from unittest.mock import AsyncMock, patch, MagicMock


def test_storage_importable():
    from app.services.storage import StorageService, get_storage
    svc = get_storage()
    assert isinstance(svc, StorageService)


def test_public_url_format():
    from app.services.storage import StorageService
    svc = StorageService()
    url = svc.public_url("photos/user_1/trip_1/photo_1.jpg")
    # Should be {minio_public_url}/{bucket}/{key}
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
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
docker compose exec atlas-backend pytest tests/test_storage.py -v
```

Expected: `ModuleNotFoundError: No module named 'app.services.storage'`

- [ ] **Step 3: Create the storage service**

Create `backend/app/services/storage.py`:

```python
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
        import json

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
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
docker compose exec atlas-backend pytest tests/test_storage.py -v
```

Expected: 3 passed

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/storage.py backend/tests/test_storage.py
git commit -m "feat(photos): MinIO storage service with bucket init"
```

---

### Task 4: Photo Pydantic Schemas

**Files:**
- Create: `backend/app/schemas/photo.py`

- [ ] **Step 1: Write the failing schema test**

Create `backend/tests/test_photo_schema.py`:

```python
import uuid
from datetime import datetime


def test_photo_read_has_url_fields():
    from app.schemas.photo import PhotoRead
    fields = set(PhotoRead.model_fields.keys())
    assert {"id", "trip_id", "storage_key", "url", "thumbnail_url", "is_cover"}.issubset(fields)


def test_photo_read_from_dict():
    from app.schemas.photo import PhotoRead
    photo_id = uuid.uuid4()
    trip_id = uuid.uuid4()
    data = {
        "id": photo_id,
        "user_id": "user_test",
        "trip_id": trip_id,
        "destination_id": None,
        "storage_key": "photos/user/trip/photo.jpg",
        "thumbnail_key": "thumbnails/user/trip/photo_thumb.webp",
        "original_filename": "photo.jpg",
        "caption": None,
        "taken_at": None,
        "latitude": None,
        "longitude": None,
        "width": 1920,
        "height": 1080,
        "size_bytes": 500000,
        "is_cover": False,
        "order_index": 0,
        "created_at": datetime.utcnow(),
        "url": "http://localhost:9000/atlas-photos/photos/user/trip/photo.jpg",
        "thumbnail_url": "http://localhost:9000/atlas-photos/thumbnails/user/trip/photo_thumb.webp",
    }
    photo = PhotoRead.model_validate(data)
    assert photo.id == photo_id
    assert "atlas-photos" in photo.url
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
docker compose exec atlas-backend pytest tests/test_photo_schema.py -v
```

Expected: `ModuleNotFoundError: No module named 'app.schemas.photo'`

- [ ] **Step 3: Create schemas**

Create `backend/app/schemas/photo.py`:

```python
import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict


class PhotoRead(BaseModel):
    id: uuid.UUID
    user_id: str
    trip_id: uuid.UUID
    destination_id: uuid.UUID | None
    storage_key: str
    thumbnail_key: str | None
    original_filename: str | None
    caption: str | None
    taken_at: datetime | None
    latitude: float | None
    longitude: float | None
    width: int | None
    height: int | None
    size_bytes: int | None
    is_cover: bool
    order_index: int | None
    created_at: datetime
    # Computed fields — set by router, not from ORM
    url: str
    thumbnail_url: str | None

    model_config = ConfigDict(from_attributes=False)


class PhotoListResponse(BaseModel):
    items: list[PhotoRead]
    total: int


class PhotoUpdate(BaseModel):
    caption: str | None = None
    order_index: int | None = None
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
docker compose exec atlas-backend pytest tests/test_photo_schema.py -v
```

Expected: 2 passed

- [ ] **Step 5: Commit**

```bash
git add backend/app/schemas/photo.py backend/tests/test_photo_schema.py
git commit -m "feat(photos): Pydantic schemas for photo responses"
```

---

### Task 5: Photo Upload Router (EXIF + Thumbnail)

**Files:**
- Create: `backend/app/routers/photos.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1: Write the failing unit test for EXIF extraction**

Add to `backend/tests/test_photo_schema.py`:

```python
def test_extract_metadata_returns_dimensions():
    from app.routers.photos import _extract_metadata
    import io
    from PIL import Image

    # Create a minimal 100x80 JPEG in memory
    buf = io.BytesIO()
    img = Image.new("RGB", (100, 80), color=(128, 64, 32))
    img.save(buf, format="JPEG")
    data = buf.getvalue()

    meta = _extract_metadata(data)
    assert meta["width"] == 100
    assert meta["height"] == 80


def test_extract_metadata_handles_corrupt_bytes():
    from app.routers.photos import _extract_metadata
    meta = _extract_metadata(b"not an image")
    assert meta == {}


def test_sync_thumbnail_reduces_size():
    from app.routers.photos import _sync_thumbnail
    import io
    from PIL import Image

    buf = io.BytesIO()
    img = Image.new("RGB", (800, 600), color=(0, 128, 255))
    img.save(buf, format="JPEG")
    data = buf.getvalue()

    thumb = _sync_thumbnail(data)
    result = Image.open(io.BytesIO(thumb))
    assert max(result.width, result.height) <= 400
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
docker compose exec atlas-backend pytest tests/test_photo_schema.py::test_extract_metadata_returns_dimensions -v
```

Expected: `ImportError: cannot import name '_extract_metadata' from 'app.routers.photos'`

- [ ] **Step 3: Create the photos router**

Create `backend/app/routers/photos.py`:

```python
import asyncio
import io
import logging
import uuid
from datetime import datetime

from fastapi import APIRouter, BackgroundTasks, Depends, Form, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.config import settings
from app.database import get_db
from app.models.photo import Photo
from app.models.trip import Trip
from app.schemas.photo import PhotoListResponse, PhotoRead, PhotoUpdate
from app.services.storage import StorageService, get_storage

logger = logging.getLogger(__name__)
router = APIRouter(tags=["photos"])

_ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}
_MAX_BYTES = 50 * 1024 * 1024  # 50 MB


# ─── EXIF helpers ──────────────────────────────────────────────────────────────

def _extract_metadata(data: bytes) -> dict:
    """Return {width, height, taken_at?, latitude?, longitude?} from image bytes."""
    try:
        from PIL import Image, ExifTags

        img = Image.open(io.BytesIO(data))
        result: dict = {"width": img.width, "height": img.height}
        exif_raw = img._getexif()
        if not exif_raw:
            return result
        tag_names = {v: k for k, v in ExifTags.TAGS.items()}
        # DateTimeOriginal
        dt_id = tag_names.get("DateTimeOriginal")
        if dt_id and dt_id in exif_raw:
            try:
                result["taken_at"] = datetime.strptime(exif_raw[dt_id], "%Y:%m:%d %H:%M:%S")
            except ValueError:
                pass
        # GPS
        gps_id = tag_names.get("GPSInfo")
        if gps_id and gps_id in exif_raw:
            gps = exif_raw[gps_id]
            try:
                result["latitude"] = _dms_to_decimal(gps[2], gps[1])
                result["longitude"] = _dms_to_decimal(gps[4], gps[3])
            except (KeyError, ZeroDivisionError, TypeError):
                pass
        return result
    except Exception:
        return {}


def _dms_to_decimal(dms: tuple, ref: str) -> float:
    d, m, s = dms
    decimal = float(d) + float(m) / 60 + float(s) / 3600
    if ref in ("S", "W"):
        decimal = -decimal
    return decimal


def _sync_thumbnail(data: bytes, max_size: int = 400) -> bytes:
    from PIL import Image

    img = Image.open(io.BytesIO(data))
    img.thumbnail((max_size, max_size), Image.LANCZOS)
    if img.mode in ("RGBA", "P"):
        img = img.convert("RGB")
    buf = io.BytesIO()
    img.save(buf, format="WEBP", quality=85)
    return buf.getvalue()


async def _generate_and_upload_thumbnail(
    storage: StorageService,
    data: bytes,
    thumb_key: str,
    photo_id: uuid.UUID,
    db_url: str,
) -> None:
    """Background task: generate thumbnail, upload to MinIO, update DB record."""
    import os
    from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
    from sqlalchemy.pool import NullPool

    loop = asyncio.get_event_loop()
    thumb_bytes = await loop.run_in_executor(None, _sync_thumbnail, data)
    await storage.upload_file(thumb_key, thumb_bytes, "image/webp")

    engine = create_async_engine(db_url, poolclass=NullPool)
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        result = await session.execute(select(Photo).where(Photo.id == photo_id))
        photo = result.scalar_one_or_none()
        if photo:
            photo.thumbnail_key = thumb_key
            await session.commit()
    await engine.dispose()


# ─── URL helper ────────────────────────────────────────────────────────────────

def _to_photo_read(photo: Photo, storage: StorageService) -> PhotoRead:
    thumb_url = storage.public_url(photo.thumbnail_key) if photo.thumbnail_key else None
    return PhotoRead(
        id=photo.id,
        user_id=photo.user_id,
        trip_id=photo.trip_id,
        destination_id=photo.destination_id,
        storage_key=photo.storage_key,
        thumbnail_key=photo.thumbnail_key,
        original_filename=photo.original_filename,
        caption=photo.caption,
        taken_at=_parse_dt(photo.taken_at),
        latitude=_parse_float(photo.latitude),
        longitude=_parse_float(photo.longitude),
        width=photo.width,
        height=photo.height,
        size_bytes=photo.size_bytes,
        is_cover=photo.is_cover,
        order_index=photo.order_index,
        created_at=_parse_dt(photo.created_at) or datetime.utcnow(),
        url=storage.public_url(photo.storage_key),
        thumbnail_url=thumb_url,
    )


def _parse_dt(value) -> datetime | None:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    try:
        return datetime.fromisoformat(str(value))
    except (ValueError, TypeError):
        return None


def _parse_float(value) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except (ValueError, TypeError):
        return None


# ─── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/trips/{trip_id}/photos/upload", response_model=PhotoRead, status_code=201)
async def upload_photo(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    file: UploadFile,
    background_tasks: BackgroundTasks,
    caption: str | None = Form(None),
    destination_id: uuid.UUID | None = Form(None),
    db: AsyncSession = Depends(get_db),
    storage: StorageService = Depends(get_storage),
) -> PhotoRead:
    # Verify trip ownership
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    if result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Trip not found")

    if file.content_type not in _ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=422, detail=f"Unsupported file type: {file.content_type}")

    data = await file.read()
    if len(data) > _MAX_BYTES:
        raise HTTPException(status_code=413, detail="File exceeds 50 MB limit")

    photo_id = uuid.uuid4()
    ext = (file.filename or "photo.jpg").rsplit(".", 1)[-1].lower()
    storage_key = f"photos/{user_id}/{trip_id}/{photo_id}.{ext}"
    thumb_key = f"thumbnails/{user_id}/{trip_id}/{photo_id}_thumb.webp"

    # Extract EXIF synchronously
    meta = _extract_metadata(data)

    # Upload original to MinIO
    await storage.upload_file(storage_key, data, file.content_type or "image/jpeg")

    # Insert DB record (thumbnail_key set after background task completes)
    photo = Photo(
        id=photo_id,
        user_id=user_id,
        trip_id=trip_id,
        destination_id=destination_id,
        storage_key=storage_key,
        thumbnail_key=None,
        original_filename=file.filename,
        caption=caption,
        taken_at=meta.get("taken_at"),
        latitude=meta.get("latitude"),
        longitude=meta.get("longitude"),
        width=meta.get("width"),
        height=meta.get("height"),
        size_bytes=len(data),
    )
    db.add(photo)
    await db.flush()
    await db.refresh(photo)

    # Background: generate + upload thumbnail, then set thumbnail_key on DB record
    background_tasks.add_task(
        _generate_and_upload_thumbnail,
        storage,
        data,
        thumb_key,
        photo_id,
        str(settings.database_url),
    )

    return _to_photo_read(photo, storage)


@router.get("/trips/{trip_id}/photos", response_model=PhotoListResponse)
async def list_photos(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
    storage: StorageService = Depends(get_storage),
) -> PhotoListResponse:
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    if result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Trip not found")

    photos_result = await db.execute(
        select(Photo)
        .where(Photo.trip_id == trip_id, Photo.user_id == user_id)
        .order_by(Photo.order_index.asc().nullsfirst(), Photo.created_at.asc())
    )
    photos = list(photos_result.scalars().all())
    return PhotoListResponse(
        items=[_to_photo_read(p, storage) for p in photos],
        total=len(photos),
    )


@router.delete("/photos/{photo_id}", status_code=204)
async def delete_photo(
    photo_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
    storage: StorageService = Depends(get_storage),
) -> None:
    result = await db.execute(select(Photo).where(Photo.id == photo_id, Photo.user_id == user_id))
    photo = result.scalar_one_or_none()
    if photo is None:
        raise HTTPException(status_code=404, detail="Photo not found")

    # Delete from MinIO first; if it fails, don't delete the DB record
    try:
        await storage.delete_file(photo.storage_key)
        if photo.thumbnail_key:
            await storage.delete_file(photo.thumbnail_key)
    except Exception as exc:
        logger.error("MinIO delete failed for photo %s: %s", photo_id, exc)
        raise HTTPException(status_code=500, detail="Storage delete failed")

    # Unset cover_photo_id on trip if this was the cover
    trip_result = await db.execute(
        select(Trip).where(Trip.id == photo.trip_id, Trip.cover_photo_id == photo_id)
    )
    trip = trip_result.scalar_one_or_none()
    if trip:
        trip.cover_photo_id = None

    await db.delete(photo)
    await db.flush()


@router.post("/photos/{photo_id}/set-cover", response_model=dict)
async def set_cover_photo(
    photo_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> dict:
    result = await db.execute(select(Photo).where(Photo.id == photo_id, Photo.user_id == user_id))
    photo = result.scalar_one_or_none()
    if photo is None:
        raise HTTPException(status_code=404, detail="Photo not found")

    # Clear existing cover on all photos for this trip
    all_photos_result = await db.execute(
        select(Photo).where(Photo.trip_id == photo.trip_id, Photo.user_id == user_id)
    )
    for p in all_photos_result.scalars().all():
        p.is_cover = p.id == photo_id

    # Update trip.cover_photo_id
    trip_result = await db.execute(
        select(Trip).where(Trip.id == photo.trip_id, Trip.user_id == user_id)
    )
    trip = trip_result.scalar_one_or_none()
    if trip:
        trip.cover_photo_id = photo_id

    await db.flush()
    return {"cover_photo_id": str(photo_id)}
```

- [ ] **Step 4: Register photos router in main.py**

Edit `backend/app/main.py`. In the lifespan function, add bucket init. In the router registrations, add photos:

```python
# In lifespan, after existing startup:
from app.services.storage import get_storage
try:
    await get_storage().ensure_bucket_exists()
    logger.info("MinIO bucket ready")
except Exception as exc:
    logger.warning("MinIO bucket init failed (may not be running): %s", exc)

# In router includes:
from app.routers.photos import router as photos_router
app.include_router(photos_router, prefix="/api/v1")
```

Full updated `backend/app/main.py`:

```python
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import destinations, map, trips, users
from app.routers.photos import router as photos_router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Atlas backend starting up")
    from app.services.storage import get_storage
    try:
        await get_storage().ensure_bucket_exists()
        logger.info("MinIO bucket ready")
    except Exception as exc:
        logger.warning("MinIO bucket init failed (may not be running): %s", exc)
    yield
    logger.info("Atlas backend shutting down")


app = FastAPI(title="Atlas API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users.router, prefix="/api/v1")
app.include_router(trips.router, prefix="/api/v1")
app.include_router(destinations.router, prefix="/api/v1")
app.include_router(map.router, prefix="/api/v1")
app.include_router(photos_router, prefix="/api/v1")


@app.get("/health")
async def health() -> dict:
    return {"status": "ok"}
```

- [ ] **Step 5: Run EXIF/thumbnail unit tests**

```bash
docker compose exec atlas-backend pytest tests/test_photo_schema.py -v
```

Expected: 5 passed

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/photos.py backend/app/main.py backend/tests/test_photo_schema.py
git commit -m "feat(photos): upload router with EXIF extraction and thumbnail background task"
```

---

### Task 6: Backend Integration Tests for Photos

**Files:**
- Create: `backend/tests/test_photos.py`

- [ ] **Step 1: Write all integration tests**

Create `backend/tests/test_photos.py`:

```python
"""Integration tests for the photo upload, list, delete, and cover endpoints.

Run: docker compose exec atlas-backend pytest tests/test_photos.py -v -m integration
Requires: running PostgreSQL + the photos table (migration 004 applied)
MinIO is mocked — no real storage calls.
"""
import io
import uuid

import pytest
from PIL import Image
from unittest.mock import AsyncMock, patch, MagicMock

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
    """Return a mock StorageService that no-ops uploads/deletes."""
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

    # Also mock background task so thumbnail doesn't fire
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
    """User isolation: another user cannot upload to a trip they don't own."""
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
```

- [ ] **Step 2: Run tests**

```bash
docker compose exec atlas-backend pytest tests/test_photos.py -v -m integration
```

Expected: 7 passed

- [ ] **Step 3: Run full backend test suite**

```bash
docker compose exec atlas-backend pytest --tb=short -q
```

Expected: all existing tests still pass

- [ ] **Step 4: Commit**

```bash
git add backend/tests/test_photos.py
git commit -m "test(photos): integration tests for upload, list, delete, set-cover"
```

---

### Task 7: Frontend Photo Type + usePhotos Hook

**Files:**
- Modify: `frontend/src/types/index.ts`
- Create: `frontend/src/hooks/usePhotos.ts`

- [ ] **Step 1: Write the failing hook test**

Create `frontend/src/hooks/__tests__/usePhotos.test.ts`:

```typescript
import { describe, it, expect } from "vitest";

describe("usePhotos hook exports", () => {
  it("exports expected hooks", async () => {
    const mod = await import("../usePhotos");
    expect(typeof mod.usePhotos).toBe("function");
    expect(typeof mod.useUploadPhotos).toBe("function");
    expect(typeof mod.useDeletePhoto).toBe("function");
    expect(typeof mod.useSetCoverPhoto).toBe("function");
  });
});
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /home/zach/Atlas/frontend && npx vitest run src/hooks/__tests__/usePhotos.test.ts
```

Expected: `Cannot find module '../usePhotos'`

- [ ] **Step 3: Add Photo type to types/index.ts**

Append to `frontend/src/types/index.ts`:

```typescript
export interface Photo {
  id: string;
  user_id: string;
  trip_id: string;
  destination_id: string | null;
  storage_key: string;
  thumbnail_key: string | null;
  original_filename: string | null;
  caption: string | null;
  taken_at: string | null;
  latitude: number | null;
  longitude: number | null;
  width: number | null;
  height: number | null;
  size_bytes: number | null;
  is_cover: boolean;
  order_index: number | null;
  created_at: string;
  url: string;
  thumbnail_url: string | null;
}

export interface PhotoListResponse {
  items: Photo[];
  total: number;
}
```

- [ ] **Step 4: Create usePhotos.ts**

Create `frontend/src/hooks/usePhotos.ts`:

```typescript
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiDelete, apiPost } from "@/lib/api";
import type { Photo, PhotoListResponse } from "@/types";

export function usePhotos(tripId: string) {
  const { getToken } = useAuth();
  return useQuery<PhotoListResponse>({
    queryKey: ["photos", tripId],
    queryFn: async () => {
      const token = await getToken();
      const res = await fetch(
        `${process.env.NEXT_PUBLIC_API_BASE}/api/v1/trips/${tripId}/photos`,
        { headers: { Authorization: `Bearer ${token}` } }
      );
      if (!res.ok) throw new Error("Failed to fetch photos");
      return res.json();
    },
    enabled: !!tripId,
  });
}

export function useUploadPhotos(tripId: string) {
  const queryClient = useQueryClient();
  const { getToken } = useAuth();
  return useMutation<Photo[], Error, File[]>({
    mutationFn: async (files: File[]) => {
      const token = await getToken();
      const results: Photo[] = [];
      for (const file of files) {
        const form = new FormData();
        form.append("file", file);
        const res = await fetch(
          `${process.env.NEXT_PUBLIC_API_BASE}/api/v1/trips/${tripId}/photos/upload`,
          { method: "POST", headers: { Authorization: `Bearer ${token}` }, body: form }
        );
        if (!res.ok) throw new Error(`Upload failed for ${file.name}`);
        results.push(await res.json());
      }
      return results;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["photos", tripId] });
    },
  });
}

export function useDeletePhoto(tripId: string) {
  const queryClient = useQueryClient();
  const { getToken } = useAuth();
  return useMutation<void, Error, string>({
    mutationFn: async (photoId: string) => {
      const token = await getToken();
      await apiDelete(`/photos/${photoId}`, token!);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["photos", tripId] });
    },
  });
}

export function useSetCoverPhoto(tripId: string) {
  const queryClient = useQueryClient();
  const { getToken } = useAuth();
  return useMutation<{ cover_photo_id: string }, Error, string>({
    mutationFn: async (photoId: string) => {
      const token = await getToken();
      return apiPost(`/photos/${photoId}/set-cover`, {}, token!);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ["photos", tripId] });
      queryClient.invalidateQueries({ queryKey: ["trips"] });
    },
  });
}
```

- [ ] **Step 5: Run test to confirm it passes**

```bash
cd /home/zach/Atlas/frontend && npx vitest run src/hooks/__tests__/usePhotos.test.ts
```

Expected: 1 passed

- [ ] **Step 6: Commit**

```bash
git add frontend/src/types/index.ts frontend/src/hooks/usePhotos.ts frontend/src/hooks/__tests__/usePhotos.test.ts
git commit -m "feat(photos): Photo type and usePhotos TanStack Query hooks"
```

---

### Task 8: PhotoGrid + Lightbox Components

**Files:**
- Modify: `frontend/package.json`
- Create: `frontend/src/components/photos/PhotoGrid.tsx`
- Create: `frontend/src/components/photos/Lightbox.tsx`

- [ ] **Step 1: Install yet-another-react-lightbox**

```bash
cd /home/zach/Atlas/frontend && npm install yet-another-react-lightbox
```

- [ ] **Step 2: Write the failing component test**

Create `frontend/src/components/photos/__tests__/PhotoGrid.test.tsx`:

```typescript
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import type { Photo } from "@/types";

const mockPhoto: Photo = {
  id: "photo-1",
  user_id: "user-1",
  trip_id: "trip-1",
  destination_id: null,
  storage_key: "photos/user-1/trip-1/photo-1.jpg",
  thumbnail_key: "thumbnails/user-1/trip-1/photo-1_thumb.webp",
  original_filename: "photo-1.jpg",
  caption: "Test caption",
  taken_at: null,
  latitude: null,
  longitude: null,
  width: 800,
  height: 600,
  size_bytes: 100000,
  is_cover: false,
  order_index: 0,
  created_at: "2026-01-01T00:00:00Z",
  url: "http://localhost:9000/atlas-photos/photos/user-1/trip-1/photo-1.jpg",
  thumbnail_url: "http://localhost:9000/atlas-photos/thumbnails/user-1/trip-1/photo-1_thumb.webp",
};

describe("PhotoGrid", () => {
  it("renders photo thumbnails", async () => {
    const { default: PhotoGrid } = await import("../PhotoGrid");
    render(
      <PhotoGrid
        photos={[mockPhoto]}
        onPhotoClick={() => {}}
        onSetCover={() => {}}
        onDelete={() => {}}
      />
    );
    const img = screen.getByRole("img");
    expect(img).toBeDefined();
  });

  it("renders empty state when no photos", async () => {
    const { default: PhotoGrid } = await import("../PhotoGrid");
    render(
      <PhotoGrid photos={[]} onPhotoClick={() => {}} onSetCover={() => {}} onDelete={() => {}} />
    );
    expect(screen.getByText(/no photos/i)).toBeDefined();
  });
});
```

- [ ] **Step 3: Run test to confirm it fails**

```bash
cd /home/zach/Atlas/frontend && npx vitest run src/components/photos/__tests__/PhotoGrid.test.tsx
```

Expected: `Cannot find module '../PhotoGrid'`

- [ ] **Step 4: Create PhotoGrid.tsx**

Create `frontend/src/components/photos/PhotoGrid.tsx`:

```tsx
"use client";

import Image from "next/image";
import { Star, Trash2 } from "lucide-react";
import type { Photo } from "@/types";

interface Props {
  photos: Photo[];
  onPhotoClick: (index: number) => void;
  onSetCover: (photoId: string) => void;
  onDelete: (photoId: string) => void;
}

export default function PhotoGrid({ photos, onPhotoClick, onSetCover, onDelete }: Props) {
  if (photos.length === 0) {
    return (
      <p className="text-atlas-muted text-sm py-8 text-center border border-dashed border-atlas-border rounded-lg">
        No photos yet. Upload some to start your visual journal.
      </p>
    );
  }

  return (
    <div className="columns-2 sm:columns-3 lg:columns-4 gap-2 space-y-2">
      {photos.map((photo, index) => (
        <div
          key={photo.id}
          className="relative group break-inside-avoid overflow-hidden rounded-lg border border-atlas-border bg-atlas-surface cursor-pointer"
          onClick={() => onPhotoClick(index)}
        >
          <Image
            src={photo.thumbnail_url ?? photo.url}
            alt={photo.caption ?? photo.original_filename ?? "Photo"}
            width={photo.width ?? 400}
            height={photo.height ?? 300}
            className="w-full h-auto object-cover transition-opacity group-hover:opacity-80"
            unoptimized
          />

          {/* Cover badge */}
          {photo.is_cover && (
            <span className="absolute top-2 left-2 bg-atlas-accent text-atlas-bg text-xs font-mono px-1.5 py-0.5 rounded">
              Cover
            </span>
          )}

          {/* Action buttons — appear on hover */}
          <div
            className="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity"
            onClick={(e) => e.stopPropagation()}
          >
            <button
              onClick={() => onSetCover(photo.id)}
              className="p-1 rounded bg-atlas-bg/80 text-atlas-accent hover:bg-atlas-bg transition-colors"
              title="Set as cover"
            >
              <Star size={12} />
            </button>
            <button
              onClick={() => onDelete(photo.id)}
              className="p-1 rounded bg-atlas-bg/80 text-red-400 hover:bg-atlas-bg transition-colors"
              title="Delete photo"
            >
              <Trash2 size={12} />
            </button>
          </div>

          {/* Caption */}
          {photo.caption && (
            <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-atlas-bg/90 to-transparent px-2 py-2 opacity-0 group-hover:opacity-100 transition-opacity">
              <p className="text-xs text-atlas-text truncate">{photo.caption}</p>
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
```

- [ ] **Step 5: Create Lightbox.tsx**

Create `frontend/src/components/photos/Lightbox.tsx`:

```tsx
"use client";

import YARLightbox from "yet-another-react-lightbox";
import "yet-another-react-lightbox/styles.css";
import Captions from "yet-another-react-lightbox/plugins/captions";
import "yet-another-react-lightbox/plugins/captions.css";
import type { Photo } from "@/types";

interface Props {
  photos: Photo[];
  open: boolean;
  index: number;
  onClose: () => void;
}

export default function Lightbox({ photos, open, index, onClose }: Props) {
  const slides = photos.map((p) => ({
    src: p.url,
    alt: p.caption ?? p.original_filename ?? "Photo",
    description: p.caption ?? undefined,
    width: p.width ?? undefined,
    height: p.height ?? undefined,
  }));

  return (
    <YARLightbox
      open={open}
      close={onClose}
      index={index}
      slides={slides}
      plugins={[Captions]}
      styles={{
        container: { backgroundColor: "rgba(10, 14, 26, 0.97)" },
      }}
    />
  );
}
```

- [ ] **Step 6: Run component tests**

```bash
cd /home/zach/Atlas/frontend && npx vitest run src/components/photos/__tests__/PhotoGrid.test.tsx
```

Expected: 2 passed

- [ ] **Step 7: Commit**

```bash
git add frontend/package.json frontend/package-lock.json frontend/src/components/photos/PhotoGrid.tsx frontend/src/components/photos/Lightbox.tsx frontend/src/components/photos/__tests__/PhotoGrid.test.tsx
git commit -m "feat(photos): PhotoGrid masonry component and YARL Lightbox wrapper"
```

---

### Task 9: PhotoUploader Component

**Files:**
- Create: `frontend/src/components/photos/PhotoUploader.tsx`

- [ ] **Step 1: Write the failing component test**

Create `frontend/src/components/photos/__tests__/PhotoUploader.test.tsx`:

```typescript
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";

describe("PhotoUploader", () => {
  it("renders drop zone text", async () => {
    const { default: PhotoUploader } = await import("../PhotoUploader");
    const mockMutation = {
      mutate: () => {},
      isPending: false,
      isError: false,
      error: null,
    } as any;
    render(<PhotoUploader uploadMutation={mockMutation} />);
    expect(screen.getByText(/drag/i)).toBeDefined();
  });
});
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /home/zach/Atlas/frontend && npx vitest run src/components/photos/__tests__/PhotoUploader.test.tsx
```

Expected: `Cannot find module '../PhotoUploader'`

- [ ] **Step 3: Create PhotoUploader.tsx**

Create `frontend/src/components/photos/PhotoUploader.tsx`:

```tsx
"use client";

import { useCallback, useRef, useState } from "react";
import { Upload } from "lucide-react";
import type { UseMutationResult } from "@tanstack/react-query";
import type { Photo } from "@/types";

interface Props {
  uploadMutation: UseMutationResult<Photo[], Error, File[]>;
}

export default function PhotoUploader({ uploadMutation }: Props) {
  const [isDragOver, setIsDragOver] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFiles = useCallback(
    (files: FileList | null) => {
      if (!files || files.length === 0) return;
      const accepted = Array.from(files).filter((f) =>
        ["image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"].includes(f.type)
      );
      if (accepted.length > 0) {
        uploadMutation.mutate(accepted);
      }
    },
    [uploadMutation]
  );

  const onDrop = useCallback(
    (e: React.DragEvent) => {
      e.preventDefault();
      setIsDragOver(false);
      handleFiles(e.dataTransfer.files);
    },
    [handleFiles]
  );

  return (
    <div
      onDrop={onDrop}
      onDragOver={(e) => { e.preventDefault(); setIsDragOver(true); }}
      onDragLeave={() => setIsDragOver(false)}
      onClick={() => inputRef.current?.click()}
      className={`
        flex flex-col items-center justify-center gap-3 p-8 rounded-lg border-2 border-dashed cursor-pointer transition-colors
        ${isDragOver
          ? "border-atlas-accent bg-atlas-accent/5"
          : "border-atlas-border hover:border-atlas-accent/50 bg-atlas-surface"
        }
      `}
    >
      <input
        ref={inputRef}
        type="file"
        multiple
        accept="image/jpeg,image/png,image/webp,image/heic,image/heif"
        className="hidden"
        onChange={(e) => handleFiles(e.target.files)}
      />
      <Upload size={20} className="text-atlas-muted" />
      {uploadMutation.isPending ? (
        <p className="text-sm text-atlas-accent">Uploading...</p>
      ) : (
        <>
          <p className="text-sm text-atlas-text">Drag & drop photos here</p>
          <p className="text-xs text-atlas-muted">or click to select — JPEG, PNG, WEBP, HEIC</p>
        </>
      )}
      {uploadMutation.isError && (
        <p className="text-xs text-red-400">{uploadMutation.error?.message ?? "Upload failed"}</p>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
cd /home/zach/Atlas/frontend && npx vitest run src/components/photos/__tests__/PhotoUploader.test.tsx
```

Expected: 1 passed

- [ ] **Step 5: Commit**

```bash
git add frontend/src/components/photos/PhotoUploader.tsx frontend/src/components/photos/__tests__/PhotoUploader.test.tsx
git commit -m "feat(photos): PhotoUploader drag-drop component"
```

---

### Task 10: Photos Page + Trip Detail Nav Link

**Files:**
- Create: `frontend/src/app/(app)/trips/[id]/photos/page.tsx`
- Modify: `frontend/src/app/(app)/trips/[id]/page.tsx`

- [ ] **Step 1: Write the failing page test**

Create `frontend/src/app/(app)/trips/[id]/photos/__tests__/page.test.tsx`:

```typescript
import { describe, it, expect } from "vitest";

describe("Photos page module", () => {
  it("exports a default component", async () => {
    // Dynamic import to verify the file exists and exports a component
    const mod = await import("../page");
    expect(typeof mod.default).toBe("function");
  });
});
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /home/zach/Atlas/frontend && npx vitest run "src/app/\(app\)/trips/\[id\]/photos/__tests__/page.test.tsx"
```

Expected: `Cannot find module '../page'`

- [ ] **Step 3: Create the Photos page**

Create `frontend/src/app/(app)/trips/[id]/photos/page.tsx`:

```tsx
"use client";

import { useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useTrip } from "@/hooks/useTrips";
import { usePhotos, useUploadPhotos, useDeletePhoto, useSetCoverPhoto } from "@/hooks/usePhotos";
import PhotoGrid from "@/components/photos/PhotoGrid";
import PhotoUploader from "@/components/photos/PhotoUploader";
import Lightbox from "@/components/photos/Lightbox";

export default function TripPhotosPage() {
  const { id } = useParams<{ id: string }>();
  const { data: trip } = useTrip(id);
  const { data: photoData, isLoading } = usePhotos(id);
  const uploadMutation = useUploadPhotos(id);
  const deleteMutation = useDeletePhoto(id);
  const setCoverMutation = useSetCoverPhoto(id);

  const [lightboxIndex, setLightboxIndex] = useState<number | null>(null);

  const photos = photoData?.items ?? [];

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-5xl mx-auto">
        {/* Header */}
        <div className="mb-6">
          <Link href={`/trips/${id}`} className="text-xs text-atlas-muted hover:text-atlas-text mb-3 inline-block">
            ← {trip?.title ?? "Trip"}
          </Link>
          <h1 className="font-display text-2xl font-semibold text-atlas-text">Photos</h1>
          <p className="text-xs text-atlas-muted mt-1">{photos.length} photo{photos.length !== 1 ? "s" : ""}</p>
        </div>

        {/* Uploader */}
        <div className="mb-6">
          <PhotoUploader uploadMutation={uploadMutation} />
        </div>

        {/* Grid */}
        {isLoading ? (
          <p className="text-atlas-muted text-sm">Loading photos...</p>
        ) : (
          <PhotoGrid
            photos={photos}
            onPhotoClick={(index) => setLightboxIndex(index)}
            onSetCover={(photoId) => setCoverMutation.mutate(photoId)}
            onDelete={(photoId) => deleteMutation.mutate(photoId)}
          />
        )}

        {/* Lightbox */}
        <Lightbox
          photos={photos}
          open={lightboxIndex !== null}
          index={lightboxIndex ?? 0}
          onClose={() => setLightboxIndex(null)}
        />
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Add Photos link to trip detail page**

Edit `frontend/src/app/(app)/trips/[id]/page.tsx`. Add a Photos nav link after the "All trips" back-link and update the header section:

Find the header section (lines 22-33) and replace with:

```tsx
        {/* Header */}
        <div className="mb-8">
          <Link href="/trips" className="text-xs text-atlas-muted hover:text-atlas-text mb-3 inline-block">
            ← All trips
          </Link>
          <div className="flex items-start justify-between">
            <div>
              <h1 className="font-display text-3xl font-semibold text-atlas-text">{trip.title}</h1>
              {trip.description && (
                <p className="text-atlas-muted mt-2 text-sm">{trip.description}</p>
              )}
              <p className="text-xs font-mono text-atlas-muted mt-2">
                {formatDateRange(trip.start_date, trip.end_date)}
              </p>
            </div>
            <Link
              href={`/trips/${id}/photos`}
              className="flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors shrink-0 ml-4"
            >
              Photos
            </Link>
          </div>
        </div>
```

- [ ] **Step 5: Run page test**

```bash
cd /home/zach/Atlas/frontend && npx vitest run "src/app/\(app\)/trips/\[id\]/photos/__tests__/page.test.tsx"
```

Expected: 1 passed

- [ ] **Step 6: Run full frontend test suite**

```bash
cd /home/zach/Atlas/frontend && npx vitest run
```

Expected: all tests pass

- [ ] **Step 7: Commit**

```bash
git add frontend/src/app/\(app\)/trips/\[id\]/photos/ frontend/src/app/\(app\)/trips/\[id\]/page.tsx
git commit -m "feat(photos): photos page with upload, grid, lightbox, and trip detail nav link"
```

---

### Task 11: TripCard Cover Photo Display

**Files:**
- Modify: `frontend/src/components/trips/TripCard.tsx`

- [ ] **Step 1: Write the failing test**

Create `frontend/src/components/trips/__tests__/TripCard.cover.test.tsx`:

```typescript
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import type { Trip } from "@/types";

const mockTrip: Trip = {
  id: "trip-1",
  user_id: "user-1",
  title: "Japan 2025",
  description: null,
  status: "past",
  start_date: "2025-03-01",
  end_date: "2025-03-14",
  tags: [],
  visibility: "private",
  created_at: "2025-01-01T00:00:00Z",
  updated_at: "2025-01-01T00:00:00Z",
};

describe("TripCard cover photo", () => {
  it("renders cover photo when coverPhotoUrl provided", async () => {
    const { default: TripCard } = await import("../TripCard");
    render(
      <TripCard
        trip={mockTrip}
        coverPhotoUrl="http://localhost:9000/atlas-photos/photos/u/t/p.jpg"
      />
    );
    const img = screen.getByRole("img");
    expect(img.getAttribute("src")).toContain("atlas-photos");
  });

  it("renders without cover photo gracefully", async () => {
    const { default: TripCard } = await import("../TripCard");
    const { container } = render(<TripCard trip={mockTrip} />);
    expect(container.querySelector("img")).toBeNull();
  });
});
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /home/zach/Atlas/frontend && npx vitest run src/components/trips/__tests__/TripCard.cover.test.tsx
```

Expected: fails because `TripCard` doesn't accept `coverPhotoUrl` prop

- [ ] **Step 3: Update TripCard to accept and display cover photo**

Read `frontend/src/components/trips/TripCard.tsx` first, then update it:

The current TripCard renders a card with status badge, title, description, date range, and tags. Add `coverPhotoUrl?: string` to its props interface and render it at the top of the card:

```tsx
"use client";

import Link from "next/link";
import Image from "next/image";
import { formatDateRange } from "@/lib/utils";
import type { Trip } from "@/types";

const STATUS_STYLES: Record<Trip["status"], string> = {
  past: "bg-atlas-surface text-atlas-muted",
  active: "bg-emerald-900/30 text-emerald-400",
  planned: "bg-atlas-accent/10 text-atlas-accent",
  dream: "bg-purple-900/30 text-purple-400",
};

interface Props {
  trip: Trip;
  coverPhotoUrl?: string;
}

export default function TripCard({ trip, coverPhotoUrl }: Props) {
  return (
    <Link
      href={`/trips/${trip.id}`}
      className="block rounded-lg border border-atlas-border bg-atlas-surface overflow-hidden hover:border-atlas-accent/40 transition-colors"
    >
      {/* Cover photo */}
      {coverPhotoUrl && (
        <div className="relative h-36 w-full">
          <Image
            src={coverPhotoUrl}
            alt={trip.title}
            fill
            className="object-cover"
            unoptimized
          />
        </div>
      )}

      <div className="p-4">
        <div className="flex items-center justify-between mb-2">
          <span className={`text-xs font-mono px-2 py-0.5 rounded capitalize ${STATUS_STYLES[trip.status as Trip["status"]] ?? STATUS_STYLES.past}`}>
            {trip.status}
          </span>
        </div>
        <h3 className="font-display text-base font-semibold text-atlas-text">{trip.title}</h3>
        {trip.description && (
          <p className="text-xs text-atlas-muted mt-1 line-clamp-2">{trip.description}</p>
        )}
        <p className="text-xs font-mono text-atlas-muted mt-2">
          {formatDateRange(trip.start_date, trip.end_date)}
        </p>
        {trip.tags.length > 0 && (
          <div className="flex flex-wrap gap-1 mt-2">
            {trip.tags.map((tag) => (
              <span key={tag} className="text-xs bg-atlas-bg text-atlas-muted px-1.5 py-0.5 rounded">
                {tag}
              </span>
            ))}
          </div>
        )}
      </div>
    </Link>
  );
}
```

- [ ] **Step 4: Run test to confirm it passes**

```bash
cd /home/zach/Atlas/frontend && npx vitest run src/components/trips/__tests__/TripCard.cover.test.tsx
```

Expected: 2 passed

- [ ] **Step 5: Run full test suite**

```bash
cd /home/zach/Atlas/frontend && npx vitest run
```

Expected: all tests pass

- [ ] **Step 6: Run full backend test suite**

```bash
docker compose exec atlas-backend pytest --tb=short -q
```

Expected: all tests pass

- [ ] **Step 7: Commit**

```bash
git add frontend/src/components/trips/TripCard.tsx frontend/src/components/trips/__tests__/TripCard.cover.test.tsx
git commit -m "feat(photos): TripCard cover photo display"
```

---

## Self-Review

### Spec coverage check

Mapping Phase 2 spec requirements to tasks:

| Requirement | Task |
|---|---|
| MinIO bucket setup + IAM policy | Task 3 (`ensure_bucket_exists` with public-read policy) |
| Photo upload API + MinIO streaming | Task 5 (upload endpoint) |
| EXIF extraction (datetime + GPS) via Pillow | Task 5 (`_extract_metadata`) |
| Thumbnail generation (async background task) | Task 5 (`_generate_and_upload_thumbnail` via BackgroundTasks) |
| Photo grid + lightbox component | Task 8 (PhotoGrid + Lightbox) |
| Trip cover photo selection | Task 5 (set-cover endpoint) + Task 11 (TripCard) |

All requirements covered.

### Placeholder scan

No TBDs, TODOs, or incomplete sections found.

### Type consistency

- `Photo` type defined in Task 7; `PhotoRead` schema in Task 4 — field names match
- `usePhotos` returns `PhotoListResponse` with `.items: Photo[]` — consumed as `photoData?.items` in Task 10 ✓
- `PhotoGrid` accepts `photos: Photo[]` — matches `usePhotos` output ✓
- `Lightbox` accepts `photos: Photo[]` — same type ✓
- `TripCard` `coverPhotoUrl?: string` — passed from trip list page in Task 11 (TripList calls existing hooks; `coverPhotoUrl` is optional so existing callers won't break) ✓
- `StorageService.public_url(key)` used in `_to_photo_read` (Task 5) and `usePhotos` test fixture ✓
