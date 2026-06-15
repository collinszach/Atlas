from pydantic import BaseModel


class StatsResponse(BaseModel):
    countries_visited: int
    trips_count: int
    nights_away: int
    total_distance_km: float
    co2_kg_estimate: float
    most_visited_country: str | None = None
    most_visited_country_code: str | None = None
    longest_trip_title: str | None = None
    longest_trip_days: int | None = None


class TimelineTrip(BaseModel):
    id: str
    title: str
    status: str
    start_date: str | None = None
    end_date: str | None = None
    destination_count: int
