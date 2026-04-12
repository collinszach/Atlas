from __future__ import annotations
import uuid
from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel


class AccommodationCreate(BaseModel):
    destination_id: uuid.UUID | None = None
    name: str
    type: str | None = None
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    check_in: datetime | None = None
    check_out: datetime | None = None
    confirmation: str | None = None
    cost_per_night: Decimal | None = None
    currency: str = "USD"
    rating: int | None = None
    notes: str | None = None


class AccommodationUpdate(BaseModel):
    destination_id: uuid.UUID | None = None
    name: str | None = None
    type: str | None = None
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    check_in: datetime | None = None
    check_out: datetime | None = None
    confirmation: str | None = None
    cost_per_night: Decimal | None = None
    currency: str | None = None
    rating: int | None = None
    notes: str | None = None


class AccommodationRead(BaseModel):
    id: uuid.UUID
    trip_id: uuid.UUID
    user_id: str
    destination_id: uuid.UUID | None
    name: str
    type: str | None
    address: str | None
    latitude: float | None = None
    longitude: float | None = None
    check_in: datetime | None
    check_out: datetime | None
    confirmation: str | None
    cost_per_night: Decimal | None
    currency: str
    rating: int | None
    notes: str | None
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_with_geo(cls, acc: object) -> "AccommodationRead":
        """Extract lat/lng from GeoAlchemy2 WKBElement."""
        from geoalchemy2.shape import to_shape
        lat: float | None = None
        lng: float | None = None
        if acc.location is not None:
            pt = to_shape(acc.location)
            lng, lat = pt.x, pt.y
        data = {c.name: getattr(acc, c.name) for c in acc.__table__.columns}
        data["latitude"] = lat
        data["longitude"] = lng
        return cls(**data)
