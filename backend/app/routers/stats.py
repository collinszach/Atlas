from __future__ import annotations

from collections import Counter
from decimal import Decimal
from typing import Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.destination import Destination
from app.models.transport import TransportLeg
from app.services.skywatch.airlines import resolve_airline

router = APIRouter(tags=["stats"])

CO2_KG_PER_KM = 0.115


class UserStats(BaseModel):
    countries_visited: int
    cities_visited: int
    trips_count: int
    nights_away: int
    total_distance_km: float
    longest_trip_days: int | None
    longest_trip_title: str | None
    most_visited_country: str | None
    most_visited_country_code: str | None
    most_visited_country_count: int | None
    co2_kg_estimate: float
    # Skywatch-era flight detail (consumed by the iOS stats view)
    hours_in_air: float | None = None
    top_airline: str | None = None
    most_flown_airport: str | None = None


class HeatmapEntry(BaseModel):
    country_code: str
    country_name: str
    visit_count: int
    total_nights: int = 0


class TimelineTrip(BaseModel):
    id: str
    title: str
    status: Literal["past", "active", "planned", "dream"]
    start_date: str | None
    end_date: str | None
    destination_count: int
    transport_count: int


@router.get("/stats", response_model=UserStats)
async def get_stats(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> UserStats:
    # Countries and cities visited
    dest_result = await db.execute(
        select(
            func.count(func.distinct(Destination.country_code)).label("countries"),
            func.count(
                func.distinct(func.concat(Destination.city, "|", Destination.country_code))
            ).label("cities"),
            func.coalesce(func.sum(Destination.nights), 0).label("total_nights"),
        ).where(Destination.user_id == user_id)
    )
    dest_row = dest_result.one()

    # Total trips count
    trips_result = await db.execute(
        text("SELECT COUNT(*) FROM trips WHERE user_id = :uid"),
        {"uid": user_id},
    )
    trips_count = int(trips_result.scalar_one() or 0)

    # Total distance flown
    dist_result = await db.execute(
        select(func.coalesce(func.sum(TransportLeg.distance_km), Decimal("0"))).where(
            TransportLeg.user_id == user_id
        )
    )
    total_distance_km = float(dist_result.scalar_one() or 0)

    # Longest trip by summed nights
    longest_result = await db.execute(
        text("""
            SELECT t.title, COALESCE(SUM(d.nights), 0) AS trip_nights
            FROM trips t
            LEFT JOIN destinations d ON d.trip_id = t.id AND d.user_id = :uid
            WHERE t.user_id = :uid
            GROUP BY t.id, t.title
            ORDER BY trip_nights DESC
            LIMIT 1
        """),
        {"uid": user_id},
    )
    longest_row = longest_result.fetchone()
    longest_trip_nights = int(longest_row.trip_nights) if longest_row and longest_row.trip_nights is not None else None
    longest_trip_title = longest_row.title if longest_row and longest_row.trip_nights is not None else None

    # Most visited country (by visit count from materialized view)
    mv_result = await db.execute(
        text("""
            SELECT country_code, country_name, visit_count
            FROM country_visits
            WHERE user_id = :uid
            ORDER BY visit_count DESC
            LIMIT 1
        """),
        {"uid": user_id},
    )
    mv_row = mv_result.fetchone()

    # --- hours_in_air ---
    # Sum duration_min where available; fall back to distance_km / 800 km·h⁻¹ for flight legs.
    flight_legs_rows = (
        await db.execute(
            select(TransportLeg.duration_min, TransportLeg.distance_km).where(
                TransportLeg.user_id == user_id, TransportLeg.type == "flight"
            )
        )
    ).all()

    total_minutes = 0.0
    for row in flight_legs_rows:
        if row.duration_min is not None:
            total_minutes += float(row.duration_min)
        elif row.distance_km is not None:
            total_minutes += float(row.distance_km) / 800.0 * 60.0
    hours_in_air = round(total_minutes / 60.0, 1) if flight_legs_rows else None

    # --- top_airline (most frequent operator across flight legs) ---
    airline_legs_rows = (
        await db.execute(
            select(TransportLeg.flight_number, TransportLeg.airline).where(
                TransportLeg.user_id == user_id, TransportLeg.type == "flight"
            )
        )
    ).all()

    airline_counter: Counter[str] = Counter()
    for row in airline_legs_rows:
        resolved = resolve_airline(row.flight_number) or row.airline
        if resolved:
            airline_counter[resolved] += 1
    top_airline = airline_counter.most_common(1)[0][0] if airline_counter else None

    # --- most_flown_airport (most frequent IATA across flight leg origins + destinations) ---
    airport_rows = (
        await db.execute(
            select(TransportLeg.origin_iata, TransportLeg.dest_iata).where(
                TransportLeg.user_id == user_id, TransportLeg.type == "flight"
            )
        )
    ).all()

    airport_counter: Counter[str] = Counter()
    for row in airport_rows:
        if row.origin_iata:
            airport_counter[row.origin_iata.upper()] += 1
        if row.dest_iata:
            airport_counter[row.dest_iata.upper()] += 1
    most_flown_airport = airport_counter.most_common(1)[0][0] if airport_counter else None

    return UserStats(
        countries_visited=dest_row.countries,
        cities_visited=dest_row.cities,
        trips_count=trips_count,
        nights_away=dest_row.total_nights,
        total_distance_km=total_distance_km,
        longest_trip_days=longest_trip_nights,
        longest_trip_title=longest_trip_title,
        most_visited_country=mv_row.country_name if mv_row else None,
        most_visited_country_code=mv_row.country_code if mv_row else None,
        most_visited_country_count=mv_row.visit_count if mv_row else None,
        co2_kg_estimate=round(total_distance_km * CO2_KG_PER_KM, 2),
        hours_in_air=hours_in_air,
        top_airline=top_airline,
        most_flown_airport=most_flown_airport,
    )


@router.get("/stats/heatmap", response_model=list[HeatmapEntry])
async def get_stats_heatmap(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[HeatmapEntry]:
    result = await db.execute(
        text("""
            SELECT country_code, country_name, visit_count, total_nights
            FROM country_visits
            WHERE user_id = :uid
            ORDER BY visit_count DESC
        """),
        {"uid": user_id},
    )
    rows = result.fetchall()
    return [
        HeatmapEntry(
            country_code=r.country_code,
            country_name=r.country_name,
            visit_count=r.visit_count,
            total_nights=r.total_nights,
        )
        for r in rows
    ]


@router.get("/stats/timeline", response_model=list[TimelineTrip])
async def get_stats_timeline(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[TimelineTrip]:
    result = await db.execute(
        text("""
            SELECT
                t.id::text,
                t.title,
                t.status,
                t.start_date::text AS start_date,
                t.end_date::text   AS end_date,
                COUNT(DISTINCT d.id)   AS destination_count,
                COUNT(DISTINCT tl.id)  AS transport_count
            FROM trips t
            LEFT JOIN destinations d  ON d.trip_id  = t.id
            LEFT JOIN transport_legs tl ON tl.trip_id = t.id
            WHERE t.user_id = :uid
            GROUP BY t.id, t.title, t.status, t.start_date, t.end_date
            ORDER BY t.start_date ASC NULLS LAST
        """),
        {"uid": user_id},
    )
    rows = result.fetchall()
    return [
        TimelineTrip(
            id=r.id,
            title=r.title,
            status=r.status,
            start_date=r.start_date,
            end_date=r.end_date,
            destination_count=r.destination_count,
            transport_count=r.transport_count,
        )
        for r in rows
    ]
