# Atlas Phase 5 — AI + Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Claude-powered destination recommendations, destination briefs, and bucket-list AI enrichment, plus a Discover frontend page and plan-page enrich button.

**Architecture:** A single `backend/app/services/ai.py` module owns all Anthropic API calls with a lazy singleton `AsyncAnthropic` client and a `_strip_fences()` JSON helper. Two new POST routes attach to the existing `discover` router; one new POST route attaches to the existing `bucket_list` router. The frontend adds `useMutation` hooks in the existing hook files and a new `/discover` page.

**Tech Stack:** Python `anthropic>=0.40.0` (`AsyncAnthropic`), `claude-haiku-4-5-20251001` model, FastAPI, TanStack Query v5 `useMutation`, Next.js 14 App Router, Tailwind/Atlas design tokens.

**Scope exclusions (explicitly out):** AI itinerary assist — no `ItineraryBuilder` component exists yet.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `backend/app/services/ai.py` | All Anthropic calls; `get_recommendations`, `get_destination_brief`, `enrich_bucket_list_item` |
| Modify | `backend/requirements.txt` | Add `anthropic>=0.40.0` |
| Modify | `backend/app/config.py` | Add `anthropic_api_key: str = ""` |
| Modify | `backend/app/routers/discover.py` | Append `POST /discover/recommend` + `POST /discover/destination-brief` |
| Modify | `backend/app/routers/bucket_list.py` | Append `POST /bucket-list/{id}/enrich` |
| Create | `backend/tests/test_ai_discover.py` | Auth + integration tests for discover endpoints |
| Create | `backend/tests/test_bucket_enrich.py` | Auth + integration test for enrich endpoint |
| Modify | `frontend/src/types/index.ts` | Add `RecommendationPreferences`, `RecommendationRequest`, `Recommendation`, `DestinationBriefResponse` |
| Modify | `frontend/src/hooks/useDiscover.ts` | Add `useRecommendations`, `useDestinationBrief` mutations |
| Modify | `frontend/src/hooks/useBucketList.ts` | Add `useEnrichBucketListItem` mutation |
| Create | `frontend/src/app/(app)/discover/page.tsx` | Preference form + recommendation cards + brief side panel |
| Modify | `frontend/src/app/(app)/plan/page.tsx` | Show `ai_summary` in `BucketCard`; "✦ Enrich" button |

---

### Task 1: Backend AI service + Discover endpoints

**Files:**
- Create: `backend/app/services/ai.py`
- Modify: `backend/requirements.txt`
- Modify: `backend/app/config.py`
- Modify: `backend/app/routers/discover.py`
- Create: `backend/tests/test_ai_discover.py`

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_ai_discover.py`:

```python
import json
import pytest
from unittest.mock import AsyncMock, patch
from httpx import AsyncClient

from app.main import app
from tests.conftest import TEST_USER_ID

RECOMMEND_URL = "/api/v1/discover/recommend"
BRIEF_URL = "/api/v1/discover/destination-brief"

SAMPLE_RECOMMENDATIONS = [
    {
        "country": "Portugal",
        "country_code": "PT",
        "city": "Lisbon",
        "why_youll_love_it": "Great food, similar vibe to cities you loved",
        "best_time": "April–June",
        "rough_cost": "moderate",
        "getting_there": "Direct flights from most US hubs",
    }
]

SAMPLE_BRIEF = {
    "destination": "Japan",
    "overview": "Island nation in East Asia",
    "best_months": [3, 4, 10, 11],
    "visa_notes": "Visa-free for US passport holders",
    "rough_costs": "moderate–high",
    "must_do": ["Kyoto temples", "Tokyo street food"],
    "food_highlights": ["Ramen", "Sushi", "Yakitori"],
    "transport_within": "JR Pass covers bullet trains",
}


@pytest.mark.asyncio
async def test_recommend_requires_auth(client: AsyncClient):
    res = await client.post(RECOMMEND_URL, json={"preferences": {}, "already_visited": []})
    assert res.status_code == 403


@pytest.mark.asyncio
async def test_destination_brief_requires_auth(client: AsyncClient):
    res = await client.post(BRIEF_URL, json={"country": "JP", "city": None})
    assert res.status_code == 403


