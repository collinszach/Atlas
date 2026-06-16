import logging
from collections import Counter

from fastapi import APIRouter, Depends
from sqlalchemy import select, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.trip import Trip
from app.models.destination import Destination
from app.models.transport import TransportLeg
from app.schemas.stats import StatsResponse, TimelineTrip
from app.services.skywatch.airlines import resolve_airline

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/stats", tags=["stats"])

# Rough kg CO2 per passenger-km for flights (short/medium-haul average).
CO2_KG_PER_KM = 0.09


@router.get("", response_model=StatsResponse)
async def get_stats(user_id: CurrentUser, db: AsyncSession = Depends(get_db)) -> StatsResponse:
    countries = (
        await db.execute(
            select(func.count(func.distinct(Destination.country_code))).where(
                Destination.user_id == user_id
            )
        )
    ).scalar_one()

    trips_count = (
        await db.execute(select(func.count()).select_from(Trip).where(Trip.user_id == user_id))
    ).scalar_one()

    nights = (
        await db.execute(
            select(func.coalesce(func.sum(Destination.nights), 0)).where(
                Destination.user_id == user_id
            )
        )
    ).scalar_one()

    distance = (
        await db.execute(
            select(func.coalesce(func.sum(TransportLeg.distance_km), 0)).where(
                TransportLeg.user_id == user_id
            )
        )
    ).scalar_one()
    distance = float(distance or 0)

    flight_distance = (
        await db.execute(
            select(func.coalesce(func.sum(TransportLeg.distance_km), 0)).where(
                TransportLeg.user_id == user_id, TransportLeg.type == "flight"
            )
        )
    ).scalar_one()

    most_visited = (
        await db.execute(
            select(Destination.country_code, Destination.country_name, func.count().label("c"))
            .where(Destination.user_id == user_id)
            .group_by(Destination.country_code, Destination.country_name)
            .order_by(desc("c"))
            .limit(1)
        )
    ).first()

    longest = (
        await db.execute(
            select(
                Trip.title,
                (Trip.end_date - Trip.start_date).label("days"),
            )
            .where(
                Trip.user_id == user_id,
                Trip.start_date.is_not(None),
                Trip.end_date.is_not(None),
            )
            .order_by(desc("days"))
            .limit(1)
        )
    ).first()

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
            # 800 km/h estimate
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
        # Prefer resolving from flight_number callsign, fall back to stored airline field
        resolved = resolve_airline(row.flight_number) or row.airline
        if resolved:
            airline_counter[resolved] += 1
    top_airline = airline_counter.most_common(1)[0][0] if airline_counter else None

    # --- most_flown_airport (most frequent IATA across all flight leg origins + destinations) ---
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

    return StatsResponse(
        countries_visited=int(countries or 0),
        trips_count=int(trips_count or 0),
        nights_away=int(nights or 0),
        total_distance_km=round(distance, 1),
        co2_kg_estimate=round(float(flight_distance or 0) * CO2_KG_PER_KM, 1),
        most_visited_country=most_visited.country_name if most_visited else None,
        most_visited_country_code=most_visited.country_code if most_visited else None,
        longest_trip_title=longest.title if longest else None,
        longest_trip_days=int(longest.days) + 1 if longest and longest.days is not None else None,
        hours_in_air=hours_in_air,
        top_airline=top_airline,
        most_flown_airport=most_flown_airport,
    )


@router.get("/timeline", response_model=list[TimelineTrip])
async def get_timeline(user_id: CurrentUser, db: AsyncSession = Depends(get_db)) -> list[TimelineTrip]:
    dest_count = (
        select(Destination.trip_id, func.count().label("n"))
        .group_by(Destination.trip_id)
        .subquery()
    )
    rows = (
        await db.execute(
            select(Trip, func.coalesce(dest_count.c.n, 0))
            .outerjoin(dest_count, dest_count.c.trip_id == Trip.id)
            .where(Trip.user_id == user_id)
            .order_by(Trip.start_date.asc().nulls_last())
        )
    ).all()

    return [
        TimelineTrip(
            id=str(trip.id),
            title=trip.title,
            status=trip.status,
            start_date=trip.start_date.isoformat() if trip.start_date else None,
            end_date=trip.end_date.isoformat() if trip.end_date else None,
            destination_count=int(n or 0),
        )
        for trip, n in rows
    ]
