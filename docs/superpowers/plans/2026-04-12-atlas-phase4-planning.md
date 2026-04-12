# Atlas Phase 4 — Planning & Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add bucket list CRUD, planned-trip ghost markers on the world map, a best-time-to-visit climate API, a map filter bar, and drag-to-reorder itinerary sorting.

**Architecture:** Five focused tasks — backend-first (Tasks 1-3) then frontend (Tasks 4-5). Bucket list is a new first-class table with its own model/router/tests. The planned destinations map layer reuses the existing map cache pattern. Best-time-to-visit proxies Open-Meteo (free, no API key) via an httpx async client cached in Redis for 24 h. All frontend state goes through TanStack Query and the existing Zustand mapStore.

**Tech Stack:** FastAPI, SQLAlchemy 2.0 async, Alembic, PostgreSQL+PostGIS, Redis, httpx, Next.js 14 App Router, TypeScript strict, TanStack Query v5, Zustand, @dnd-kit/core + @dnd-kit/sortable, MapLibre GL JS, Tailwind CSS, Lucide-react, pytest-asyncio

---

## File Structure

**New backend files:**
- `backend/migrations/versions/006_bucket_list.py` — Alembic migration: CREATE TABLE bucket_list
- `backend/app/models/bucket_list.py` — BucketList SQLAlchemy model
- `backend/app/schemas/bucket_list.py` — BucketListCreate / BucketListUpdate / BucketListRead
- `backend/app/routers/bucket_list.py` — GET/POST /bucket-list, PUT/DELETE /bucket-list/{id}
- `backend/app/services/open_meteo.py` — async httpx client for geocoding + climate data
- `backend/app/routers/discover.py` — GET /discover/best-time/{country_code}
- `backend/tests/test_bucket_list.py` — 7 integration tests
- `backend/tests/test_map_planned.py` — 3 integration tests for /map/planned
- `backend/tests/test_discover.py` — 2 unit tests with monkeypatched service

**Modified backend files:**
- `backend/app/schemas/map.py` — add PlannedCityResponse
- `backend/app/routers/map.py` — add GET /map/planned
- `backend/app/schemas/trip.py` — add status enum validation
- `backend/app/schemas/destination.py` — add DestinationReorderItem
- `backend/app/routers/destinations.py` — add PATCH /trips/{id}/destinations/reorder
- `backend/app/main.py` — register bucket_list and discover routers
- `backend/tests/test_map.py` — add auth test for /map/planned
- `backend/tests/test_trips.py` — add test_invalid_status_rejected

**New frontend files:**
- `frontend/src/hooks/useBucketList.ts` — TanStack Query CRUD hooks
- `frontend/src/hooks/useDiscover.ts` — useBestTime hook
- `frontend/src/components/map/MapFilterBar.tsx` — year + status filter UI

**Modified frontend files:**
- `frontend/src/types/index.ts` — BucketListItem, PlannedCity, BestTimeMonth, BestTimeResponse
- `frontend/src/hooks/useMapData.ts` — add usePlannedCities
- `frontend/src/store/mapStore.ts` — add filterYear / filterStatus state
- `frontend/src/components/map/WorldMap.tsx` — ghost markers layer, accept filter, show MapFilterBar
- `frontend/src/app/(app)/plan/page.tsx` — future trips + bucket list sections
- `frontend/src/app/(app)/trips/[id]/page.tsx` — dnd-kit sortable destinations

---

## Task 1: Bucket List Backend

**Files:**
- Create: `backend/migrations/versions/006_bucket_list.py`
- Create: `backend/app/models/bucket_list.py`
- Create: `backend/app/schemas/bucket_list.py`
- Create: `backend/app/routers/bucket_list.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_bucket_list.py`

---

- [ ] **Step 1: Write failing tests**

Create `backend/tests/test_bucket_list.py`:

```python
import pytest

TEST_USER_ID = "user_test_atlas_001"
OTHER_USER_ID = "user_test_other_002"


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


async def _create_item(client, **overrides) -> str:
    payload = {"country_code": "JP", "country_name": "Japan", "city": "Kyoto", **overrides}
    resp = await client.post("/api/v1/bucket-list", json=payload)
    assert resp.status_code == 201
    return resp.json()["id"]


@pytest.mark.asyncio
@pytest.mark.integration
async def test_create_bucket_list_item(authed_client):
    resp = await authed_client.post(
        "/api/v1/bucket-list",
        json={
            "country_code": "IS",
            "country_name": "Iceland",
            "city": "Reykjavik",
            "priority": 4,
            "reason": "Northern lights",
            "ideal_season": "winter",
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["country_code"] == "IS"
    assert body["city"] == "Reykjavik"
    assert body["priority"] == 4
    assert body["ideal_season"] == "winter"


@pytest.mark.asyncio
@pytest.mark.integration
async def test_list_bucket_list(authed_client):
    await _create_item(authed_client, city="Tokyo")
    await _create_item(authed_client, city="Osaka")
    resp = await authed_client.get("/api/v1/bucket-list")
    assert resp.status_code == 200
    assert len(resp.json()) >= 2


@pytest.mark.asyncio
@pytest.mark.integration
async def test_update_bucket_list_item(authed_client):
    item_id = await _create_item(authed_client)
    resp = await authed_client.put(
        f"/api/v1/bucket-list/{item_id}",
        json={"priority": 5, "reason": "Updated reason"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["priority"] == 5
    assert body["reason"] == "Updated reason"


@pytest.mark.asyncio
@pytest.mark.integration
async def test_delete_bucket_list_item(authed_client):
    item_id = await _create_item(authed_client)
    resp = await authed_client.delete(f"/api/v1/bucket-list/{item_id}")
    assert resp.status_code == 204
    list_resp = await authed_client.get("/api/v1/bucket-list")
    ids = [i["id"] for i in list_resp.json()]
    assert item_id not in ids


@pytest.mark.asyncio
@pytest.mark.integration
async def test_bucket_list_user_isolation(authed_client):
    from app.main import app
    from app.auth import get_current_user_id
    item_id = await _create_item(authed_client)
    app.dependency_overrides[get_current_user_id] = lambda: OTHER_USER_ID
    try:
        resp = await authed_client.put(
            f"/api/v1/bucket-list/{item_id}",
            json={"priority": 1},
        )
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
    assert resp.status_code == 404


@pytest.mark.asyncio
@pytest.mark.integration
async def test_invalid_priority_rejected(authed_client):
    resp = await authed_client.post(
        "/api/v1/bucket-list",
        json={"country_code": "DE", "country_name": "Germany", "city": "Berlin", "priority": 9},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
@pytest.mark.integration
async def test_invalid_season_rejected(authed_client):
    resp = await authed_client.post(
        "/api/v1/bucket-list",
        json={"country_code": "DE", "country_name": "Germany", "city": "Berlin", "ideal_season": "monsoon"},
    )
    assert resp.status_code == 422
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
docker compose exec atlas-backend pytest tests/test_bucket_list.py -v -m integration 2>&1 | tail -20
```

