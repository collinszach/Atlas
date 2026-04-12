import logging
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from app.auth import CurrentUser
from app.services import open_meteo
from app.services import ai as ai_service
from app.services.map_cache import get_cached, set_cached

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/discover", tags=["discover"])

BEST_TIME_TTL = 60 * 60 * 24  # 24 hours
BRIEF_TTL = 60 * 60 * 24       # 24 hours


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


class RecommendationPreferences(BaseModel):
    climate: str | None = None
    duration_days: int | None = None
    budget: str | None = None
    interests: list[str] = []
    avoid_crowds: bool = False
    departure_region: str | None = None
    travel_month: str | None = None


class RecommendationRequest(BaseModel):
    preferences: RecommendationPreferences
    already_visited: list[str] = []


class Recommendation(BaseModel):
    country: str
    country_code: str | None = None
    city: str | None = None
    why_youll_love_it: str
    best_time: str
    rough_cost: str
    getting_there: str


class DestinationBriefRequest(BaseModel):
    country: str
    country_code: str | None = None
    city: str | None = None


class DestinationBriefResponse(BaseModel):
    destination: str
    overview: str
    best_months: list[int]
    visa_notes: str
    rough_costs: str
    must_do: list[str]
    food_highlights: list[str]
    transport_within: str


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


@router.post("/recommend", response_model=list[Recommendation])
async def recommend(
    body: RecommendationRequest,
    user_id: CurrentUser,
) -> list[Recommendation]:
    """Return 3 AI destination recommendations based on traveler preferences."""
    try:
        results = await ai_service.get_recommendations(
            preferences=body.preferences.model_dump(exclude_none=True),
            already_visited=body.already_visited,
        )
        return [Recommendation(**r) for r in results]
    except Exception as exc:
        logger.warning("AI recommendations failed: %s", exc)
        raise HTTPException(status_code=502, detail="AI service unavailable")


@router.post("/destination-brief", response_model=DestinationBriefResponse)
async def destination_brief(
    body: DestinationBriefRequest,
    user_id: CurrentUser,
) -> DestinationBriefResponse:
    """Return a cached AI destination brief for a country or city."""
    cache_key = f"discover:brief:{(body.country_code or body.country).lower()}:{(body.city or '').lower()}"
    cached = await get_cached(cache_key)
    if cached is not None:
        return DestinationBriefResponse(**cached)

    try:
        data = await ai_service.get_destination_brief(
            country=body.country,
            country_code=body.country_code,
            city=body.city,
        )
        response = DestinationBriefResponse(**data)
        await set_cached(cache_key, response.model_dump(), ttl=BRIEF_TTL)
        return response
    except Exception as exc:
        logger.warning("AI destination brief failed for %r: %s", body.country, exc)
        raise HTTPException(status_code=502, detail="AI service unavailable")
