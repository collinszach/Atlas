import uuid
from datetime import datetime, date
from pydantic import BaseModel, model_validator


class DestinationCreate(BaseModel):
    city: str
    country_code: str
    country_name: str
    region: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    arrival_date: date | None = None
    departure_date: date | None = None
    notes: str | None = None
    rating: int | None = None
    order_index: int = 0

    @model_validator(mode="after")
    def validate_coordinates(self) -> "DestinationCreate":
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("Provide both latitude and longitude, or neither")
        return self


class DestinationUpdate(BaseModel):
    city: str | None = None
    country_code: str | None = None
    country_name: str | None = None
    region: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    arrival_date: date | None = None
    departure_date: date | None = None
    notes: str | None = None
    rating: int | None = None
    order_index: int | None = None


class DestinationRead(BaseModel):
    id: uuid.UUID
    trip_id: uuid.UUID
    user_id: str
    city: str
    country_code: str
    country_name: str
    region: str | None
    latitude: float | None = None
    longitude: float | None = None
    arrival_date: date | None
    departure_date: date | None
    nights: int | None
    notes: str | None
    rating: int | None
    order_index: int
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_with_geo(cls, dest: object) -> "DestinationRead":
        """Extract lat/lng from GeoAlchemy2 WKBElement."""
        from geoalchemy2.shape import to_shape
        lat: float | None = None
        lng: float | None = None
        if dest.location is not None:
            pt = to_shape(dest.location)
            lng, lat = pt.x, pt.y
        data = {c.name: getattr(dest, c.name) for c in dest.__table__.columns}
        data["latitude"] = lat
        data["longitude"] = lng
        return cls(**data)


class DestinationReorderItem(BaseModel):
    id: uuid.UUID
    order_index: int