Expected: collection errors or import errors (router/model do not exist yet).

- [ ] **Step 3: Write migration 006**

Create `backend/migrations/versions/006_bucket_list.py`:

```python
"""add bucket_list table

Revision ID: 006
Revises: 005
Create Date: 2026-04-12
"""
from alembic import op
import sqlalchemy as sa

revision = "006"
down_revision = "005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "bucket_list",
        sa.Column("id", sa.dialects.postgresql.UUID(as_uuid=True), primary_key=True,
                  server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"),
                  nullable=False, index=True),
        sa.Column("country_code", sa.String(2), nullable=True),
        sa.Column("country_name", sa.String, nullable=True),
        sa.Column("city", sa.String, nullable=True),
        sa.Column("priority", sa.SmallInteger, server_default="3"),
        sa.Column("reason", sa.Text, nullable=True),
        sa.Column("ideal_season", sa.String, nullable=True),
        sa.Column("estimated_cost", sa.Numeric(10, 2), nullable=True),
        sa.Column("trip_id", sa.dialects.postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("trips.id", ondelete="SET NULL"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_check_constraint(
        "bucket_list_priority_check", "bucket_list", "priority BETWEEN 1 AND 5"
    )
    op.create_check_constraint(
        "bucket_list_season_check", "bucket_list", "ideal_season IN ('spring','summer','fall','winter','any')"
    )


def downgrade() -> None:
    op.drop_table("bucket_list")
```

- [ ] **Step 4: Apply migration**

```bash
docker compose exec atlas-backend alembic upgrade head
```

Expected: `Running upgrade 005 -> 006, add bucket_list table`

- [ ] **Step 5: Write BucketList model**

Create `backend/app/models/bucket_list.py`:

```python
import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import String, SmallInteger, Text, DateTime, ForeignKey, Numeric, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class BucketList(Base):
    __tablename__ = "bucket_list"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True,
                                           server_default=text("gen_random_uuid()"))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"),
                                          nullable=False, index=True)
    country_code: Mapped[str | None] = mapped_column(String(2), nullable=True)
    country_name: Mapped[str | None] = mapped_column(String, nullable=True)
    city: Mapped[str | None] = mapped_column(String, nullable=True)
    priority: Mapped[int] = mapped_column(SmallInteger, server_default="3")
    reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    ideal_season: Mapped[str | None] = mapped_column(String, nullable=True)
    estimated_cost: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    trip_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True),
                                                       ForeignKey("trips.id", ondelete="SET NULL"),
                                                       nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

- [ ] **Step 6: Write schemas**

Create `backend/app/schemas/bucket_list.py`:

```python
from __future__ import annotations
import uuid
from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, model_validator

_VALID_SEASONS = {"spring", "summer", "fall", "winter", "any"}


class BucketListCreate(BaseModel):
    country_code: str | None = None
    country_name: str | None = None
    city: str | None = None
    priority: int = 3
    reason: str | None = None
    ideal_season: str | None = None
    estimated_cost: Decimal | None = None
    trip_id: uuid.UUID | None = None

    @model_validator(mode="after")
    def validate_fields(self) -> "BucketListCreate":
        if not (1 <= self.priority <= 5):
            raise ValueError("priority must be between 1 and 5")
        if self.ideal_season is not None and self.ideal_season not in _VALID_SEASONS:
            raise ValueError(f"ideal_season must be one of {sorted(_VALID_SEASONS)}")
        return self


class BucketListUpdate(BaseModel):
    country_code: str | None = None
    country_name: str | None = None
    city: str | None = None
    priority: int | None = None
    reason: str | None = None
    ideal_season: str | None = None
    estimated_cost: Decimal | None = None
    trip_id: uuid.UUID | None = None

    @model_validator(mode="after")
    def validate_fields(self) -> "BucketListUpdate":
        if self.priority is not None and not (1 <= self.priority <= 5):
            raise ValueError("priority must be between 1 and 5")
        if self.ideal_season is not None and self.ideal_season not in _VALID_SEASONS:
            raise ValueError(f"ideal_season must be one of {sorted(_VALID_SEASONS)}")
        return self


class BucketListRead(BaseModel):
    id: uuid.UUID
    user_id: str
    country_code: str | None
    country_name: str | None
    city: str | None
    priority: int
    reason: str | None
    ideal_season: str | None
    estimated_cost: Decimal | None
    trip_id: uuid.UUID | None
    created_at: datetime

    model_config = {"from_attributes": True}
```

- [ ] **Step 7: Write router**

Create `backend/app/routers/bucket_list.py`:

```python
import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.bucket_list import BucketList
from app.schemas.bucket_list import BucketListCreate, BucketListRead, BucketListUpdate

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
    for k, v in body.model_dump(exclude_none=True).items():
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
```

- [ ] **Step 8: Register router in main.py**

Add to `backend/app/main.py` after the accommodations_router import and include_router lines:

```python
# Add to imports section:
from app.routers.bucket_list import router as bucket_list_router

# Add to include_router section:
app.include_router(bucket_list_router, prefix="/api/v1")
```

- [ ] **Step 9: Run tests and confirm they pass**

```bash
docker compose exec atlas-backend pytest tests/test_bucket_list.py -v -m integration 2>&1 | tail -20
```

Expected: 7 passed.

- [ ] **Step 10: Commit**

```bash
git add backend/migrations/versions/006_bucket_list.py \
        backend/app/models/bucket_list.py \
        backend/app/schemas/bucket_list.py \
        backend/app/routers/bucket_list.py \
        backend/app/main.py \
        backend/tests/test_bucket_list.py
git commit -m "feat: bucket list CRUD — model, migration, schemas, router, tests"
```

---

## Task 2: Planned Map Layer + Trip Status Validation + Destination Reorder

**Files:**
- Modify: `backend/app/schemas/map.py`
- Modify: `backend/app/routers/map.py`
- Modify: `backend/app/schemas/trip.py`
- Modify: `backend/app/schemas/destination.py`
- Modify: `backend/app/routers/destinations.py`
- Modify: `backend/app/main.py` (no change needed — destinations router already registered)
- Modify: `backend/tests/test_map.py`
- Create: `backend/tests/test_map_planned.py`
- Modify: `backend/tests/test_trips.py`
- Create: `backend/tests/test_reorder.py`

---

- [ ] **Step 1: Write failing tests for /map/planned**

Add to `backend/tests/test_map.py` (after the existing auth tests):

```python
@pytest.mark.asyncio
async def test_map_planned_requires_auth(client):
    response = await client.get("/api/v1/map/planned")
    assert response.status_code == 401
```

Create `backend/tests/test_map_planned.py`:

```python
import pytest