@pytest.mark.asyncio
async def test_recommend_returns_list(auth_client: AsyncClient):
    with patch(
        "app.routers.discover.ai_service.get_recommendations",
        new=AsyncMock(return_value=SAMPLE_RECOMMENDATIONS),
    ):
        res = await auth_client.post(
            RECOMMEND_URL,
            json={
                "preferences": {
                    "climate": "warm",
                    "duration_days": 10,
                    "budget": "moderate",
                    "interests": ["food", "history"],
                    "avoid_crowds": False,
                    "departure_region": "North America",
                    "travel_month": "October",
                },
                "already_visited": ["FR", "JP"],
            },
        )
    assert res.status_code == 200
    data = res.json()
    assert isinstance(data, list)
    assert data[0]["country"] == "Portugal"


@pytest.mark.asyncio
async def test_destination_brief_returns_brief(auth_client: AsyncClient):
    with patch(
        "app.routers.discover.ai_service.get_destination_brief",
        new=AsyncMock(return_value=SAMPLE_BRIEF),
    ):
        res = await auth_client.post(
            BRIEF_URL,
            json={"country": "Japan", "country_code": "JP", "city": None},
        )
    assert res.status_code == 200
    data = res.json()
    assert data["destination"] == "Japan"
    assert "best_months" in data
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd backend && pytest tests/test_ai_discover.py -v
```
Expected: `FAILED` — `ImportError` or 404 (routes don't exist yet).

- [ ] **Step 3: Add `anthropic` to requirements and config**

In `backend/requirements.txt`, append after `python-jose[cryptography]==3.3.0`:
```
anthropic>=0.40.0
```

In `backend/app/config.py`, add one field to `Settings`:
```python
# AI
anthropic_api_key: str = ""
```

Full updated `config.py`:
```python
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Database
    database_url: str
    database_url_sync: str

    # Redis
    redis_url: str = "redis://localhost:6379/0"

    # Clerk
    clerk_secret_key: str
    clerk_webhook_secret: str

    # MinIO
    minio_endpoint: str = "atlas-minio:9000"
    minio_access_key: str = "minioadmin"
    minio_secret_key: str = "minioadmin"
    minio_bucket_photos: str = "atlas-photos"
    minio_public_url: str = "http://localhost:9000"
    storage_backend: str = "minio"

    # AI
    anthropic_api_key: str = ""

    # App
    app_env: str = "development"


settings = Settings()
```

- [ ] **Step 4: Create `backend/app/services/ai.py`**

```python
from __future__ import annotations

import json
import logging
import re
from typing import Any

from anthropic import AsyncAnthropic

from app.config import settings

logger = logging.getLogger(__name__)

_client: AsyncAnthropic | None = None

MODEL = "claude-haiku-4-5-20251001"


def _get_client() -> AsyncAnthropic:
    global _client
    if _client is None:
        _client = AsyncAnthropic(api_key=settings.anthropic_api_key)
    return _client


def _strip_fences(text: str) -> str:
    """Remove markdown code fences (```json ... ```) if present."""
    text = text.strip()
    match = re.search(r"```(?:json)?\s*([\s\S]*?)```", text)
    if match:
        return match.group(1).strip()
    return text


async def get_recommendations(
    preferences: dict[str, Any],
    already_visited: list[str],
) -> list[dict[str, Any]]:
    """Return 3 AI destination recommendations as a list of dicts."""
    prompt = (
        f"You are a knowledgeable travel advisor. Based on the traveler's preferences and history, "
        f"suggest exactly 3 destination recommendations.\n\n"
        f"Traveler preferences:\n{json.dumps(preferences, indent=2)}\n\n"
        f"Countries already visited (ISO codes): {', '.join(already_visited) if already_visited else 'none'}\n\n"
        f"Return ONLY a JSON array (no markdown, no explanation) with exactly 3 objects, each with keys:\n"
        f"  country (string), country_code (ISO 3166-1 alpha-2), city (string or null),\n"
        f"  why_youll_love_it (string, personalized to their history/preferences),\n"
        f"  best_time (string), rough_cost (\"budget\"|\"moderate\"|\"luxury\"),\n"
        f"  getting_there (string)"
    )
    client = _get_client()
    message = await client.messages.create(
        model=MODEL,
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )
    raw = message.content[0].text
    return json.loads(_strip_fences(raw))


