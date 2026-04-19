from __future__ import annotations
import uuid
from datetime import date, datetime
from decimal import Decimal
from pydantic import BaseModel, model_validator


_VALID_TYPES = {"flight", "car", "train", "ferry", "bus", "walk", "other"}


class TransportCreate(BaseModel):
    type: str = "flight"
    flight_number: str | None = None
    airline: str | None = None
    origin_iata: str | None = None
    dest_iata: str | None = None
    origin_city: str | None = None
    dest_city: str | None = None
    departure_at: datetime | None = None
    arrival_at: datetime | None = None
    duration_min: int | None = None
    distance_km: Decimal | None = None
    seat_class: str | None = None
    booking_ref: str | None = None
    cost: Decimal | None = None
    currency: str = "USD"
    notes: str | None = None
    origin_lat: float | None = None
    origin_lng: float | None = None
    dest_lat: float | None = None
    dest_lng: float | None = None

    @model_validator(mode="after")
    def validate_type(self) -> "TransportCreate":
        if self.type not in _VALID_TYPES:
            raise ValueError(f"type must be one of {sorted(_VALID_TYPES)}")
        return self

    @model_validator(mode="after")
    def validate_geo_pairs(self) -> "TransportCreate":
        if (self.origin_lat is None) != (self.origin_lng is None):
            raise ValueError("Provide both origin_lat and origin_lng, or neither")
        if (self.dest_lat is None) != (self.dest_lng is None):
            raise ValueError("Provide both dest_lat and dest_lng, or neither")
        return self


class TransportUpdate(BaseModel):
    type: str | None = None
    flight_number: str | None = None
    airline: str | None = None
    origin_iata: str | None = None
    dest_iata: str | None = None
    origin_city: str | None = None
    dest_city: str | None = None
    departure_at: datetime | None = None
    arrival_at: datetime | None = None
    duration_min: int | None = None
    distance_km: Decimal | None = None
    seat_class: str | None = None
    booking_ref: str | None = None
    cost: Decimal | None = None
    currency: str | None = None
    notes: str | None = None
    origin_lat: float | None = None
    origin_lng: float | None = None
    dest_lat: float | None = None
    dest_lng: float | None = None

    @model_validator(mode="after")
    def validate_type(self) -> "TransportUpdate":
        if self.type is not None and self.type not in _VALID_TYPES:
            raise ValueError(f"type must be one of {sorted(_VALID_TYPES)}")
        return self


class TransportRead(BaseModel):
    id: uuid.UUID
    trip_id: uuid.UUID
    user_id: str
    type: str
    flight_number: str | None
    airline: str | None
    origin_iata: str | None
    dest_iata: str | None
    origin_city: str | None
    dest_city: str | None
    departure_at: datetime | None
    arrival_at: datetime | None
    duration_min: int | None
    distance_km: Decimal | None
    seat_class: str | None
    booking_ref: str | None
    cost: Decimal | None
    currency: str
    notes: str | None
    origin_lat: float | None = None
    origin_lng: float | None = None
    dest_lat: float | None = None
    dest_lng: float | None = None
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_with_geo(cls, leg: object) -> "TransportRead":
        """Extract lat/lng from GeoAlchemy2 WKBElement for both origin and dest."""
        from geoalchemy2.shape import to_shape
        origin_lat = origin_lng = dest_lat = dest_lng = None
        if leg.origin_geo is not None:
            pt = to_shape(leg.origin_geo)
            origin_lng, origin_lat = pt.x, pt.y
        if leg.dest_geo is not None:
            pt = to_shape(leg.dest_geo)
            dest_lng, dest_lat = pt.x, pt.y
        data = {c.name: getattr(leg, c.name) for c in leg.__table__.columns}
        data["origin_lat"] = origin_lat
        data["origin_lng"] = origin_lng
        data["dest_lat"] = dest_lat
        data["dest_lng"] = dest_lng
        return cls(**data)


class EnrichFlightRequest(BaseModel):
    flight_number: str
    date: date


class EnrichFlightResponse(BaseModel):
    flight_number: str | None = None
    airline: str | None = None
    origin_iata: str | None = None
    dest_iata: str | None = None
    origin_city: str | None = None
    dest_city: str | None = None
    duration_min: int | None = None
    distance_km: float | None = None
