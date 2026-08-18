from __future__ import annotations

from collections import Counter
from decimal import Decimal

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.transport import TransportLeg
from app.services.skywatch.airlines import resolve_airline

router = APIRouter(tags=["stats"])

CO2_KG_PER_KM = 0.115


class UserStats(BaseModel):
    flights_count: int
    total_distance_km: float
    co2_kg_estimate: float
    hours_in_air: float | None = None
    top_airline: str | None = None
    most_flown_airport: str | None = None


@router.get("/stats", response_model=UserStats)
async def get_stats(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> UserStats:
    flights_count = (
        await db.execute(select(func.count()).select_from(TransportLeg).where(TransportLeg.user_id == user_id))
    ).scalar_one()

    dist_result = await db.execute(
        select(func.coalesce(func.sum(TransportLeg.distance_km), Decimal("0"))).where(
            TransportLeg.user_id == user_id
        )
    )
    total_distance_km = float(dist_result.scalar_one() or 0)

    # --- hours_in_air ---
    # Sum duration_min where available; fall back to distance_km / 800 km·h⁻¹.
    flight_legs_rows = (
        await db.execute(
            select(TransportLeg.duration_min, TransportLeg.distance_km).where(TransportLeg.user_id == user_id)
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
        await db.execute(select(TransportLeg.flight_number, TransportLeg.airline).where(TransportLeg.user_id == user_id))
    ).all()

    airline_counter: Counter[str] = Counter()
    for row in airline_legs_rows:
        resolved = resolve_airline(row.flight_number) or row.airline
        if resolved:
            airline_counter[resolved] += 1
    top_airline = airline_counter.most_common(1)[0][0] if airline_counter else None

    # --- most_flown_airport (most frequent IATA across origins + destinations) ---
    airport_rows = (
        await db.execute(select(TransportLeg.origin_iata, TransportLeg.dest_iata).where(TransportLeg.user_id == user_id))
    ).all()

    airport_counter: Counter[str] = Counter()
    for row in airport_rows:
        if row.origin_iata:
            airport_counter[row.origin_iata.upper()] += 1
        if row.dest_iata:
            airport_counter[row.dest_iata.upper()] += 1
    most_flown_airport = airport_counter.most_common(1)[0][0] if airport_counter else None

    return UserStats(
        flights_count=flights_count,
        total_distance_km=total_distance_km,
        co2_kg_estimate=round(total_distance_km * CO2_KG_PER_KM, 2),
        hours_in_air=hours_in_air,
        top_airline=top_airline,
        most_flown_airport=most_flown_airport,
    )