async def get_destination_brief(country: str, country_code: str | None, city: str | None) -> dict[str, Any]:
    """Return a destination brief as a dict."""
    location = f"{city}, {country}" if city else country
    prompt = (
        f"You are a travel expert. Write a concise destination brief for: {location}\n\n"
        f"Return ONLY a JSON object (no markdown, no explanation) with keys:\n"
        f"  destination (string), overview (string, 2-3 sentences),\n"
        f"  best_months (list of ints 1-12), visa_notes (string),\n"
        f"  rough_costs (string), must_do (list of strings, max 5),\n"
        f"  food_highlights (list of strings, max 5),\n"
        f"  transport_within (string)"
    )
    client = _get_client()
    message = await client.messages.create(
        model=MODEL,
        max_tokens=1024,
        messages=[{"role": "user", "content": prompt}],
    )
    raw = message.content[0].text
    return json.loads(_strip_fences(raw))


async def enrich_bucket_list_item(
    country_name: str | None,
    country_code: str | None,
    city: str | None,
    reason: str | None,
) -> str:
    """Return a short AI-generated summary string for a bucket list item."""
    location = city if city else country_name or country_code or "Unknown"
    context = f" The traveler wants to go because: {reason}" if reason else ""
    prompt = (
        f"Write a 2-3 sentence travel teaser for {location}.{context} "
        f"Make it evocative and specific — highlight what makes this place special. "
        f"Return only the plain text summary, no markdown, no JSON."
    )
    client = _get_client()
    message = await client.messages.create(
        model=MODEL,
        max_tokens=256,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text.strip()
```

- [ ] **Step 5: Add POST routes to `backend/app/routers/discover.py`**

Append to the existing `discover.py` (after the `best_time` route). The full updated file:

```python
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
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd backend && pytest tests/test_ai_discover.py -v
```
Expected: 4 PASSED.

- [ ] **Step 7: Run full test suite**

```bash
cd backend && pytest --tb=short -q
```
Expected: all previously passing tests still pass.

- [ ] **Step 8: Commit**

```bash
git add backend/app/services/ai.py backend/app/config.py backend/requirements.txt backend/app/routers/discover.py backend/tests/test_ai_discover.py
git commit -m "feat(ai): add AI service + discover recommend + destination-brief endpoints"
```

---

### Task 2: Bucket list enrich endpoint

**Files:**
- Modify: `backend/app/routers/bucket_list.py`
- Create: `backend/tests/test_bucket_enrich.py`

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_bucket_enrich.py`:

```python
import pytest
from unittest.mock import AsyncMock, patch
from httpx import AsyncClient

from tests.conftest import TEST_USER_ID

ENRICH_SUMMARY = "Tokyo is a dazzling collision of ancient temples and neon-lit skyscrapers. The city rewards explorers with world-class ramen, bullet trains, and a culture of extraordinary craftsmanship."


@pytest.mark.asyncio
async def test_enrich_requires_auth(client: AsyncClient, db_session):
    from app.models.bucket_list import BucketList
    item = BucketList(
        user_id=TEST_USER_ID,
        country_name="Japan",
        country_code="JP",
        city="Tokyo",
        priority=3,
    )
    db_session.add(item)
    await db_session.flush()
    res = await client.post(f"/api/v1/bucket-list/{item.id}/enrich")
    assert res.status_code == 403


@pytest.mark.asyncio
async def test_enrich_sets_ai_summary(auth_client: AsyncClient, db_session):
    from app.models.bucket_list import BucketList
    item = BucketList(
        user_id=TEST_USER_ID,
        country_name="Japan",
        country_code="JP",
        city="Tokyo",
        priority=3,
    )
    db_session.add(item)
    await db_session.flush()

    with patch(
        "app.routers.bucket_list.ai_service.enrich_bucket_list_item",
        new=AsyncMock(return_value=ENRICH_SUMMARY),
    ):
        res = await auth_client.post(f"/api/v1/bucket-list/{item.id}/enrich")

    assert res.status_code == 200
    data = res.json()
    assert data["ai_summary"] == ENRICH_SUMMARY
    assert data["id"] == str(item.id)


@pytest.mark.asyncio
async def test_enrich_wrong_user_returns_404(auth_client: AsyncClient, db_session):
    from app.models.bucket_list import BucketList
    item = BucketList(
        user_id="other_user_id",
        country_name="Brazil",
        country_code="BR",
        priority=2,
    )
    db_session.add(item)
    await db_session.flush()

    with patch(
        "app.routers.bucket_list.ai_service.enrich_bucket_list_item",
        new=AsyncMock(return_value="Should not be called"),
    ):
        res = await auth_client.post(f"/api/v1/bucket-list/{item.id}/enrich")

    assert res.status_code == 404
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd backend && pytest tests/test_bucket_enrich.py -v
```
Expected: `FAILED` — route doesn't exist yet (404 or import error).

- [ ] **Step 3: Add the enrich route to `backend/app/routers/bucket_list.py`**

Add the import for `ai_service` and `HTTPException` (already present), then append the route. Full updated file:

```python
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.bucket_list import BucketList
from app.schemas.bucket_list import BucketListCreate, BucketListRead, BucketListUpdate
from app.services import ai as ai_service

router = APIRouter(prefix="/bucket-list", tags=["bucket-list"])


@router.get("", response_model=list[BucketListRead])
async def list_bucket_list(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[BucketList]:
    result = await db.execute(
        select(BucketList)
        .where(BucketList.user_id == user_id)
        .order_by(BucketList.priority.desc(), BucketList.created_at.desc())
    )
    return list(result.scalars().all())


@router.post("", response_model=BucketListRead, status_code=201)
async def create_bucket_list_item(
    body: BucketListCreate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> BucketList:
    item = BucketList(user_id=user_id, **body.model_dump())
    db.add(item)
    await db.flush()
    await db.refresh(item)
    return item


@router.put("/{item_id}", response_model=BucketListRead)
async def update_bucket_list_item(
    item_id: uuid.UUID,
    body: BucketListUpdate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> BucketList:
    result = await db.execute(
        select(BucketList).where(BucketList.id == item_id, BucketList.user_id == user_id)
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Bucket list item not found")
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(item, k, v)
    await db.flush()
    await db.refresh(item)
    return item


@router.delete("/{item_id}", status_code=204)
async def delete_bucket_list_item(
    item_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> None:
    result = await db.execute(
        select(BucketList).where(BucketList.id == item_id, BucketList.user_id == user_id)
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Bucket list item not found")
    await db.delete(item)
    await db.flush()


@router.post("/{item_id}/enrich", response_model=BucketListRead)
async def enrich_bucket_list_item(
    item_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> BucketList:
    """Generate and persist an AI summary for a bucket list item."""
    result = await db.execute(
        select(BucketList).where(BucketList.id == item_id, BucketList.user_id == user_id)
    )
    item = result.scalar_one_or_none()
    if item is None:
        raise HTTPException(status_code=404, detail="Bucket list item not found")

    try:
        summary = await ai_service.enrich_bucket_list_item(
            country_name=item.country_name,
            country_code=item.country_code,
            city=item.city,
            reason=item.reason,
        )
    except Exception as exc:
        raise HTTPException(status_code=502, detail="AI service unavailable") from exc

    item.ai_summary = summary
    await db.flush()
    await db.refresh(item)
    return item
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd backend && pytest tests/test_bucket_enrich.py -v
```
Expected: 3 PASSED.

- [ ] **Step 5: Run full test suite**

```bash
cd backend && pytest --tb=short -q
```
Expected: all previously passing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/bucket_list.py backend/tests/test_bucket_enrich.py
git commit -m "feat(bucket-list): add POST /bucket-list/{id}/enrich endpoint"
```

---

### Task 3: Frontend types and hooks

**Files:**
- Modify: `frontend/src/types/index.ts`
- Modify: `frontend/src/hooks/useDiscover.ts`
- Modify: `frontend/src/hooks/useBucketList.ts`

- [ ] **Step 1: Add new types to `frontend/src/types/index.ts`**

Append after the existing `BestTimeResponse` interface (after line 205):

```typescript
export interface RecommendationPreferences {
  climate?: string;
  duration_days?: number;
  budget?: string;
  interests?: string[];
  avoid_crowds?: boolean;
  departure_region?: string;
  travel_month?: string;
}

export interface RecommendationRequest {
  preferences: RecommendationPreferences;
  already_visited: string[];
}

export interface Recommendation {
  country: string;
  country_code: string | null;
  city: string | null;
  why_youll_love_it: string;
  best_time: string;
  rough_cost: string;
  getting_there: string;
}

export interface DestinationBriefRequest {
  country: string;
  country_code?: string | null;
  city?: string | null;
}

export interface DestinationBriefResponse {
  destination: string;
  overview: string;
  best_months: number[];
  visa_notes: string;
  rough_costs: string;
  must_do: string[];
  food_highlights: string[];
  transport_within: string;
}
```

- [ ] **Step 2: Verify TypeScript compiles**

```bash
cd frontend && npx tsc --noEmit
```
Expected: no errors related to the new types.

- [ ] **Step 3: Update `frontend/src/hooks/useDiscover.ts`** to add mutations

Full replacement of the file:

```typescript
import { useQuery, useMutation } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost } from "@/lib/api";
import type {
  BestTimeResponse,
  RecommendationRequest,
  Recommendation,
  DestinationBriefRequest,
  DestinationBriefResponse,
} from "@/types";

