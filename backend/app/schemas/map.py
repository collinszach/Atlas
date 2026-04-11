from __future__ import annotations
from pydantic import BaseModel


class CountryVisitResponse(BaseModel):
    country_code: str
    country_name: str
    visit_count: int
    first_visit: str | None
    last_visit: str | None
    total_nights: int | None
    trip_ids: list[str]


class CityPointResponse(BaseModel):
    id: str
    city: str
    country_code: str
    country_name: str
    latitude: float
    longitude: float
    arrival_date: str | None
    departure_date: str | None
    trip_id: str