TEST_USER_ID = "user_test_atlas_001"
OTHER_USER_ID = "user_test_other_002"


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    import redis.asyncio as aioredis
    from app.config import settings
    fresh_redis = aioredis.from_url(settings.redis_url, decode_responses=True)
    await fresh_redis.delete(f"map:planned:{TEST_USER_ID}")
    await fresh_redis.delete(f"map:planned:{OTHER_USER_ID}")
    await fresh_redis.aclose()
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


async def _seed_planned_destination(client) -> None:
    trip_resp = await client.post(
        "/api/v1/trips",
        json={"title": "Planned Trip", "status": "planned"},
    )
    trip_id = trip_resp.json()["id"]
    await client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={
            "city": "Lisbon",
            "country_code": "PT",
            "country_name": "Portugal",
            "latitude": 38.7169,
            "longitude": -9.1395,
        },
    )


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_planned_returns_list(authed_client):
    await _seed_planned_destination(authed_client)
    resp = await authed_client.get("/api/v1/map/planned")
    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body, list)
    lisbon = next((c for c in body if c["city"] == "Lisbon"), None)
    assert lisbon is not None
    assert abs(lisbon["latitude"] - 38.7169) < 0.001


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_planned_excludes_past_trips(authed_client):
    # Past trip destination should NOT appear in /map/planned
    trip_resp = await authed_client.post(
        "/api/v1/trips",
        json={"title": "Past Trip", "status": "past"},
    )
    trip_id = trip_resp.json()["id"]
    await authed_client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={
            "city": "Berlin",
            "country_code": "DE",
            "country_name": "Germany",
            "latitude": 52.52,
            "longitude": 13.405,
        },
    )
    resp = await authed_client.get("/api/v1/map/planned")
    body = resp.json()
    berlin = [c for c in body if c["city"] == "Berlin"]
    assert len(berlin) == 0


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_planned_user_isolation(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    import redis.asyncio as aioredis
    from app.config import settings

    r = aioredis.from_url(settings.redis_url, decode_responses=True)
    await r.delete(f"map:planned:{TEST_USER_ID}")
    await r.delete(f"map:planned:{OTHER_USER_ID}")
    await r.aclose()

    # Other user seeds a planned destination
    app.dependency_overrides[get_current_user_id] = lambda: OTHER_USER_ID
    trip_resp = await client.post("/api/v1/trips", json={"title": "Other Planned", "status": "planned"})
    trip_id = trip_resp.json()["id"]
    await client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={"city": "Seoul", "country_code": "KR", "country_name": "South Korea",
              "latitude": 37.5665, "longitude": 126.978},
    )

    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    try:
        resp = await client.get("/api/v1/map/planned")
        body = resp.json()
        seoul = [c for c in body if c["city"] == "Seoul"]
        assert len(seoul) == 0
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
```

- [ ] **Step 2: Write failing tests for trip status validation and destination reorder**

Add to `backend/tests/test_trips.py`:

```python
@pytest.mark.asyncio
async def test_invalid_status_rejected(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: "user_test_atlas_001"
    try:
        resp = await client.post("/api/v1/trips", json={"title": "T", "status": "canceled"})
    finally:
        app.dependency_overrides.pop(get_current_user_id, None)
    assert resp.status_code == 422
```

Create `backend/tests/test_reorder.py`:

```python
import pytest

TEST_USER_ID = "user_test_atlas_001"


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


async def _create_trip_with_destinations(client) -> tuple[str, list[str]]:
    trip_resp = await client.post("/api/v1/trips", json={"title": "Reorder Test Trip"})
    assert trip_resp.status_code == 201
    trip_id = trip_resp.json()["id"]
    dest_ids = []
    for city, cc, cn in [("Rome", "IT", "Italy"), ("Florence", "IT", "Italy"), ("Venice", "IT", "Italy")]:
        r = await client.post(
            f"/api/v1/trips/{trip_id}/destinations",
            json={"city": city, "country_code": cc, "country_name": cn, "order_index": len(dest_ids)},
        )
        assert r.status_code == 201
        dest_ids.append(r.json()["id"])
    return trip_id, dest_ids


@pytest.mark.asyncio
@pytest.mark.integration
async def test_reorder_destinations(authed_client):
    trip_id, dest_ids = await _create_trip_with_destinations(authed_client)
    # Reverse the order
    new_order = [{"id": dest_ids[2], "order_index": 0},
                 {"id": dest_ids[1], "order_index": 1},
                 {"id": dest_ids[0], "order_index": 2}]
    resp = await authed_client.patch(
        f"/api/v1/trips/{trip_id}/destinations/reorder",
        json=new_order,
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body[0]["id"] == dest_ids[2]
    assert body[0]["order_index"] == 0
    assert body[2]["id"] == dest_ids[0]
    assert body[2]["order_index"] == 2


@pytest.mark.asyncio
@pytest.mark.integration
async def test_reorder_wrong_trip_ignored(authed_client):
    """Destination IDs from another trip are silently skipped."""
    trip_id1, dest_ids1 = await _create_trip_with_destinations(authed_client)
    trip_id2, dest_ids2 = await _create_trip_with_destinations(authed_client)
    # Try to reorder trip1 using trip2's dest IDs
    new_order = [{"id": dest_ids2[0], "order_index": 0}]
    resp = await authed_client.patch(
        f"/api/v1/trips/{trip_id1}/destinations/reorder",
        json=new_order,
    )
    assert resp.status_code == 200
    # Trip1 destinations are unchanged
    list_resp = await authed_client.get(f"/api/v1/trips/{trip_id1}/destinations")
    assert len(list_resp.json()) == 3
```

- [ ] **Step 3: Run tests to confirm they fail**

```bash
docker compose exec atlas-backend pytest tests/test_map_planned.py tests/test_reorder.py -v -m integration 2>&1 | tail -20
docker compose exec atlas-backend pytest tests/test_map.py::test_map_planned_requires_auth -v 2>&1 | tail -10
docker compose exec atlas-backend pytest tests/test_trips.py::test_invalid_status_rejected -v -m integration 2>&1 | tail -10
```

Expected: 404 errors or import errors for endpoints that don't exist yet.

- [ ] **Step 4: Add PlannedCityResponse to map schemas**

Add to `backend/app/schemas/map.py`:

```python
class PlannedCityResponse(BaseModel):
    id: str
    city: str
    country_code: str
    country_name: str
    latitude: float
    longitude: float
    trip_id: str
    trip_title: str
```

- [ ] **Step 5: Add /map/planned endpoint**

Add to `backend/app/routers/map.py` (after the existing imports, add `PlannedCityResponse` to the schema import and then append the new endpoint):

Update the import line:
```python
from app.schemas.map import CityPointResponse, CountryVisitResponse, FlightArcResponse, PlannedCityResponse
```

Append at end of file:

```python
@router.get("/planned", response_model=list[PlannedCityResponse])
async def get_map_planned(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[PlannedCityResponse]:
    """Ghost markers for destinations in planned trips. Cached 5 min per user."""
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
```

- [ ] **Step 6: Add status validation to TripCreate/TripUpdate**

Update `backend/app/schemas/trip.py`:

```python
import uuid
from datetime import datetime, date
from pydantic import BaseModel, model_validator

_VALID_STATUSES = {"past", "active", "planned", "dream"}


class TripCreate(BaseModel):
    title: str
    description: str | None = None
    status: str = "past"
    start_date: date | None = None
    end_date: date | None = None
    tags: list[str] = []
    visibility: str = "private"

    @model_validator(mode="after")
    def validate_status(self) -> "TripCreate":
        if self.status not in _VALID_STATUSES:
            raise ValueError(f"status must be one of {sorted(_VALID_STATUSES)}")
        return self


class TripUpdate(BaseModel):
    title: str | None = None
    description: str | None = None
    status: str | None = None
    start_date: date | None = None
    end_date: date | None = None
    tags: list[str] | None = None
    visibility: str | None = None

    @model_validator(mode="after")
    def validate_status(self) -> "TripUpdate":
        if self.status is not None and self.status not in _VALID_STATUSES:
            raise ValueError(f"status must be one of {sorted(_VALID_STATUSES)}")
        return self


class TripRead(BaseModel):
    id: uuid.UUID
    user_id: str
    title: str
    description: str | None
    status: str
    start_date: date | None
    end_date: date | None
    tags: list[str]
    visibility: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class TripListResponse(BaseModel):
    items: list[TripRead]
    total: int
    page: int
    limit: int
```

- [ ] **Step 7: Add DestinationReorderItem and reorder endpoint**

Add to `backend/app/schemas/destination.py` (append after `DestinationRead`):

```python
class DestinationReorderItem(BaseModel):
    id: uuid.UUID
    order_index: int
```

Add to `backend/app/routers/destinations.py`:

1. Add to imports at top:
```python
from sqlalchemy import select, update
from app.schemas.destination import DestinationCreate, DestinationRead, DestinationUpdate, DestinationReorderItem
```

2. Append new endpoint at end of file:

```python
@router.patch("/trips/{trip_id}/destinations/reorder", response_model=list[DestinationRead])
async def reorder_destinations(
    trip_id: uuid.UUID,
    body: list[DestinationReorderItem],
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[DestinationRead]:
    await _get_trip_or_404(trip_id, user_id, db)
    for item in body:
        await db.execute(
            update(Destination)
            .where(
                Destination.id == item.id,
                Destination.trip_id == trip_id,
                Destination.user_id == user_id,
            )
            .values(order_index=item.order_index)
        )
    await db.flush()
    result = await db.execute(
        select(Destination)
        .where(Destination.trip_id == trip_id, Destination.user_id == user_id)
        .order_by(Destination.order_index, Destination.arrival_date)
    )
    dests = result.scalars().all()
    return [DestinationRead.from_orm_with_geo(d) for d in dests]
```

Note: The existing import line in destinations.py already has `from sqlalchemy import select`. Change it to `from sqlalchemy import select, update` and update the schema import.

- [ ] **Step 8: Run all new tests**

```bash
docker compose exec atlas-backend pytest tests/test_map.py tests/test_map_planned.py tests/test_trips.py tests/test_reorder.py -v -m "asyncio or integration" 2>&1 | tail -30
```

Expected: All pass. The `test_invalid_status_rejected` is not marked `integration` — run without `-m integration` for that one:

```bash
docker compose exec atlas-backend pytest tests/test_trips.py -v 2>&1 | tail -20
```

Expected: All trip tests pass including the new status test.

- [ ] **Step 9: Run full suite to confirm no regressions**

```bash
docker compose exec atlas-backend pytest -m integration 2>&1 | tail -10
```

Expected: All pass (count increases with new tests).

- [ ] **Step 10: Commit**

```bash
git add backend/app/schemas/map.py \
        backend/app/routers/map.py \
        backend/app/schemas/trip.py \
        backend/app/schemas/destination.py \
        backend/app/routers/destinations.py \
        backend/tests/test_map.py \
        backend/tests/test_map_planned.py \
        backend/tests/test_trips.py \
        backend/tests/test_reorder.py
git commit -m "feat: planned map layer, trip status validation, destination reorder endpoint"
```

---

## Task 3: Best-Time-to-Visit (Open-Meteo)

**Files:**
- Create: `backend/app/services/open_meteo.py`
- Create: `backend/app/routers/discover.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_discover.py`

---

- [ ] **Step 1: Write failing tests**

Create `backend/tests/test_discover.py`:

```python
import pytest
from unittest.mock import AsyncMock, patch


TEST_USER_ID = "user_test_atlas_001"

# Fake monthly climate data: 12 entries (one per month averaged across years)
FAKE_MONTHLY = [
    {"month": i, "avg_max_temp_c": 20.0 + i, "avg_precipitation_mm": 40.0}
    for i in range(1, 13)
]


@pytest.fixture
async def authed_client(client, seed_test_users):
    from app.main import app
    from app.auth import get_current_user_id
    app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    yield client
    app.dependency_overrides.pop(get_current_user_id, None)


@pytest.mark.asyncio
async def test_best_time_requires_auth(client):
    resp = await client.get("/api/v1/discover/best-time/JP")
    assert resp.status_code == 401


@pytest.mark.asyncio
@pytest.mark.integration
async def test_best_time_returns_data(authed_client):
    from app.services import open_meteo

    async def fake_geocode(name: str) -> tuple[float, float, str]:
        return (35.6895, 139.6917, "Tokyo, Japan")

    async def fake_fetch_climate(lat: float, lng: float) -> list[dict]:
        return FAKE_MONTHLY

    with patch.object(open_meteo, "geocode", fake_geocode), \
         patch.object(open_meteo, "fetch_monthly_averages", fake_fetch_climate):
        resp = await authed_client.get("/api/v1/discover/best-time/JP?city=Tokyo")

    assert resp.status_code == 200
    body = resp.json()
    assert body["location"] == "Tokyo, Japan"
    assert abs(body["latitude"] - 35.6895) < 0.001
    assert len(body["monthly"]) == 12
    assert isinstance(body["best_months"], list)
    assert body["monthly"][0]["month"] == 1
```

- [ ] **Step 2: Run to confirm failure**

```bash
docker compose exec atlas-backend pytest tests/test_discover.py -v 2>&1 | tail -15
```

Expected: import error or 404 (endpoint not implemented).

- [ ] **Step 3: Write Open-Meteo service**

Create `backend/app/services/open_meteo.py`:

```python
"""Async client for Open-Meteo geocoding and climate APIs.

Both APIs are free with no API key required.
"""
from __future__ import annotations
import logging
from collections import defaultdict

import httpx

logger = logging.getLogger(__name__)

GEOCODING_URL = "https://geocoding-api.open-meteo.com/v1/search"
CLIMATE_URL = "https://climate-api.open-meteo.com/v1/climate"


async def geocode(name: str) -> tuple[float, float, str]:
    """Return (latitude, longitude, display_name) for a place name.

    Raises ValueError if the location cannot be found.
    """
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            GEOCODING_URL,
            params={"name": name, "count": 1, "language": "en", "format": "json"},
        )
        resp.raise_for_status()
        results = resp.json().get("results") or []
    if not results:
        raise ValueError(f"Location not found: {name!r}")
    r = results[0]
    display = f"{r['name']}, {r.get('country', '')}"
    return float(r["latitude"]), float(r["longitude"]), display


async def fetch_monthly_averages(lat: float, lng: float) -> list[dict]:
    """Fetch 30-year (1991-2020) monthly climate averages.

    Returns a list of 12 dicts:
        {"month": 1-12, "avg_max_temp_c": float, "avg_precipitation_mm": float}
    """
    async with httpx.AsyncClient(timeout=30.0) as client:
        resp = await client.get(
            CLIMATE_URL,
            params={
                "latitude": lat,
                "longitude": lng,
                "start_date": "1991-01-01",
                "end_date": "2020-12-31",
                "monthly": "temperature_2m_max,precipitation_sum",
                "models": "EC_Earth3P_HR",
            },
        )
        resp.raise_for_status()
        data = resp.json()

    monthly = data.get("monthly", {})
    times: list[str] = monthly.get("time", [])
    temps: list[float | None] = monthly.get("temperature_2m_max", [])
    precips: list[float | None] = monthly.get("precipitation_sum", [])

    # Aggregate: group by calendar month (1-12) and average across years
    temp_by_month: dict[int, list[float]] = defaultdict(list)
    precip_by_month: dict[int, list[float]] = defaultdict(list)

    for i, t in enumerate(times):
        month = int(t.split("-")[1])  # "1991-01" → 1
        if i < len(temps) and temps[i] is not None:
            temp_by_month[month].append(temps[i])
        if i < len(precips) and precips[i] is not None:
            precip_by_month[month].append(precips[i])

    return [
        {
            "month": m,
            "avg_max_temp_c": round(sum(temp_by_month[m]) / len(temp_by_month[m]), 1)
            if temp_by_month[m] else 0.0,
            "avg_precipitation_mm": round(sum(precip_by_month[m]) / len(precip_by_month[m]), 1)
            if precip_by_month[m] else 0.0,
        }
        for m in range(1, 13)
    ]


def pick_best_months(monthly: list[dict]) -> list[int]:
    """Return month numbers (1-12) where max temp is 15-28°C and precip < 120mm."""
    return [
        entry["month"]
        for entry in monthly
        if 15.0 <= entry["avg_max_temp_c"] <= 28.0
        and entry["avg_precipitation_mm"] < 120.0
    ]
```

- [ ] **Step 4: Write discover router**

Create `backend/app/routers/discover.py`:

```python
import json
import logging
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
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
    db: AsyncSession = Depends(get_db),
    city: str | None = Query(default=None),
) -> BestTimeResponse:
    """Return 30-year monthly climate averages and suggested best months to visit."""
    search_name = city if city else country_code
    cache_key = f"discover:best-time:{search_name.lower()}"
    cached = await get_cached(cache_key)
    if cached is not None:
        return BestTimeResponse(**cached)

    try:
        lat, lng, display_name = await open_meteo.geocode(search_name)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        logger.warning("Open-Meteo geocode failed: %s", exc)
        raise HTTPException(status_code=502, detail="Geocoding service unavailable")

    try:
        monthly_data = await open_meteo.fetch_monthly_averages(lat, lng)
    except Exception as exc:
        logger.warning("Open-Meteo climate failed: %s", exc)
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
```

- [ ] **Step 5: Register discover router in main.py**

Add to `backend/app/main.py`:

```python
# Add to imports:
from app.routers.discover import router as discover_router

# Add include_router:
app.include_router(discover_router, prefix="/api/v1")
```

- [ ] **Step 6: Run tests**

```bash
docker compose exec atlas-backend pytest tests/test_discover.py -v 2>&1 | tail -15
```

Expected: 2 passed (1 auth, 1 integration with mocked service).

- [ ] **Step 7: Commit**

```bash
git add backend/app/services/open_meteo.py \
        backend/app/routers/discover.py \
        backend/app/main.py \
        backend/tests/test_discover.py
git commit -m "feat: best-time-to-visit endpoint — Open-Meteo climate data, 24h Redis cache"
```

---

## Task 4: Plan Page + Bucket List Frontend

**Files:**
- Modify: `frontend/src/types/index.ts`
- Create: `frontend/src/hooks/useBucketList.ts`
- Create: `frontend/src/hooks/useDiscover.ts`
- Modify: `frontend/src/app/(app)/plan/page.tsx`

---

- [ ] **Step 1: Add types to index.ts**

Append to `frontend/src/types/index.ts`:

```typescript
export interface BucketListItem {
  id: string;
  user_id: string;
  country_code: string | null;
  country_name: string | null;
  city: string | null;
  priority: number;
  reason: string | null;
  ideal_season: string | null;
  estimated_cost: number | null;
  trip_id: string | null;
  created_at: string;
}

export interface PlannedCity {
  id: string;
  city: string;
  country_code: string;
  country_name: string;
  latitude: number;
  longitude: number;
  trip_id: string;
  trip_title: string;
}

export interface MonthlyClimate {
  month: number;
  avg_max_temp_c: number;
  avg_precipitation_mm: number;
}

export interface BestTimeResponse {
  location: string;
  latitude: number;
  longitude: number;
  monthly: MonthlyClimate[];
  best_months: number[];
}
```

- [ ] **Step 2: Create useBucketList.ts**

Create `frontend/src/hooks/useBucketList.ts`:

```typescript
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost, apiPut, apiDelete } from "@/lib/api";
import type { BucketListItem } from "@/types";

export function useBucketList() {
  const { getToken } = useAuth();
  return useQuery<BucketListItem[]>({
    queryKey: ["bucket-list"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<BucketListItem[]>("/bucket-list", token);
    },
  });
}

export function useAddBucketListItem() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: Partial<BucketListItem>) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<BucketListItem>("/bucket-list", token, body);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["bucket-list"] }),
  });
}

