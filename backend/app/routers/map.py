import logging

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.schemas.map import CityPointResponse, CountryVisitResponse, FlightArcResponse, PlannedCityResponse
from app.services.map_cache import get_cached, set_cached

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/map", tags=["map"])


@router.get("/countries", response_model=list[CountryVisitResponse])
async def get_map_countries(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[CountryVisitResponse]:
    """Country visit summary for choropleth layer. Cached 5 min per user."""
    cache_key = f"map:countries:{user_id}"
    cached = await get_cached(cache_key)
    if cached is not None:
        return [CountryVisitResponse(**r) for r in cached]

    result = await db.execute(
        text("""
            SELECT
                cv.country_code,
                cv.country_name,
                cv.visit_count,
                cv.first_visit::text,
                cv.last_visit::text,
                cv.total_nights,
                COALESCE(cv.trip_ids, '{}')::text[] AS trip_ids
            FROM country_visits cv
            WHERE cv.user_id = :user_id
        """),
        {"user_id": user_id},
    )
    rows = result.mappings().all()
    data = [CountryVisitResponse(**r) for r in rows]
    await set_cached(cache_key, [r.model_dump() for r in data])
    return data


@router.get("/cities", response_model=list[CityPointResponse])
async def get_map_cities(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[CityPointResponse]:
    """All visited city points for marker layer. Cached 5 min per user."""
    cache_key = f"map:cities:{user_id}"
    cached = await get_cached(cache_key)
    if cached is not None:
        return [CityPointResponse(**r) for r in cached]

    result = await db.execute(
        text("""
            SELECT DISTINCT ON (city, country_code)
                id::text,
                city,
                country_code,
                country_name,
                ST_Y(location::geometry) AS latitude,
                ST_X(location::geometry) AS longitude,
                arrival_date::text,
                departure_date::text,
                trip_id::text
            FROM destinations
            WHERE user_id = :user_id
              AND location IS NOT NULL
            ORDER BY city, country_code, arrival_date DESC NULLS LAST
        """),
        {"user_id": user_id},
    )
    rows = result.mappings().all()
    data = [CityPointResponse(**r) for r in rows]
    await set_cached(cache_key, [r.model_dump() for r in data])
    return data


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
                trip_id::text,
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
              AND type = 'flight'
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


@router.get("/planned", response_model=list[PlannedCityResponse])
async def get_map_planned(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[PlannedCityResponse]:
    """Ghost markers for destinations in planned/dream trips. Cached 5 min per user."""
    cache_key = f"map:planned:{user_id}"
    cached = await get_cached(cache_key)
    if cached is not None:
        return [PlannedCityResponse(**r) for r in cached]

    result = await db.execute(
        text("""
            SELECT DISTINCT ON (d.city, d.country_code)
                d.id::text,
                d.city,
                d.country_code,
                d.country_name,
                ST_Y(d.location::geometry) AS latitude,
                ST_X(d.location::geometry) AS longitude,
                t.id::text AS trip_id,
                t.title AS trip_title
            FROM destinations d
            JOIN trips t ON t.id = d.trip_id
            WHERE d.user_id = :user_id
              AND t.status IN ('planned', 'dream')
              AND d.location IS NOT NULL
            ORDER BY d.city, d.country_code, d.arrival_date NULLS LAST
        """),
        {"user_id": user_id},
    )
    rows = result.mappings().all()
    data = [PlannedCityResponse(**r) for r in rows]
    await set_cached(cache_key, [r.model_dump() for r in data])
    return data
