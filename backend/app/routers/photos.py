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
from app.schemas.photo import PhotoListResponse, PhotoRead
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
        dt_id = tag_names.get("DateTimeOriginal")
        if dt_id and dt_id in exif_raw:
            try:
                result["taken_at"] = datetime.strptime(exif_raw[dt_id], "%Y:%m:%d %H:%M:%S")
            except ValueError:
                pass
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
    from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
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

    meta = _extract_metadata(data)

    await storage.upload_file(storage_key, data, file.content_type or "image/jpeg")

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

    try:
        await storage.delete_file(photo.storage_key)
        if photo.thumbnail_key:
            await storage.delete_file(photo.thumbnail_key)
    except Exception as exc:
        logger.error("MinIO delete failed for photo %s: %s", photo_id, exc)
        raise HTTPException(status_code=500, detail="Storage delete failed")

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

    all_photos_result = await db.execute(
        select(Photo).where(Photo.trip_id == photo.trip_id, Photo.user_id == user_id)
    )
    for p in all_photos_result.scalars().all():
        p.is_cover = p.id == photo_id

    trip_result = await db.execute(
        select(Trip).where(Trip.id == photo.trip_id, Trip.user_id == user_id)
    )
    trip = trip_result.scalar_one_or_none()
    if trip:
        trip.cover_photo_id = photo_id

    await db.flush()
    return {"cover_photo_id": str(photo_id)}