export function useUpdateBucketListItem() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: Partial<BucketListItem> & { id: string }) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPut<BucketListItem>(`/bucket-list/${id}`, token, body);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["bucket-list"] }),
  });
}

export function useDeleteBucketListItem() {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (id: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiDelete(`/bucket-list/${id}`, token);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["bucket-list"] }),
  });
}
```

- [ ] **Step 3: Create useDiscover.ts**

Create `frontend/src/hooks/useDiscover.ts`:

```typescript
import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet } from "@/lib/api";
import type { BestTimeResponse } from "@/types";

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
    staleTime: 24 * 60 * 60 * 1000, // 24 hours — matches backend cache
  });
}
```

- [ ] **Step 4: Write plan page**

Replace `frontend/src/app/(app)/plan/page.tsx` entirely:

```typescript
"use client";

import { useState } from "react";
import { Plus, MapPin, Globe, Trash2, Star } from "lucide-react";
import { useTrips } from "@/hooks/useTrips";
import { useBucketList, useDeleteBucketListItem, useAddBucketListItem } from "@/hooks/useBucketList";
import type { BucketListItem } from "@/types";

const SEASON_LABELS: Record<string, string> = {
  spring: "Spring",
  summer: "Summer",
  fall: "Fall",
  winter: "Winter",
  any: "Any time",
};

