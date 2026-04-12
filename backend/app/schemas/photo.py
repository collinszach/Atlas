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
    # Computed by router — not from ORM
    url: str
    thumbnail_url: str | None

    model_config = ConfigDict(from_attributes=False)


class PhotoListResponse(BaseModel):
    items: list[PhotoRead]
    total: int


class PhotoUpdate(BaseModel):
    caption: str | None = None
    order_index: int | None = None
