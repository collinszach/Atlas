from __future__ import annotations
from pydantic import BaseModel


class FlightArcResponse(BaseModel):
    id: str
    flight_number: str | None
    origin_city: str | None
    dest_city: str | None
    origin_iata: str | None
    dest_iata: str | None
    departure_at: str | None
    origin_lat: float
    origin_lng: float
    dest_lat: float
    dest_lng: float