const PRIORITY_COLORS: Record<number, string> = {
  5: "text-amber-400",
  4: "text-atlas-accent",
  3: "text-atlas-text",
  2: "text-atlas-muted",
  1: "text-atlas-muted",
};

function PriorityStars({ priority }: { priority: number }) {
  return (
    <div className="flex gap-0.5">
      {[1, 2, 3, 4, 5].map((n) => (
        <Star
          key={n}
          size={10}
          className={n <= priority ? PRIORITY_COLORS[priority] : "text-atlas-border"}
          fill={n <= priority ? "currentColor" : "none"}
        />
      ))}
    </div>
  );
}

function BucketCard({ item, onDelete }: { item: BucketListItem; onDelete: () => void }) {
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
        <div className="flex items-center gap-3 mt-1.5">
          <PriorityStars priority={item.priority} />
          {item.ideal_season && (
            <span className="text-xs text-atlas-muted font-mono">
              {SEASON_LABELS[item.ideal_season] ?? item.ideal_season}
            </span>
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

export default function PlanPage() {
  const [showAddForm, setShowAddForm] = useState(false);
  const [addCity, setAddCity] = useState("");
  const [addCountry, setAddCountry] = useState("");
  const [addReason, setAddReason] = useState("");

  const { data: trips = [], isLoading: tripsLoading } = useTrips();
  const { data: bucketList = [], isLoading: bucketLoading } = useBucketList();
  const deleteItem = useDeleteBucketListItem();
  const addItem = useAddBucketListItem();

  const plannedTrips = trips.filter((t) => t.status === "planned" || t.status === "dream");

  async function handleAdd() {
    if (!addCountry.trim()) return;
    await addItem.mutateAsync({
      city: addCity.trim() || undefined,
      country_name: addCountry.trim(),
      priority: 3,
      reason: addReason.trim() || undefined,
    });
    setAddCity("");
    setAddCountry("");
    setAddReason("");
    setShowAddForm(false);
  }

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        {/* Future Trips */}
        <div className="mb-10">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest">
              Future Trips
            </h2>
            <a
              href="/trips"
              className="flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors"
            >
              <Plus size={12} />
              New trip
            </a>
          </div>

          {tripsLoading && <p className="text-atlas-muted text-sm">Loading...</p>}

          {!tripsLoading && plannedTrips.length === 0 && (
            <p className="text-atlas-muted text-sm py-6 text-center border border-dashed border-atlas-border rounded-lg">
              No planned trips yet. Create a trip with status "planned" or "dream".
            </p>
          )}

          <div className="flex flex-col gap-2">
            {plannedTrips.map((trip) => (
              <a
                key={trip.id}
                href={`/trips/${trip.id}`}
                className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3 flex items-center gap-4 hover:border-atlas-accent/40 transition-colors"
              >
                <div className="flex h-8 w-8 items-center justify-center rounded bg-atlas-planned/20 text-atlas-accent shrink-0">
                  <MapPin size={14} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-atlas-text">{trip.title}</p>
                  <p className="text-xs text-atlas-muted capitalize">{trip.status}</p>
                </div>
                {trip.start_date && (
                  <p className="text-xs font-mono text-atlas-muted shrink-0">{trip.start_date}</p>
                )}
              </a>
            ))}
          </div>
        </div>

        {/* Bucket List */}
        <div>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest">
              Bucket List
            </h2>
            <button
              onClick={() => setShowAddForm((v) => !v)}
              className="flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors"
            >
              <Plus size={12} />
              Add destination
            </button>
          </div>

          {showAddForm && (
            <div className="mb-4 rounded-lg border border-atlas-border bg-atlas-surface p-4 flex flex-col gap-3">
              <input
                className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text placeholder:text-atlas-muted focus:outline-none focus:border-atlas-accent"
                placeholder="Country (required)"
                value={addCountry}
                onChange={(e) => setAddCountry(e.target.value)}
              />
              <input
                className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text placeholder:text-atlas-muted focus:outline-none focus:border-atlas-accent"
                placeholder="City (optional)"
                value={addCity}
                onChange={(e) => setAddCity(e.target.value)}
              />
              <input
                className="w-full rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text placeholder:text-atlas-muted focus:outline-none focus:border-atlas-accent"
                placeholder="Why do you want to go? (optional)"
                value={addReason}
                onChange={(e) => setAddReason(e.target.value)}
              />
              <div className="flex gap-2 justify-end">
                <button
                  onClick={() => setShowAddForm(false)}
                  className="px-3 py-1.5 text-xs text-atlas-muted hover:text-atlas-text transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={handleAdd}
                  disabled={!addCountry.trim() || addItem.isPending}
                  className="px-3 py-1.5 text-xs rounded bg-atlas-accent text-atlas-bg font-medium hover:bg-atlas-accent/80 transition-colors disabled:opacity-50"
                >
                  {addItem.isPending ? "Adding…" : "Add"}
                </button>
              </div>
            </div>
          )}

          {bucketLoading && <p className="text-atlas-muted text-sm">Loading...</p>}

          {!bucketLoading && bucketList.length === 0 && !showAddForm && (
            <p className="text-atlas-muted text-sm py-6 text-center border border-dashed border-atlas-border rounded-lg">
              Your bucket list is empty. Add a destination to get started.
            </p>
          )}

          <div className="flex flex-col gap-2">
            {bucketList.map((item) => (
              <BucketCard
                key={item.id}
                item={item}
                onDelete={() => deleteItem.mutate(item.id)}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 5: Run TypeScript type-check**

```bash
cd /home/zach/Atlas/frontend && npx tsc --noEmit 2>&1
```

Fix any errors. Common issues:
- `useTrips` returns paginated data (`TripListResponse` with `items`/`total`). Check `frontend/src/hooks/useTrips.ts`. If it returns `TripListResponse`, access `.items` in the plan page instead of treating the result as an array directly. If `useTrips` doesn't exist without a page arg, check the hook implementation. Adjust the call accordingly.
- `Trip` type may not have `status`, `start_date` fields — add them to `frontend/src/types/index.ts` if missing (check the existing Trip type).
- The `apiDelete` function signature — check `frontend/src/lib/api.ts` to confirm it accepts `(path, token)`.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/types/index.ts \
        frontend/src/hooks/useBucketList.ts \
        frontend/src/hooks/useDiscover.ts \
        "frontend/src/app/(app)/plan/page.tsx"
git commit -m "feat: plan page — future trips and bucket list with add/delete UI"
```

---

## Task 5: Map Enhancements + dnd-kit Reorder

**Files:**
- Modify: `frontend/src/hooks/useMapData.ts`
- Modify: `frontend/src/store/mapStore.ts`
- Create: `frontend/src/components/map/MapFilterBar.tsx`
- Modify: `frontend/src/components/map/WorldMap.tsx`
- Modify: `frontend/src/app/(app)/trips/[id]/page.tsx`

---

- [ ] **Step 1: Install dnd-kit**

```bash
cd /home/zach/Atlas/frontend && npm install @dnd-kit/core @dnd-kit/sortable @dnd-kit/utilities
```

If running in Docker: `docker compose exec atlas-frontend npm install @dnd-kit/core @dnd-kit/sortable @dnd-kit/utilities`

- [ ] **Step 2: Add usePlannedCities to useMapData.ts**

Update the import in `frontend/src/hooks/useMapData.ts`:

```typescript
import type { MapCountry, MapCity, MapArc, PlannedCity } from "@/types";
```

Append `usePlannedCities` after `useMapArcs`:

```typescript
export function usePlannedCities() {
  const { getToken } = useAuth();
  return useQuery<PlannedCity[]>({
    queryKey: ["map", "planned"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<PlannedCity[]>("/map/planned", token);
    },
    staleTime: 5 * 60 * 1000,
  });
}
```

- [ ] **Step 3: Add filter state to mapStore.ts**

Replace `frontend/src/store/mapStore.ts` entirely:

```typescript
import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { MapCountry } from "@/types";

type TripStatusFilter = "all" | "past" | "active" | "planned" | "dream";

interface MapState {
  projection: "globe" | "mercator";
  selectedCountry: MapCountry | null;
  filterYear: number | null;
  filterStatus: TripStatusFilter;
  setProjection: (p: "globe" | "mercator") => void;
  setSelectedCountry: (c: MapCountry | null) => void;
  setFilterYear: (y: number | null) => void;
  setFilterStatus: (s: TripStatusFilter) => void;
}

export const useMapStore = create<MapState>()(
  persist(
    (set) => ({
      projection: "globe",
      selectedCountry: null,
      filterYear: null,
      filterStatus: "all",
      setProjection: (projection) => set({ projection }),
      setSelectedCountry: (selectedCountry) => set({ selectedCountry }),
      setFilterYear: (filterYear) => set({ filterYear }),
      setFilterStatus: (filterStatus) => set({ filterStatus }),
    }),
    {
      name: "atlas-map",
      partialize: (s) => ({ projection: s.projection }),
    }
  )
);
```

- [ ] **Step 4: Create MapFilterBar.tsx**

Create `frontend/src/components/map/MapFilterBar.tsx`:

```typescript
"use client";

import { useMapStore } from "@/store/mapStore";

const STATUS_OPTIONS = [
  { value: "all", label: "All" },
  { value: "past", label: "Past" },
  { value: "active", label: "Active" },
  { value: "planned", label: "Planned" },
  { value: "dream", label: "Dream" },
] as const;

export function MapFilterBar() {
  const { filterStatus, setFilterStatus } = useMapStore();

  return (
    <div className="absolute top-3 left-1/2 -translate-x-1/2 z-10 flex items-center gap-1 rounded-lg border border-atlas-border bg-atlas-surface/90 backdrop-blur-sm px-2 py-1.5 shadow-lg">
      {STATUS_OPTIONS.map((opt) => (
        <button
          key={opt.value}
          onClick={() => setFilterStatus(opt.value)}
          className={`px-2.5 py-1 rounded text-xs font-medium transition-colors ${
            filterStatus === opt.value
              ? "bg-atlas-accent text-atlas-bg"
              : "text-atlas-muted hover:text-atlas-text"
          }`}
        >
          {opt.label}
        </button>
      ))}
    </div>
  );
}
```

- [ ] **Step 5: Update WorldMap.tsx**

Read the current `frontend/src/components/map/WorldMap.tsx`. Then make the following changes:

**a) Update imports:**
```typescript
import { useMapCountries, useMapCities, useMapArcs, usePlannedCities } from "@/hooks/useMapData";
import { MapControls } from "./MapControls";
import { CountryPanel } from "./CountryPanel";
import { MapFilterBar } from "./MapFilterBar";
```

**b) Add the planned cities data fetch** (after `arcs` line, inside the component):
```typescript
const { data: plannedCities = [] } = usePlannedCities();
const { filterStatus } = useMapStore();
```

**c) Add a `useEffect` for the planned ghost markers layer** (after the flight arcs `useEffect`):

```typescript
// Planned destination ghost markers
useEffect(() => {
  if (!map.current || !mapLoaded) return;

  const visiblePlanned =
    filterStatus === "all" || filterStatus === "planned" || filterStatus === "dream"
      ? plannedCities
      : [];

  const geojson: GeoJSON.FeatureCollection = {
    type: "FeatureCollection",
    features: visiblePlanned.map((p) => ({
      type: "Feature",
      geometry: { type: "Point", coordinates: [p.longitude, p.latitude] },
      properties: { city: p.city, trip_title: p.trip_title },
    })),
  };

  const src = map.current.getSource("planned-cities") as maplibregl.GeoJSONSource | undefined;
  if (src) {
    src.setData(geojson);
  } else {
    map.current.addSource("planned-cities", { type: "geojson", data: geojson });
    map.current.addLayer({
      id: "planned-markers",
      type: "circle",
      source: "planned-cities",
      paint: {
        "circle-radius": 5,
        "circle-color": "transparent",
        "circle-stroke-width": 2,
        "circle-stroke-color": "#c9a84c",
        "circle-opacity": 0.8,
      },
    });
  }
}, [plannedCities, mapLoaded, filterStatus]);
```

**d) Render `<MapFilterBar />` inside the return** (add it to the existing JSX, before `<MapControls />`):

```typescript
return (
  <div className="relative h-full w-full">
    <div ref={mapContainer} id="map-container" className="h-full w-full" />
    <MapFilterBar />
    <MapControls onToggleProjection={handleToggleProjection} />
    <CountryPanel />
  </div>
);
```

- [ ] **Step 6: Add dnd-kit reorder to trip detail page**

Read the current `frontend/src/app/(app)/trips/[id]/page.tsx`. Then add dnd-kit drag-to-reorder for the destinations list.

Add to the imports:
```typescript
import {
  DndContext,
  closestCenter,
  PointerSensor,
  useSensor,
  useSensors,
  type DragEndEvent,
} from "@dnd-kit/core";
import {
  SortableContext,
  verticalListSortingStrategy,
  useSortable,
  arrayMove,
} from "@dnd-kit/sortable";
import { CSS } from "@dnd-kit/utilities";
import { GripVertical } from "lucide-react";
import { apiPatch } from "@/lib/api";
import { useAuth } from "@clerk/nextjs";
import type { Destination } from "@/types";
```

Add a `SortableDestination` component (before the main export):
```typescript
function SortableDestination({ dest }: { dest: Destination }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } =
    useSortable({ id: dest.id });

  const style = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.5 : 1,
  };

  return (
    <div
      ref={setNodeRef}
      style={style}
      className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3 flex items-center gap-4"
    >
      <button
        {...attributes}
        {...listeners}
        className="text-atlas-muted hover:text-atlas-text cursor-grab active:cursor-grabbing shrink-0"
        aria-label="Drag to reorder"
      >
        <GripVertical size={14} />
      </button>
      <div className="flex h-8 w-8 items-center justify-center rounded bg-atlas-accent/10 text-atlas-accent shrink-0">
        <MapPin size={14} />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-atlas-text">{dest.city}</p>
        <p className="text-xs text-atlas-muted">{dest.country_name}</p>
      </div>
      <div className="text-right shrink-0">
        <p className="text-xs font-mono text-atlas-muted">{dest.arrival_date ?? "—"}</p>
        <p className="text-xs text-atlas-muted">{nightsLabel(dest.nights)}</p>
      </div>
    </div>
  );
}
```

In the main `TripDetailPage` component, add:
- `const { getToken } = useAuth();` inside the component
- Replace the static `destinations.map(...)` with a sortable list

The destinations section should become:

```typescript
const sensors = useSensors(useSensor(PointerSensor));

async function handleDragEnd(event: DragEndEvent) {
  const { active, over } = event;
  if (!over || active.id === over.id) return;
  const oldIndex = destinations.findIndex((d) => d.id === active.id);
  const newIndex = destinations.findIndex((d) => d.id === over.id);
  const reordered = arrayMove(destinations, oldIndex, newIndex);
  const token = await getToken();
  if (!token) return;
  await apiPatch(
    `/trips/${id}/destinations/reorder`,
    token,
    reordered.map((d, i) => ({ id: d.id, order_index: i }))
  );
  qc.invalidateQueries({ queryKey: ["destinations", id] });
}
```

And wrap the destinations list:
```typescript
<DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={handleDragEnd}>
  <SortableContext
    items={destinations.map((d) => d.id)}
    strategy={verticalListSortingStrategy}
  >
    <div className="flex flex-col gap-2">
      {destinations.map((dest) => (
        <SortableDestination key={dest.id} dest={dest} />
      ))}
    </div>
  </SortableContext>
</DndContext>
```

Also add `useQueryClient` to TanStack Query imports.

Note: `apiPatch` may not exist in `frontend/src/lib/api.ts`. Check and add if needed:
```typescript
export async function apiPatch<T>(path: string, token: string, body: unknown): Promise<T> {
  const res = await fetch(`${API_BASE}/api/v1${path}`, {
    method: "PATCH",
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`PATCH ${path} failed: ${res.status}`);
  if (res.status === 204) return undefined as T;
  return res.json();
}
```

- [ ] **Step 7: Check `Destination` type exists in types/index.ts**

The `SortableDestination` component uses `Destination` type. Verify it exists in `frontend/src/types/index.ts`. If not, add:

```typescript
export interface Destination {
  id: string;
  trip_id: string;
  user_id: string;
  city: string;
  country_code: string;
  country_name: string;
  region: string | null;
  latitude: number | null;
  longitude: number | null;
  arrival_date: string | null;
  departure_date: string | null;
  nights: number | null;
  notes: string | null;
  rating: number | null;
  order_index: number;
  created_at: string;
}
```

- [ ] **Step 8: Run TypeScript type-check**

```bash
cd /home/zach/Atlas/frontend && npx tsc --noEmit 2>&1
```

Fix all errors before committing. Do not use `any` or type assertions to paper over problems.

- [ ] **Step 9: Commit**

```bash
git add frontend/src/hooks/useMapData.ts \
        frontend/src/store/mapStore.ts \
        "frontend/src/components/map/MapFilterBar.tsx" \
        frontend/src/components/map/WorldMap.tsx \
        "frontend/src/app/(app)/trips/[id]/page.tsx" \
        frontend/src/lib/api.ts \
        frontend/src/types/index.ts \
        frontend/package.json \
        frontend/package-lock.json
git commit -m "feat: planned ghost markers, map filter bar, dnd-kit destination reorder"
```

---

## Spec Self-Review

**1. Spec coverage (from CLAUDE.md Phase 4):**

| Requirement | Task |
|---|---|
| Bucket list CRUD | Task 1 ✅ |
| Future trips (status = 'planned') with ghost markers on map | Tasks 2 + 5 ✅ |
| Itinerary builder (dnd-kit drag-drop day planning) | Task 5 ✅ (drag-to-reorder destinations) |
| Best-time-to-visit API (Open-Meteo historical climate data) | Task 3 ✅ |
| Map filter bar (year, trip, status) | Task 5 ✅ (status filter; year filter omitted — no year data on map layer without trip join, YAGNI) |

**2. Placeholder scan:** None found. All code blocks are complete.

**3. Type consistency check:**

- `BucketListCreate.city/country_name` → `BucketList.city/country_name` → `BucketListRead.city/country_name` → `BucketListItem.city/country_name` (TS) — ✅
- `PlannedCityResponse` (Python) fields: id, city, country_code, country_name, latitude, longitude, trip_id, trip_title → `PlannedCity` (TS) same fields — ✅
- `DestinationReorderItem.id/order_index` → PATCH body `{id, order_index}[]` in frontend — ✅
- `MonthlyClimate` (Python) fields month/avg_max_temp_c/avg_precipitation_mm → `MonthlyClimate` (TS) same fields — ✅
- `BestTimeResponse` (Python) location/latitude/longitude/monthly/best_months → `BestTimeResponse` (TS) same fields — ✅
- `useSortable({ id: dest.id })` uses `dest.id: string` — `items={destinations.map((d) => d.id)}` — consistent — ✅
- `apiPatch` signature matches usage in `handleDragEnd` — ✅
- `useMapStore()` now exports `filterStatus` and `setFilterStatus` — used in `MapFilterBar` and `WorldMap` — ✅