export function useBestTime(countryCode: string, city?: string) {
  const { getToken } = useAuth();
  const params = city ? `?city=${encodeURIComponent(city)}` : "";
  return useQuery<BestTimeResponse>({
    queryKey: ["best-time", countryCode, city],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<BestTimeResponse>(`/discover/best-time/${countryCode}${params}`, token);
    },
    enabled: !!countryCode,
    staleTime: 24 * 60 * 60 * 1000,
  });
}

export function useRecommendations() {
  const { getToken } = useAuth();
  return useMutation<Recommendation[], Error, RecommendationRequest>({
    mutationFn: async (body) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<Recommendation[]>("/discover/recommend", token, body);
    },
  });
}

export function useDestinationBrief() {
  const { getToken } = useAuth();
  return useMutation<DestinationBriefResponse, Error, DestinationBriefRequest>({
    mutationFn: async (body) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<DestinationBriefResponse>("/discover/destination-brief", token, body);
    },
  });
}
```

- [ ] **Step 4: Add `useEnrichBucketListItem` to `frontend/src/hooks/useBucketList.ts`**

Append after the existing `useDeleteBucketListItem` export:

```typescript
export function useEnrichBucketListItem() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<BucketListItem>(`/bucket-list/${id}/enrich`, token, {});
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["bucket-list"] }),
  });
}
```

- [ ] **Step 5: Verify TypeScript compiles**

```bash
cd frontend && npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/types/index.ts frontend/src/hooks/useDiscover.ts frontend/src/hooks/useBucketList.ts
git commit -m "feat(frontend): add AI discovery types and hooks"
```

---

### Task 4: Discover page + plan page enrich button

**Files:**
- Create: `frontend/src/app/(app)/discover/page.tsx`
- Modify: `frontend/src/app/(app)/plan/page.tsx`

- [ ] **Step 1: Create `frontend/src/app/(app)/discover/page.tsx`**

```typescript
"use client";

