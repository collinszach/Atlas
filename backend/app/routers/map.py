import logging

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.schemas.map import FlightArcResponse
from app.services.map_cache import get_cached, set_cached

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/map", tags=["map"])


@router.get("/arcs", response_model=list[FlightArcResponse])
async def get_map_arcs(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[FlightArcResponse]:
    """Flight arcs for all logged flights with geo. Cached 5 min per user."""
    cache_key = f"map:arcs:{user_id}"
    cached = await get_cached(cache_key)
    if cached is not None:
        return [FlightArcResponse(**r) for r in cached]

    result = await db.execute(
        text("""
            SELECT
                id::text,
                flight_number,
                origin_city,
                dest_city,
                origin_iata,
                dest_iata,
                departure_at::text,
                ST_Y(origin_geo::geometry) AS origin_lat,
                ST_X(origin_geo::geometry) AS origin_lng,
                ST_Y(dest_geo::geometry)   AS dest_lat,
                ST_X(dest_geo::geometry)   AS dest_lng
            FROM transport_legs
            WHERE user_id = :user_id
              AND origin_geo IS NOT NULL
              AND dest_geo IS NOT NULL
            ORDER BY departure_at NULLS LAST
        """),
        {"user_id": user_id},
    )
    rows = result.mappings().all()
    data = [FlightArcResponse(**r) for r in rows]
    await set_cached(cache_key, [r.model_dump() for r in data])
    return data
