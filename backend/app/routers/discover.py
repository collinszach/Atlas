import logging
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from app.auth import CurrentUser
from app.services import open_meteo
from app.services.map_cache import get_cached, set_cached

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/discover", tags=["discover"])

BEST_TIME_TTL = 60 * 60 * 24  # 24 hours


class MonthlyClimate(BaseModel):
    month: int
    avg_max_temp_c: float
    avg_precipitation_mm: float


class BestTimeResponse(BaseModel):
    location: str
    latitude: float
    longitude: float
    monthly: list[MonthlyClimate]
    best_months: list[int]


@router.get("/best-time/{country_code}", response_model=BestTimeResponse)
async def best_time(
    country_code: str,
    user_id: CurrentUser,
    city: str | None = Query(default=None),
) -> BestTimeResponse:
    """Return 30-year monthly climate averages and suggested best months to visit."""
    search_name = city if city else country_code
    cache_key = f"discover:best-time:{country_code.lower()}:{(city or '').lower()}"
    cached = await get_cached(cache_key)
    if cached is not None:
        return BestTimeResponse(**cached)

    try:
        lat, lng, display_name = await open_meteo.geocode(search_name)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        logger.warning("Open-Meteo geocode failed for %r: %s", search_name, exc)
        raise HTTPException(status_code=502, detail="Geocoding service unavailable")

    try:
        monthly_data = await open_meteo.fetch_monthly_averages(lat, lng)
    except Exception as exc:
        logger.warning("Open-Meteo climate fetch failed for (%s, %s): %s", lat, lng, exc)
        raise HTTPException(status_code=502, detail="Climate data service unavailable")

    best = open_meteo.pick_best_months(monthly_data)
    response = BestTimeResponse(
        location=display_name,
        latitude=lat,
        longitude=lng,
        monthly=[MonthlyClimate(**m) for m in monthly_data],
        best_months=best,
    )
    await set_cached(cache_key, response.model_dump(), ttl=BEST_TIME_TTL)
    return response