import { useState } from "react";
import { Sparkles, MapPin, ChevronRight, X, Loader2 } from "lucide-react";
import { useRecommendations, useDestinationBrief } from "@/hooks/useDiscover";
import type { Recommendation, DestinationBriefResponse, RecommendationPreferences } from "@/types";

const MONTH_NAMES = [
  "", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
];

const CLIMATE_OPTIONS = ["warm", "cool", "tropical", "temperate", "any"];
const BUDGET_OPTIONS = ["budget", "moderate", "luxury"];
const INTEREST_OPTIONS = ["food", "history", "hiking", "beaches", "culture", "nightlife", "wildlife", "architecture"];

function RecommendationCard({
  rec,
  onViewBrief,
}: {
  rec: Recommendation;
  onViewBrief: (rec: Recommendation) => void;
}) {
  return (
    <div className="rounded-lg border border-atlas-border bg-atlas-surface p-5 flex flex-col gap-3">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h3 className="text-base font-semibold text-atlas-text font-display">
            {rec.city ? `${rec.city}, ${rec.country}` : rec.country}
          </h3>
          {rec.country_code && (
            <span className="text-xs font-mono text-atlas-muted">{rec.country_code}</span>
          )}
        </div>
        <span className="text-xs font-mono px-2 py-0.5 rounded border border-atlas-border text-atlas-muted capitalize shrink-0">
          {rec.rough_cost}
        </span>
      </div>

      <p className="text-sm text-atlas-text leading-relaxed">{rec.why_youll_love_it}</p>

      <div className="flex flex-col gap-1 text-xs text-atlas-muted">
        <span><span className="text-atlas-accent font-mono">Best time:</span> {rec.best_time}</span>
        <span><span className="text-atlas-accent font-mono">Getting there:</span> {rec.getting_there}</span>
      </div>

      <button
        onClick={() => onViewBrief(rec)}
        className="mt-1 flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors self-start"
      >
        View destination brief
        <ChevronRight size={12} />
      </button>
    </div>
  );
}

function BriefPanel({
  brief,
  onClose,
}: {
  brief: DestinationBriefResponse;
  onClose: () => void;
}) {
  return (
    <div className="fixed inset-y-0 right-0 w-full max-w-md bg-atlas-surface border-l border-atlas-border overflow-y-auto z-50 shadow-2xl">
      <div className="flex items-center justify-between p-5 border-b border-atlas-border sticky top-0 bg-atlas-surface">
        <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest">
          {brief.destination}
        </h2>
        <button
          onClick={onClose}
          className="text-atlas-muted hover:text-atlas-text transition-colors"
        >
          <X size={16} />
        </button>
      </div>

      <div className="p-5 flex flex-col gap-5">
        <p className="text-sm text-atlas-text leading-relaxed">{brief.overview}</p>

        <section>
          <h3 className="text-xs font-semibold text-atlas-accent uppercase tracking-widest mb-2">Best Months</h3>
          <div className="flex gap-1.5 flex-wrap">
            {brief.best_months.map((m) => (
              <span key={m} className="text-xs font-mono px-2 py-0.5 rounded bg-atlas-bg border border-atlas-border text-atlas-text">
                {MONTH_NAMES[m]}
              </span>
            ))}
          </div>
        </section>

        <section>
          <h3 className="text-xs font-semibold text-atlas-accent uppercase tracking-widest mb-2">Visa & Entry</h3>
          <p className="text-sm text-atlas-text">{brief.visa_notes}</p>
        </section>

        <section>
          <h3 className="text-xs font-semibold text-atlas-accent uppercase tracking-widest mb-2">Rough Costs</h3>
          <p className="text-sm text-atlas-text">{brief.rough_costs}</p>
        </section>

        <section>
          <h3 className="text-xs font-semibold text-atlas-accent uppercase tracking-widest mb-2">Must Do</h3>
          <ul className="flex flex-col gap-1">
            {brief.must_do.map((item, i) => (
              <li key={i} className="text-sm text-atlas-text flex items-start gap-2">
                <MapPin size={10} className="text-atlas-accent mt-1 shrink-0" />
                {item}
              </li>
            ))}
          </ul>
        </section>

        <section>
          <h3 className="text-xs font-semibold text-atlas-accent uppercase tracking-widest mb-2">Food Highlights</h3>
          <ul className="flex flex-col gap-1">
            {brief.food_highlights.map((item, i) => (
              <li key={i} className="text-sm text-atlas-text">· {item}</li>
            ))}
          </ul>
        </section>

        <section>
          <h3 className="text-xs font-semibold text-atlas-accent uppercase tracking-widest mb-2">Getting Around</h3>
          <p className="text-sm text-atlas-text">{brief.transport_within}</p>
        </section>
      </div>
    </div>
  );
}

export default function DiscoverPage() {
  const [climate, setClimate] = useState("");
  const [budget, setBudget] = useState("");
  const [month, setMonth] = useState("");
  const [selectedInterests, setSelectedInterests] = useState<string[]>([]);
  const [region, setRegion] = useState("");
  const [activeBrief, setActiveBrief] = useState<DestinationBriefResponse | null>(null);

  const recommend = useRecommendations();
  const getBreif = useDestinationBrief();

  function toggleInterest(interest: string) {
    setSelectedInterests((prev) =>
      prev.includes(interest) ? prev.filter((i) => i !== interest) : [...prev, interest]
    );
  }

  async function handleRecommend() {
    const prefs: RecommendationPreferences = {};
    if (climate) prefs.climate = climate;
    if (budget) prefs.budget = budget;
    if (month) prefs.travel_month = month;
    if (selectedInterests.length > 0) prefs.interests = selectedInterests;
    if (region) prefs.departure_region = region;
    await recommend.mutateAsync({ preferences: prefs, already_visited: [] });
  }

  async function handleViewBrief(rec: Recommendation) {
    const brief = await getBreif.mutateAsync({
      country: rec.country,
      country_code: rec.country_code ?? undefined,
      city: rec.city ?? undefined,
    });
    setActiveBrief(brief);
  }

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-3xl mx-auto">
        <div className="mb-8">
          <h1 className="text-xl font-semibold text-atlas-text font-display mb-1">Discover</h1>
          <p className="text-sm text-atlas-muted">AI-powered destination recommendations based on your preferences.</p>
        </div>

        {/* Preference form */}
        <div className="rounded-lg border border-atlas-border bg-atlas-surface p-5 mb-6 flex flex-col gap-4">
          <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
            <div>
              <label className="text-xs text-atlas-muted mb-1 block">Climate</label>
              <select
                value={climate}
                onChange={(e) => setClimate(e.target.value)}
                className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text focus:outline-none focus:border-atlas-accent"
              >
                <option value="">Any</option>
                {CLIMATE_OPTIONS.map((c) => (
                  <option key={c} value={c} className="capitalize">{c.charAt(0).toUpperCase() + c.slice(1)}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="text-xs text-atlas-muted mb-1 block">Budget</label>
              <select
                value={budget}
                onChange={(e) => setBudget(e.target.value)}
                className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text focus:outline-none focus:border-atlas-accent"
              >
                <option value="">Any</option>
                {BUDGET_OPTIONS.map((b) => (
                  <option key={b} value={b} className="capitalize">{b.charAt(0).toUpperCase() + b.slice(1)}</option>
                ))}
              </select>
            </div>

            <div>
              <label className="text-xs text-atlas-muted mb-1 block">Travel Month</label>
              <select
                value={month}
                onChange={(e) => setMonth(e.target.value)}
                className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text focus:outline-none focus:border-atlas-accent"
              >
                <option value="">Any</option>
                {MONTH_NAMES.slice(1).map((m, i) => (
                  <option key={i + 1} value={m}>{m}</option>
                ))}
              </select>
            </div>
          </div>

          <div>
            <label className="text-xs text-atlas-muted mb-2 block">Interests</label>
            <div className="flex flex-wrap gap-2">
              {INTEREST_OPTIONS.map((interest) => (
                <button
                  key={interest}
                  onClick={() => toggleInterest(interest)}
                  className={`px-3 py-1 text-xs rounded-full border transition-colors capitalize ${
                    selectedInterests.includes(interest)
                      ? "border-atlas-accent bg-atlas-accent/10 text-atlas-accent"
                      : "border-atlas-border text-atlas-muted hover:border-atlas-accent/40"
                  }`}
                >
                  {interest}
                </button>
              ))}
            </div>
          </div>

          <div>
            <label className="text-xs text-atlas-muted mb-1 block">Departure Region (optional)</label>
            <input
              value={region}
              onChange={(e) => setRegion(e.target.value)}
              placeholder="e.g. North America, Western Europe"
              className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text placeholder:text-atlas-muted focus:outline-none focus:border-atlas-accent"
            />
          </div>

          <button
            onClick={handleRecommend}
            disabled={recommend.isPending}
            className="flex items-center justify-center gap-2 px-4 py-2.5 rounded bg-atlas-accent text-atlas-bg text-sm font-medium hover:bg-atlas-accent/80 transition-colors disabled:opacity-50"
          >
            {recommend.isPending ? (
              <>
                <Loader2 size={14} className="animate-spin" />
                Thinking&hellip;
              </>
            ) : (
              <>
                <Sparkles size={14} />
                Get Recommendations
              </>
            )}
          </button>

          {recommend.isError && (
            <p className="text-xs text-red-400">Failed to get recommendations. Try again.</p>
          )}
        </div>

        {/* Results */}
        {recommend.data && (
          <div className="flex flex-col gap-4">
            {recommend.data.map((rec, i) => (
              <RecommendationCard key={i} rec={rec} onViewBrief={handleViewBrief} />
            ))}
          </div>
        )}

        {getBreif.isPending && (
          <div className="fixed inset-0 bg-atlas-bg/60 flex items-center justify-center z-40">
            <Loader2 size={24} className="animate-spin text-atlas-accent" />
          </div>
        )}
      </div>

      {activeBrief && (
        <BriefPanel brief={activeBrief} onClose={() => setActiveBrief(null)} />
      )}
    </div>
  );
}
```

- [ ] **Step 2: Verify TypeScript compiles**

```bash
cd frontend && npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 3: Update `BucketCard` in `frontend/src/app/(app)/plan/page.tsx`**

Add `useEnrichBucketListItem` to the import:
```typescript
import { useBucketList, useDeleteBucketListItem, useAddBucketListItem, useEnrichBucketListItem } from "@/hooks/useBucketList";
```

Add `Sparkles` and `Loader2` to the lucide import:
```typescript
import { Plus, MapPin, Globe, Trash2, Star, Sparkles, Loader2 } from "lucide-react";
```

Replace the `BucketCard` component:
```typescript
function BucketCard({ item, onDelete, onEnrich, isEnriching }: {
  item: BucketListItem;
  onDelete: () => void;
  onEnrich: () => void;
  isEnriching: boolean;
}) {
  return (
    <div className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3 flex items-start gap-4">
      <div className="flex h-8 w-8 items-center justify-center rounded bg-atlas-accent/10 text-atlas-accent shrink-0 mt-0.5">
        <Globe size={14} />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-atlas-text">
          {item.city ? `${item.city}, ` : ""}{item.country_name ?? item.country_code}
        </p>
        {item.reason && (
          <p className="text-xs text-atlas-muted mt-0.5 line-clamp-2">{item.reason}</p>
        )}
        {item.ai_summary && (
          <p className="text-xs text-atlas-text/80 mt-1.5 leading-relaxed border-l-2 border-atlas-accent/40 pl-2">
            {item.ai_summary}
          </p>
        )}
        <div className="flex items-center gap-3 mt-1.5">
          <PriorityStars priority={item.priority} />
          {item.ideal_season && (
            <span className="text-xs text-atlas-muted font-mono">
              {SEASON_LABELS[item.ideal_season] ?? item.ideal_season}
            </span>
          )}
          {!item.ai_summary && (
            <button
              onClick={onEnrich}
              disabled={isEnriching}
              className="flex items-center gap-1 text-xs text-atlas-muted hover:text-atlas-accent transition-colors disabled:opacity-50"
            >
              {isEnriching ? (
                <Loader2 size={10} className="animate-spin" />
              ) : (
                <Sparkles size={10} />
              )}
              {isEnriching ? "Enriching…" : "✦ Enrich"}
            </button>
          )}
        </div>
      </div>
      <button
        onClick={onDelete}
        className="text-atlas-muted hover:text-red-400 transition-colors shrink-0 mt-0.5"
        aria-label="Remove from bucket list"
      >
        <Trash2 size={14} />
      </button>
    </div>
  );
}
```

Add `enrichItem` and `enrichingId` state to `PlanPage`:
```typescript
const enrichItem = useEnrichBucketListItem();
const [enrichingId, setEnrichingId] = useState<string | null>(null);

async function handleEnrich(id: string) {
  setEnrichingId(id);
  try {
    await enrichItem.mutateAsync(id);
  } finally {
    setEnrichingId(null);
  }
}
```

Update the `BucketCard` usage in the map:
```typescript
{bucketList.map((item) => (
  <BucketCard
    key={item.id}
    item={item}
    onDelete={() => deleteItem.mutate(item.id)}
    onEnrich={() => handleEnrich(item.id)}
    isEnriching={enrichingId === item.id}
  />
))}
```

- [ ] **Step 4: Verify TypeScript compiles**

```bash
cd frontend && npx tsc --noEmit
```
Expected: no errors.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/app/\(app\)/discover/page.tsx frontend/src/app/\(app\)/plan/page.tsx
git commit -m "feat(frontend): add Discover page and bucket list AI enrich button"
```

---

## Completion Checklist

- [ ] All backend tests pass: `cd backend && pytest --tb=short -q`
- [ ] TypeScript compiles: `cd frontend && npx tsc --noEmit`
- [ ] `POST /discover/recommend` returns 3 structured recommendations
- [ ] `POST /discover/destination-brief` returns and caches briefs
- [ ] `POST /bucket-list/{id}/enrich` persists `ai_summary` and returns updated item
- [ ] Discover page: preference form → 3 recommendation cards → side panel brief
- [ ] Plan page: `ai_summary` shown inline; "✦ Enrich" button visible when no summary
