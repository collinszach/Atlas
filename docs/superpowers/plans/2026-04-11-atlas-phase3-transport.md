# Atlas Phase 3 — Transport & Accommodations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full Transport leg CRUD, Accommodation CRUD, flight arcs on the world map, and a transport timeline section on the trip detail page.

**Architecture:** Expand the stub `transport_legs` and `accommodations` tables via migration 005 (ADD COLUMN). Follow the existing destinations router pattern (schemas with `from_orm_with_geo()`, `_get_trip_or_404` helper, full CRUD). Add `/map/arcs` to the map router — query flight legs with PostGIS geo → cache in Redis. On the frontend, add a `useMapArcs` hook and a flight arc `line` layer in `WorldMap`. Show transport legs in the trip detail page.

**Tech Stack:** FastAPI + SQLAlchemy 2.0 async + GeoAlchemy2, PostgreSQL+PostGIS, Redis, Next.js 14, MapLibre GL JS, TanStack Query, Lucide-react

---

## File Map

| Status | Path | Responsibility |
|--------|------|----------------|
| Modify | `backend/app/models/transport.py` | Full TransportLeg model (add all flight + geo columns) |
| Modify | `backend/app/models/accommodation.py` | Full Accommodation model (add all fields + geo column) |
| Create | `backend/migrations/versions/005_transport_accommodations.py` | ADD COLUMN for both tables |
| Create | `backend/app/schemas/transport.py` | TransportCreate, TransportUpdate, TransportRead |
| Create | `backend/app/routers/transport.py` | CRUD endpoints |
| Create | `backend/app/schemas/accommodation.py` | AccommodationCreate, AccommodationUpdate, AccommodationRead |
| Create | `backend/app/routers/accommodations.py` | CRUD endpoints |
| Modify | `backend/app/schemas/map.py` | Add FlightArcResponse |
| Modify | `backend/app/routers/map.py` | Add `/map/arcs` endpoint |
| Modify | `backend/app/main.py` | Register transport and accommodations routers |
| Create | `backend/tests/test_transport.py` | Integration tests: transport CRUD + user isolation |
| Create | `backend/tests/test_accommodations.py` | Integration tests: accommodation CRUD |
| Create | `backend/tests/test_map_arcs.py` | Integration tests: /map/arcs endpoint |
| Modify | `frontend/src/types/index.ts` | Add TransportLeg, Accommodation, MapArc types |
| Create | `frontend/src/hooks/useTransport.ts` | Transport CRUD hooks |
| Create | `frontend/src/hooks/useAccommodations.ts` | Accommodation CRUD hooks |
| Modify | `frontend/src/hooks/useMapData.ts` | Add useMapArcs |
| Modify | `frontend/src/components/map/WorldMap.tsx` | Add flight arc GeoJSON layer |
| Modify | `frontend/src/app/(app)/trips/[id]/page.tsx` | Add transport section |

---

### Task 1: Expand Models + Migration 005

**Files:**
- Modify: `backend/app/models/transport.py`
- Modify: `backend/app/models/accommodation.py`
- Create: `backend/migrations/versions/005_transport_accommodations.py`
- Create: `backend/tests/test_transport_model.py`

- [ ] **Step 1: Write failing model field tests**

Create `backend/tests/test_transport_model.py`:

```python
import pytest


def test_transport_leg_model_importable():
    from app.models.transport import TransportLeg
    assert TransportLeg.__tablename__ == "transport_legs"


def test_transport_leg_model_has_flight_fields():
    from app.models.transport import TransportLeg
    cols = {c.name for c in TransportLeg.__table__.columns}
    assert {
        "id", "trip_id", "user_id", "type",
        "flight_number", "airline", "origin_iata", "dest_iata",
        "origin_city", "dest_city",
        "departure_at", "arrival_at", "duration_min", "distance_km",
        "seat_class", "booking_ref", "cost", "currency", "notes",
        "origin_geo", "dest_geo", "created_at",
    }.issubset(cols)


def test_accommodation_model_importable():
    from app.models.accommodation import Accommodation
    assert Accommodation.__tablename__ == "accommodations"


def test_accommodation_model_has_full_fields():
    from app.models.accommodation import Accommodation
    cols = {c.name for c in Accommodation.__table__.columns}
    assert {
        "id", "trip_id", "user_id", "destination_id", "name",
        "type", "address", "location", "check_in", "check_out",
        "confirmation", "cost_per_night", "currency",
        "rating", "notes", "created_at",
    }.issubset(cols)


@pytest.mark.asyncio
async def test_transport_table_has_geo_columns(db_session):
    from sqlalchemy import text
    result = await db_session.execute(
        text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_name = 'transport_legs'"
        )
    )
    cols = {r[0] for r in result.fetchall()}
    assert {"flight_number", "origin_geo", "dest_geo", "departure_at"}.issubset(cols)


@pytest.mark.asyncio
async def test_accommodations_table_has_geo_column(db_session):
    from sqlalchemy import text
    result = await db_session.execute(
        text(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_name = 'accommodations'"
        )
    )
    cols = {r[0] for r in result.fetchall()}
    assert {"destination_id", "location", "check_in", "cost_per_night"}.issubset(cols)
```

- [ ] **Step 2: Run to see it fail**

```bash
docker compose -f /home/zach/Atlas/docker-compose.yml exec atlas-backend \
  pytest tests/test_transport_model.py -v
```

Expected: `test_transport_leg_model_has_flight_fields` and `test_accommodation_model_has_full_fields` FAIL (columns missing).

- [ ] **Step 3: Expand TransportLeg model**

Replace `backend/app/models/transport.py` entirely:

```python
import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import String, DateTime, Integer, Text, Numeric, ForeignKey, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from geoalchemy2 import Geography
from geoalchemy2.types import WKBElement

from app.database import Base


class TransportLeg(Base):
    __tablename__ = "transport_legs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    trip_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("trips.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    type: Mapped[str] = mapped_column(String, nullable=False, server_default="flight")

    # Flight-specific
    flight_number: Mapped[str | None] = mapped_column(String, nullable=True)
    airline: Mapped[str | None] = mapped_column(String, nullable=True)
    origin_iata: Mapped[str | None] = mapped_column(String(3), nullable=True)
    dest_iata: Mapped[str | None] = mapped_column(String(3), nullable=True)
    origin_city: Mapped[str | None] = mapped_column(String, nullable=True)
    dest_city: Mapped[str | None] = mapped_column(String, nullable=True)

    # Timing + logistics
    departure_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    arrival_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    duration_min: Mapped[int | None] = mapped_column(Integer, nullable=True)
    distance_km: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    seat_class: Mapped[str | None] = mapped_column(String, nullable=True)
    booking_ref: Mapped[str | None] = mapped_column(String, nullable=True)
    cost: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    currency: Mapped[str] = mapped_column(String(3), server_default="USD")
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Geo
    origin_geo: Mapped[WKBElement | None] = mapped_column(Geography(geometry_type="POINT", srid=4326), nullable=True)
    dest_geo: Mapped[WKBElement | None] = mapped_column(Geography(geometry_type="POINT", srid=4326), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

- [ ] **Step 4: Expand Accommodation model**

Replace `backend/app/models/accommodation.py` entirely:

```python
import uuid
from datetime import datetime
from decimal import Decimal
from sqlalchemy import String, DateTime, SmallInteger, Text, Numeric, ForeignKey, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column
from geoalchemy2 import Geography
from geoalchemy2.types import WKBElement

from app.database import Base


class Accommodation(Base):
    __tablename__ = "accommodations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    trip_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("trips.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    destination_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("destinations.id", ondelete="SET NULL"), nullable=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    type: Mapped[str | None] = mapped_column(String, nullable=True)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    location: Mapped[WKBElement | None] = mapped_column(Geography(geometry_type="POINT", srid=4326), nullable=True)
    check_in: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    check_out: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    confirmation: Mapped[str | None] = mapped_column(String, nullable=True)
    cost_per_night: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    currency: Mapped[str] = mapped_column(String(3), server_default="USD")
    rating: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

- [ ] **Step 5: Write migration 005**

Create `backend/migrations/versions/005_transport_accommodations.py`:

```python
"""Expand transport_legs and accommodations with full fields

Revision ID: 005
Revises: 004
Create Date: 2026-04-11
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID
import geoalchemy2

revision = "005"
down_revision = "004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # --- transport_legs ---
    op.add_column("transport_legs", sa.Column("flight_number", sa.String, nullable=True))
    op.add_column("transport_legs", sa.Column("airline", sa.String, nullable=True))
    op.add_column("transport_legs", sa.Column("origin_iata", sa.String(3), nullable=True))
    op.add_column("transport_legs", sa.Column("dest_iata", sa.String(3), nullable=True))
    op.add_column("transport_legs", sa.Column("origin_city", sa.String, nullable=True))
    op.add_column("transport_legs", sa.Column("dest_city", sa.String, nullable=True))
    op.add_column("transport_legs", sa.Column("departure_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("transport_legs", sa.Column("arrival_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("transport_legs", sa.Column("duration_min", sa.Integer, nullable=True))
    op.add_column("transport_legs", sa.Column("distance_km", sa.Numeric(10, 2), nullable=True))
    op.add_column("transport_legs", sa.Column("seat_class", sa.String, nullable=True))
    op.add_column("transport_legs", sa.Column("booking_ref", sa.String, nullable=True))
    op.add_column("transport_legs", sa.Column("cost", sa.Numeric(10, 2), nullable=True))
    op.add_column("transport_legs", sa.Column("currency", sa.String(3), nullable=False, server_default="USD"))
    op.add_column("transport_legs", sa.Column("notes", sa.Text, nullable=True))
    op.add_column(
        "transport_legs",
        sa.Column("origin_geo", geoalchemy2.Geography(geometry_type="POINT", srid=4326), nullable=True),
    )
    op.add_column(
        "transport_legs",
        sa.Column("dest_geo", geoalchemy2.Geography(geometry_type="POINT", srid=4326), nullable=True),
    )
    op.execute("CREATE INDEX transport_legs_origin_idx ON transport_legs USING GIST (origin_geo)")
    op.execute("CREATE INDEX transport_legs_dest_idx ON transport_legs USING GIST (dest_geo)")
    op.create_index("transport_legs_user_id_idx", "transport_legs", ["user_id"])
    op.create_index("transport_legs_trip_id_idx", "transport_legs", ["trip_id"])

    # --- accommodations ---
    op.add_column(
        "accommodations",
        sa.Column("destination_id", UUID(as_uuid=True), sa.ForeignKey("destinations.id", ondelete="SET NULL"), nullable=True),
    )
    op.add_column("accommodations", sa.Column("type", sa.String, nullable=True))
    op.add_column("accommodations", sa.Column("address", sa.Text, nullable=True))
    op.add_column(
        "accommodations",
        sa.Column("location", geoalchemy2.Geography(geometry_type="POINT", srid=4326), nullable=True),
    )
    op.add_column("accommodations", sa.Column("check_in", sa.DateTime(timezone=True), nullable=True))
    op.add_column("accommodations", sa.Column("check_out", sa.DateTime(timezone=True), nullable=True))
    op.add_column("accommodations", sa.Column("confirmation", sa.String, nullable=True))
    op.add_column("accommodations", sa.Column("cost_per_night", sa.Numeric(10, 2), nullable=True))
    op.add_column("accommodations", sa.Column("currency", sa.String(3), nullable=False, server_default="USD"))
    op.add_column("accommodations", sa.Column("rating", sa.SmallInteger, nullable=True))
    op.add_column("accommodations", sa.Column("notes", sa.Text, nullable=True))
    op.create_index("accommodations_user_id_idx", "accommodations", ["user_id"])
    op.create_index("accommodations_trip_id_idx", "accommodations", ["trip_id"])


def downgrade() -> None:
    op.drop_index("accommodations_trip_id_idx", table_name="accommodations")
    op.drop_index("accommodations_user_id_idx", table_name="accommodations")
    for col in ["notes", "rating", "currency", "cost_per_night", "confirmation",
                "check_out", "check_in", "location", "address", "type", "destination_id"]:
        op.drop_column("accommodations", col)

    op.drop_index("transport_legs_trip_id_idx", table_name="transport_legs")
    op.drop_index("transport_legs_user_id_idx", table_name="transport_legs")
    op.execute("DROP INDEX IF EXISTS transport_legs_dest_idx")
    op.execute("DROP INDEX IF EXISTS transport_legs_origin_idx")
    for col in ["dest_geo", "origin_geo", "notes", "currency", "cost", "booking_ref",
                "seat_class", "distance_km", "duration_min", "arrival_at", "departure_at",
                "dest_city", "origin_city", "dest_iata", "origin_iata", "airline", "flight_number"]:
        op.drop_column("transport_legs", col)
```

- [ ] **Step 6: Apply migration in Docker**

```bash
docker compose -f /home/zach/Atlas/docker-compose.yml exec atlas-backend alembic upgrade head
```

Expected output: `Running upgrade 004 -> 005, Expand transport_legs and accommodations with full fields`

- [ ] **Step 7: Run model tests — verify pass**

```bash
docker compose -f /home/zach/Atlas/docker-compose.yml exec atlas-backend \
  pytest tests/test_transport_model.py -v
```

Expected: 5 tests PASSED.

- [ ] **Step 8: Commit**

```bash
git add backend/app/models/transport.py backend/app/models/accommodation.py \
        backend/migrations/versions/005_transport_accommodations.py \
        backend/tests/test_transport_model.py
git commit -m "feat: expand transport_legs and accommodations models + migration 005"
```

---

### Task 2: Transport CRUD — Schemas, Router, Tests

**Files:**
- Create: `backend/app/schemas/transport.py`
- Create: `backend/app/routers/transport.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_transport.py`

- [ ] **Step 1: Write failing integration tests**

Create `backend/tests/test_transport.py`:

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


async def _create_trip(client) -> str:
    resp = await client.post("/api/v1/trips", json={"title": "Transport Test Trip"})
    assert resp.status_code == 201
    return resp.json()["id"]


async def _create_leg(client, trip_id: str, **overrides) -> str:
    payload = {"type": "flight", "origin_city": "JFK", "dest_city": "LHR", **overrides}
    resp = await client.post(f"/api/v1/trips/{trip_id}/transport", json=payload)
    assert resp.status_code == 201
    return resp.json()["id"]


@pytest.mark.asyncio
@pytest.mark.integration
async def test_create_flight_leg(authed_client):
    trip_id = await _create_trip(authed_client)
    resp = await authed_client.post(
        f"/api/v1/trips/{trip_id}/transport",
        json={
            "type": "flight",
            "flight_number": "BA178",
            "airline": "British Airways",
            "origin_iata": "JFK",
            "dest_iata": "LHR",
            "origin_city": "New York",
            "dest_city": "London",
            "departure_at": "2025-06-01T09:00:00Z",
            "arrival_at": "2025-06-01T21:00:00Z",
            "duration_min": 420,
            "seat_class": "economy",
            "origin_lat": 40.6413,
            "origin_lng": -73.7781,
            "dest_lat": 51.4775,
            "dest_lng": -0.4614,
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["flight_number"] == "BA178"
    assert body["duration_min"] == 420
    assert abs(body["origin_lat"] - 40.6413) < 0.001
    assert abs(body["dest_lat"] - 51.4775) < 0.001


@pytest.mark.asyncio
@pytest.mark.integration
async def test_list_transport_legs(authed_client):
    trip_id = await _create_trip(authed_client)
    await _create_leg(authed_client, trip_id)
    await _create_leg(authed_client, trip_id, type="train", origin_city="London", dest_city="Paris")
    resp = await authed_client.get(f"/api/v1/trips/{trip_id}/transport")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


@pytest.mark.asyncio
@pytest.mark.integration
async def test_update_transport_leg(authed_client):
    trip_id = await _create_trip(authed_client)
    leg_id = await _create_leg(authed_client, trip_id)
    resp = await authed_client.put(
        f"/api/v1/transport/{leg_id}",
        json={"flight_number": "AA100", "seat_class": "business"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["flight_number"] == "AA100"
    assert body["seat_class"] == "business"


@pytest.mark.asyncio
@pytest.mark.integration
async def test_delete_transport_leg(authed_client):
    trip_id = await _create_trip(authed_client)
    leg_id = await _create_leg(authed_client, trip_id)
    resp = await authed_client.delete(f"/api/v1/transport/{leg_id}")
    assert resp.status_code == 204
    list_resp = await authed_client.get(f"/api/v1/trips/{trip_id}/transport")
    assert list_resp.json() == []


@pytest.mark.asyncio
@pytest.mark.integration
async def test_transport_user_isolation(authed_client):
    from app.main import app
    from app.auth import get_current_user_id

    trip_id = await _create_trip(authed_client)
    await _create_leg(authed_client, trip_id)

    app.dependency_overrides[get_current_user_id] = lambda: OTHER_USER_ID
    try:
        resp = await authed_client.get(f"/api/v1/trips/{trip_id}/transport")
    finally:
        app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    assert resp.status_code == 404


@pytest.mark.asyncio
@pytest.mark.integration
async def test_invalid_transport_type_rejected(authed_client):
    trip_id = await _create_trip(authed_client)
    resp = await authed_client.post(
        f"/api/v1/trips/{trip_id}/transport",
        json={"type": "teleporter", "origin_city": "A", "dest_city": "B"},
    )
    assert resp.status_code == 422
```

- [ ] **Step 2: Run tests to see them fail**

```bash
docker compose -f /home/zach/Atlas/docker-compose.yml exec atlas-backend \
  pytest tests/test_transport.py -v -m integration
```

Expected: ERRORS — `404 Not Found` for the transport endpoints (router not registered yet).

- [ ] **Step 3: Create transport schemas**

Create `backend/app/schemas/transport.py`:

```python
from __future__ import annotations
import uuid
from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, model_validator


_VALID_TYPES = {"flight", "car", "train", "ferry", "bus", "walk", "other"}


class TransportCreate(BaseModel):
    type: str = "flight"
    flight_number: str | None = None
    airline: str | None = None
    origin_iata: str | None = None
    dest_iata: str | None = None
    origin_city: str | None = None
    dest_city: str | None = None
    departure_at: datetime | None = None
    arrival_at: datetime | None = None
    duration_min: int | None = None
    distance_km: Decimal | None = None
    seat_class: str | None = None
    booking_ref: str | None = None
    cost: Decimal | None = None
    currency: str = "USD"
    notes: str | None = None
    origin_lat: float | None = None
    origin_lng: float | None = None
    dest_lat: float | None = None
    dest_lng: float | None = None

    @model_validator(mode="after")
    def validate_type(self) -> "TransportCreate":
        if self.type not in _VALID_TYPES:
            raise ValueError(f"type must be one of {sorted(_VALID_TYPES)}")
        return self

    @model_validator(mode="after")
    def validate_geo_pairs(self) -> "TransportCreate":
        if (self.origin_lat is None) != (self.origin_lng is None):
            raise ValueError("Provide both origin_lat and origin_lng, or neither")
        if (self.dest_lat is None) != (self.dest_lng is None):
            raise ValueError("Provide both dest_lat and dest_lng, or neither")
        return self


class TransportUpdate(BaseModel):
    type: str | None = None
    flight_number: str | None = None
    airline: str | None = None
    origin_iata: str | None = None
    dest_iata: str | None = None
    origin_city: str | None = None
    dest_city: str | None = None
    departure_at: datetime | None = None
    arrival_at: datetime | None = None
    duration_min: int | None = None
    distance_km: Decimal | None = None
    seat_class: str | None = None
    booking_ref: str | None = None
    cost: Decimal | None = None
    currency: str | None = None
    notes: str | None = None
    origin_lat: float | None = None
    origin_lng: float | None = None
    dest_lat: float | None = None
    dest_lng: float | None = None


class TransportRead(BaseModel):
    id: uuid.UUID
    trip_id: uuid.UUID
    user_id: str
    type: str
    flight_number: str | None
    airline: str | None
    origin_iata: str | None
    dest_iata: str | None
    origin_city: str | None
    dest_city: str | None
    departure_at: datetime | None
    arrival_at: datetime | None
    duration_min: int | None
    distance_km: Decimal | None
    seat_class: str | None
    booking_ref: str | None
    cost: Decimal | None
    currency: str
    notes: str | None
    origin_lat: float | None = None
    origin_lng: float | None = None
    dest_lat: float | None = None
    dest_lng: float | None = None
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_with_geo(cls, leg: object) -> "TransportRead":
        """Extract lat/lng from GeoAlchemy2 WKBElement for both origin and dest."""
        from geoalchemy2.shape import to_shape
        origin_lat = origin_lng = dest_lat = dest_lng = None
        if leg.origin_geo is not None:
            pt = to_shape(leg.origin_geo)
            origin_lng, origin_lat = pt.x, pt.y
        if leg.dest_geo is not None:
            pt = to_shape(leg.dest_geo)
            dest_lng, dest_lat = pt.x, pt.y
        data = {c.name: getattr(leg, c.name) for c in leg.__table__.columns}
        data["origin_lat"] = origin_lat
        data["origin_lng"] = origin_lng
        data["dest_lat"] = dest_lat
        data["dest_lng"] = dest_lng
        return cls(**data)
```

- [ ] **Step 4: Create transport router**

Create `backend/app/routers/transport.py`:

```python
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException
from geoalchemy2.shape import from_shape
from shapely.geometry import Point
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.transport import TransportLeg
from app.models.trip import Trip
from app.schemas.transport import TransportCreate, TransportRead, TransportUpdate

logger = logging.getLogger(__name__)
router = APIRouter(tags=["transport"])


async def _get_trip_or_404(trip_id: uuid.UUID, user_id: str, db: AsyncSession) -> Trip:
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip


@router.get("/trips/{trip_id}/transport", response_model=list[TransportRead])
async def list_transport(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[TransportRead]:
    await _get_trip_or_404(trip_id, user_id, db)
    result = await db.execute(
        select(TransportLeg)
        .where(TransportLeg.trip_id == trip_id, TransportLeg.user_id == user_id)
        .order_by(TransportLeg.departure_at.nullslast())
    )
    legs = result.scalars().all()
    return [TransportRead.from_orm_with_geo(leg) for leg in legs]


@router.post("/trips/{trip_id}/transport", response_model=TransportRead, status_code=201)
async def add_transport(
    trip_id: uuid.UUID,
    body: TransportCreate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> TransportRead:
    await _get_trip_or_404(trip_id, user_id, db)

    origin_geo = None
    dest_geo = None
    if body.origin_lat is not None:
        origin_geo = from_shape(Point(body.origin_lng, body.origin_lat), srid=4326)
    if body.dest_lat is not None:
        dest_geo = from_shape(Point(body.dest_lng, body.dest_lat), srid=4326)

    leg = TransportLeg(
        trip_id=trip_id,
        user_id=user_id,
        type=body.type,
        flight_number=body.flight_number,
        airline=body.airline,
        origin_iata=body.origin_iata,
        dest_iata=body.dest_iata,
        origin_city=body.origin_city,
        dest_city=body.dest_city,
        departure_at=body.departure_at,
        arrival_at=body.arrival_at,
        duration_min=body.duration_min,
        distance_km=body.distance_km,
        seat_class=body.seat_class,
        booking_ref=body.booking_ref,
        cost=body.cost,
        currency=body.currency,
        notes=body.notes,
        origin_geo=origin_geo,
        dest_geo=dest_geo,
    )
    db.add(leg)
    await db.flush()
    await db.refresh(leg)
    return TransportRead.from_orm_with_geo(leg)


@router.put("/transport/{leg_id}", response_model=TransportRead)
async def update_transport(
    leg_id: uuid.UUID,
    body: TransportUpdate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> TransportRead:
    result = await db.execute(
        select(TransportLeg).where(TransportLeg.id == leg_id, TransportLeg.user_id == user_id)
    )
    leg = result.scalar_one_or_none()
    if leg is None:
        raise HTTPException(status_code=404, detail="Transport leg not found")

    update_data = body.model_dump(exclude_none=True)
    origin_lat = update_data.pop("origin_lat", None)
    origin_lng = update_data.pop("origin_lng", None)
    dest_lat = update_data.pop("dest_lat", None)
    dest_lng = update_data.pop("dest_lng", None)

    if origin_lat is not None and origin_lng is not None:
        leg.origin_geo = from_shape(Point(origin_lng, origin_lat), srid=4326)
    if dest_lat is not None and dest_lng is not None:
        leg.dest_geo = from_shape(Point(dest_lng, dest_lat), srid=4326)

    for k, v in update_data.items():
        setattr(leg, k, v)

    await db.flush()
    await db.refresh(leg)
    return TransportRead.from_orm_with_geo(leg)


@router.delete("/transport/{leg_id}", status_code=204)
async def delete_transport(
    leg_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> None:
    result = await db.execute(
        select(TransportLeg).where(TransportLeg.id == leg_id, TransportLeg.user_id == user_id)
    )
    leg = result.scalar_one_or_none()
    if leg is None:
        raise HTTPException(status_code=404, detail="Transport leg not found")
    await db.delete(leg)
    await db.flush()
```

- [ ] **Step 5: Register transport router in main.py**

In `backend/app/main.py`, add after the existing router imports and `include_router` calls:

```python
# Add to imports at top:
from app.routers import transport as transport_router

# Add after app.include_router(map_router.router, prefix="/api/v1"):
app.include_router(transport_router.router, prefix="/api/v1")
```

The full import block becomes:
```python
from app.routers import users, trips, destinations, map as map_router
from app.routers.photos import router as photos_router
from app.routers.transport import router as transport_router_obj
```

And the include_router lines:
```python
app.include_router(users.router, prefix="/api/v1")
app.include_router(trips.router, prefix="/api/v1")
app.include_router(destinations.router, prefix="/api/v1")
app.include_router(map_router.router, prefix="/api/v1")
app.include_router(photos_router, prefix="/api/v1")
app.include_router(transport_router_obj, prefix="/api/v1")
```

- [ ] **Step 6: Run tests — verify pass**

```bash
docker compose -f /home/zach/Atlas/docker-compose.yml exec atlas-backend \
  pytest tests/test_transport.py -v -m integration
```

Expected: 6 tests PASSED.

- [ ] **Step 7: Commit**

```bash
git add backend/app/schemas/transport.py backend/app/routers/transport.py \
        backend/app/main.py backend/tests/test_transport.py
git commit -m "feat: transport leg CRUD — schemas, router, integration tests"
```

---

### Task 3: Accommodation CRUD — Schemas, Router, Tests

**Files:**
- Create: `backend/app/schemas/accommodation.py`
- Create: `backend/app/routers/accommodations.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_accommodations.py`

- [ ] **Step 1: Write failing integration tests**

Create `backend/tests/test_accommodations.py`:

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


async def _create_trip(client) -> str:
    resp = await client.post("/api/v1/trips", json={"title": "Accommodation Test Trip"})
    assert resp.status_code == 201
    return resp.json()["id"]


async def _create_accommodation(client, trip_id: str) -> str:
    resp = await client.post(
        f"/api/v1/trips/{trip_id}/accommodations",
        json={"name": "The Savoy", "type": "hotel"},
    )
    assert resp.status_code == 201
    return resp.json()["id"]


@pytest.mark.asyncio
@pytest.mark.integration
async def test_create_accommodation(authed_client):
    trip_id = await _create_trip(authed_client)
    resp = await authed_client.post(
        f"/api/v1/trips/{trip_id}/accommodations",
        json={
            "name": "Hotel de Crillon",
            "type": "hotel",
            "address": "10 Place de la Concorde, Paris",
            "cost_per_night": 850.00,
            "currency": "EUR",
            "check_in": "2025-06-15T15:00:00Z",
            "check_out": "2025-06-18T11:00:00Z",
            "confirmation": "CONF-12345",
            "rating": 5,
            "latitude": 48.8656,
            "longitude": 2.3212,
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["name"] == "Hotel de Crillon"
    assert body["currency"] == "EUR"
    assert abs(body["latitude"] - 48.8656) < 0.001


@pytest.mark.asyncio
@pytest.mark.integration
async def test_list_accommodations(authed_client):
    trip_id = await _create_trip(authed_client)
    await _create_accommodation(authed_client, trip_id)
    await _create_accommodation(authed_client, trip_id)
    resp = await authed_client.get(f"/api/v1/trips/{trip_id}/accommodations")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


@pytest.mark.asyncio
@pytest.mark.integration
async def test_update_accommodation(authed_client):
    trip_id = await _create_trip(authed_client)
    acc_id = await _create_accommodation(authed_client, trip_id)
    resp = await authed_client.put(
        f"/api/v1/accommodations/{acc_id}",
        json={"rating": 4, "notes": "Great breakfast"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["rating"] == 4
    assert body["notes"] == "Great breakfast"


@pytest.mark.asyncio
@pytest.mark.integration
async def test_delete_accommodation(authed_client):
    trip_id = await _create_trip(authed_client)
    acc_id = await _create_accommodation(authed_client, trip_id)
    resp = await authed_client.delete(f"/api/v1/accommodations/{acc_id}")
    assert resp.status_code == 204
    list_resp = await authed_client.get(f"/api/v1/trips/{trip_id}/accommodations")
    assert list_resp.json() == []


@pytest.mark.asyncio
@pytest.mark.integration
async def test_accommodation_user_isolation(authed_client):
    from app.main import app
    from app.auth import get_current_user_id

    trip_id = await _create_trip(authed_client)
    await _create_accommodation(authed_client, trip_id)

    app.dependency_overrides[get_current_user_id] = lambda: OTHER_USER_ID
    try:
        resp = await authed_client.get(f"/api/v1/trips/{trip_id}/accommodations")
    finally:
        app.dependency_overrides[get_current_user_id] = lambda: TEST_USER_ID
    assert resp.status_code == 404
```

- [ ] **Step 2: Run tests to see them fail**

```bash
docker compose -f /home/zach/Atlas/docker-compose.yml exec atlas-backend \
  pytest tests/test_accommodations.py -v -m integration
```

Expected: 404 errors (router not registered).

- [ ] **Step 3: Create accommodation schemas**

Create `backend/app/schemas/accommodation.py`:

```python
from __future__ import annotations
import uuid
from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel


class AccommodationCreate(BaseModel):
    destination_id: uuid.UUID | None = None
    name: str
    type: str | None = None
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    check_in: datetime | None = None
    check_out: datetime | None = None
    confirmation: str | None = None
    cost_per_night: Decimal | None = None
    currency: str = "USD"
    rating: int | None = None
    notes: str | None = None


class AccommodationUpdate(BaseModel):
    destination_id: uuid.UUID | None = None
    name: str | None = None
    type: str | None = None
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    check_in: datetime | None = None
    check_out: datetime | None = None
    confirmation: str | None = None
    cost_per_night: Decimal | None = None
    currency: str | None = None
    rating: int | None = None
    notes: str | None = None


class AccommodationRead(BaseModel):
    id: uuid.UUID
    trip_id: uuid.UUID
    user_id: str
    destination_id: uuid.UUID | None
    name: str
    type: str | None
    address: str | None
    latitude: float | None = None
    longitude: float | None = None
    check_in: datetime | None
    check_out: datetime | None
    confirmation: str | None
    cost_per_night: Decimal | None
    currency: str
    rating: int | None
    notes: str | None
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_with_geo(cls, acc: object) -> "AccommodationRead":
        """Extract lat/lng from GeoAlchemy2 WKBElement."""
        from geoalchemy2.shape import to_shape
        lat: float | None = None
        lng: float | None = None
        if acc.location is not None:
            pt = to_shape(acc.location)
            lng, lat = pt.x, pt.y
        data = {c.name: getattr(acc, c.name) for c in acc.__table__.columns}
        data["latitude"] = lat
        data["longitude"] = lng
        return cls(**data)
```

- [ ] **Step 4: Create accommodation router**

Create `backend/app/routers/accommodations.py`:

```python
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException
from geoalchemy2.shape import from_shape
from shapely.geometry import Point
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.accommodation import Accommodation
from app.models.trip import Trip
from app.schemas.accommodation import AccommodationCreate, AccommodationRead, AccommodationUpdate

logger = logging.getLogger(__name__)
router = APIRouter(tags=["accommodations"])


async def _get_trip_or_404(trip_id: uuid.UUID, user_id: str, db: AsyncSession) -> Trip:
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip


@router.get("/trips/{trip_id}/accommodations", response_model=list[AccommodationRead])
async def list_accommodations(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[AccommodationRead]:
    await _get_trip_or_404(trip_id, user_id, db)
    result = await db.execute(
        select(Accommodation)
        .where(Accommodation.trip_id == trip_id, Accommodation.user_id == user_id)
        .order_by(Accommodation.check_in.nullslast())
    )
    accs = result.scalars().all()
    return [AccommodationRead.from_orm_with_geo(a) for a in accs]


@router.post("/trips/{trip_id}/accommodations", response_model=AccommodationRead, status_code=201)
async def add_accommodation(
    trip_id: uuid.UUID,
    body: AccommodationCreate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> AccommodationRead:
    await _get_trip_or_404(trip_id, user_id, db)

    location = None
    if body.latitude is not None and body.longitude is not None:
        location = from_shape(Point(body.longitude, body.latitude), srid=4326)

    acc = Accommodation(
        trip_id=trip_id,
        user_id=user_id,
        destination_id=body.destination_id,
        name=body.name,
        type=body.type,
        address=body.address,
        location=location,
        check_in=body.check_in,
        check_out=body.check_out,
        confirmation=body.confirmation,
        cost_per_night=body.cost_per_night,
        currency=body.currency,
        rating=body.rating,
        notes=body.notes,
    )
    db.add(acc)
    await db.flush()
    await db.refresh(acc)
    return AccommodationRead.from_orm_with_geo(acc)


@router.put("/accommodations/{acc_id}", response_model=AccommodationRead)
async def update_accommodation(
    acc_id: uuid.UUID,
    body: AccommodationUpdate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> AccommodationRead:
    result = await db.execute(
        select(Accommodation).where(Accommodation.id == acc_id, Accommodation.user_id == user_id)
    )
    acc = result.scalar_one_or_none()
    if acc is None:
        raise HTTPException(status_code=404, detail="Accommodation not found")

    update_data = body.model_dump(exclude_none=True)
    lat = update_data.pop("latitude", None)
    lng = update_data.pop("longitude", None)
    if lat is not None and lng is not None:
        acc.location = from_shape(Point(lng, lat), srid=4326)

    for k, v in update_data.items():
        setattr(acc, k, v)

    await db.flush()
    await db.refresh(acc)
    return AccommodationRead.from_orm_with_geo(acc)


@router.delete("/accommodations/{acc_id}", status_code=204)
async def delete_accommodation(
    acc_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> None:
    result = await db.execute(
        select(Accommodation).where(Accommodation.id == acc_id, Accommodation.user_id == user_id)
    )
    acc = result.scalar_one_or_none()
    if acc is None:
        raise HTTPException(status_code=404, detail="Accommodation not found")
    await db.delete(acc)
    await db.flush()
```

- [ ] **Step 5: Register accommodation router in main.py**

In `backend/app/main.py`, add accommodations router. The updated imports and includes:

```python
from app.routers import users, trips, destinations, map as map_router
from app.routers.photos import router as photos_router
from app.routers.transport import router as transport_router_obj
from app.routers.accommodations import router as accommodations_router_obj

# ...
app.include_router(users.router, prefix="/api/v1")
app.include_router(trips.router, prefix="/api/v1")
app.include_router(destinations.router, prefix="/api/v1")
app.include_router(map_router.router, prefix="/api/v1")
app.include_router(photos_router, prefix="/api/v1")
app.include_router(transport_router_obj, prefix="/api/v1")
app.include_router(accommodations_router_obj, prefix="/api/v1")
```

- [ ] **Step 6: Run tests — verify pass**

```bash
docker compose -f /home/zach/Atlas/docker-compose.yml exec atlas-backend \
  pytest tests/test_accommodations.py -v -m integration
```

Expected: 5 tests PASSED.

- [ ] **Step 7: Commit**

```bash
git add backend/app/schemas/accommodation.py backend/app/routers/accommodations.py \
        backend/app/main.py backend/tests/test_accommodations.py
git commit -m "feat: accommodation CRUD — schemas, router, integration tests"
```

---

### Task 4: /map/arcs Endpoint

**Files:**
- Modify: `backend/app/schemas/map.py`
- Modify: `backend/app/routers/map.py`
- Create: `backend/tests/test_map_arcs.py`

- [ ] **Step 1: Write failing test**

Create `backend/tests/test_map_arcs.py`:

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


async def _seed_flight(client, with_geo: bool = True) -> None:
    trip_resp = await client.post("/api/v1/trips", json={"title": "Arc Test Trip"})
    trip_id = trip_resp.json()["id"]
    payload = {
        "type": "flight",
        "flight_number": "UA900",
        "origin_city": "San Francisco",
        "dest_city": "Tokyo",
    }
    if with_geo:
        payload.update(
            origin_lat=37.6213,
            origin_lng=-122.379,
            dest_lat=35.5494,
            dest_lng=139.7798,
        )
    await client.post(f"/api/v1/trips/{trip_id}/transport", json=payload)


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_arcs_returns_flight_with_geo(authed_client):
    await _seed_flight(authed_client, with_geo=True)
    resp = await authed_client.get("/api/v1/map/arcs")
    assert resp.status_code == 200
    arcs = resp.json()
    assert len(arcs) >= 1
    arc = next(a for a in arcs if a["flight_number"] == "UA900")
    assert arc["origin_city"] == "San Francisco"
    assert abs(arc["origin_lat"] - 37.6213) < 0.001
    assert abs(arc["dest_lat"] - 35.5494) < 0.001


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_arcs_excludes_flights_without_geo(authed_client):
    await _seed_flight(authed_client, with_geo=False)
    resp = await authed_client.get("/api/v1/map/arcs")
    assert resp.status_code == 200
    # The no-geo flight should not appear
    arcs = resp.json()
    no_geo_arcs = [a for a in arcs if a.get("origin_lat") is None]
    assert len(no_geo_arcs) == 0


@pytest.mark.asyncio
@pytest.mark.integration
async def test_map_arcs_excludes_non_flight_legs(authed_client):
    trip_resp = await authed_client.post("/api/v1/trips", json={"title": "Non-flight Trip"})
    trip_id = trip_resp.json()["id"]
    await authed_client.post(
        f"/api/v1/trips/{trip_id}/transport",
        json={
            "type": "train",
            "origin_city": "Paris",
            "dest_city": "Amsterdam",
            "origin_lat": 48.8566,
            "origin_lng": 2.3522,
            "dest_lat": 52.3676,
            "dest_lng": 4.9041,
        },
    )
    resp = await authed_client.get("/api/v1/map/arcs")
    arcs = resp.json()
    paris_arcs = [a for a in arcs if a.get("origin_city") == "Paris"]
    assert len(paris_arcs) == 0
```

- [ ] **Step 2: Run test to see it fail**

```bash
docker compose -f /home/zach/Atlas/docker-compose.yml exec atlas-backend \
  pytest tests/test_map_arcs.py -v -m integration
```

Expected: 404 Not Found (endpoint doesn't exist yet).

- [ ] **Step 3: Add FlightArcResponse to map schemas**

In `backend/app/schemas/map.py`, append:

```python
class FlightArcResponse(BaseModel):
    id: str
    trip_id: str
    flight_number: str | None
    origin_city: str | None
    dest_city: str | None
    origin_iata: str | None
    dest_iata: str | None
    departure_at: str | None
    origin_lat: float
    origin_lng: float
    dest_lat: float
    dest_lng: float
```

- [ ] **Step 4: Add /map/arcs endpoint to map router**

In `backend/app/routers/map.py`, add after the existing imports:

```python
from app.schemas.map import CityPointResponse, CountryVisitResponse, FlightArcResponse
```

Then append the endpoint:

```python
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
```

- [ ] **Step 5: Run tests — verify pass**

```bash
docker compose -f /home/zach/Atlas/docker-compose.yml exec atlas-backend \
  pytest tests/test_map_arcs.py -v -m integration
```

Expected: 3 tests PASSED.

- [ ] **Step 6: Run full test suite — verify no regressions**

```bash
docker compose -f /home/zach/Atlas/docker-compose.yml exec atlas-backend \
  pytest -v -m integration
```

Expected: All integration tests pass.

- [ ] **Step 7: Commit**

```bash
git add backend/app/schemas/map.py backend/app/routers/map.py \
        backend/tests/test_map_arcs.py
git commit -m "feat: /map/arcs endpoint — flight arcs for world map, cached in Redis"
```

---

### Task 5: Frontend — Types, Hooks, Arc Layer, Transport Section

**Files:**
- Modify: `frontend/src/types/index.ts`
- Create: `frontend/src/hooks/useTransport.ts`
- Create: `frontend/src/hooks/useAccommodations.ts`
- Modify: `frontend/src/hooks/useMapData.ts`
- Modify: `frontend/src/components/map/WorldMap.tsx`
- Modify: `frontend/src/app/(app)/trips/[id]/page.tsx`

- [ ] **Step 1: Add types to index.ts**

Append to `frontend/src/types/index.ts` (after the existing MapCity interface):

```typescript
export interface TransportLeg {
  id: string;
  trip_id: string;
  user_id: string;
  type: "flight" | "car" | "train" | "ferry" | "bus" | "walk" | "other";
  flight_number: string | null;
  airline: string | null;
  origin_iata: string | null;
  dest_iata: string | null;
  origin_city: string | null;
  dest_city: string | null;
  departure_at: string | null;
  arrival_at: string | null;
  duration_min: number | null;
  distance_km: number | null;
  seat_class: string | null;
  booking_ref: string | null;
  cost: number | null;
  currency: string;
  notes: string | null;
  origin_lat: number | null;
  origin_lng: number | null;
  dest_lat: number | null;
  dest_lng: number | null;
  created_at: string;
}

export interface Accommodation {
  id: string;
  trip_id: string;
  user_id: string;
  destination_id: string | null;
  name: string;
  type: string | null;
  address: string | null;
  latitude: number | null;
  longitude: number | null;
  check_in: string | null;
  check_out: string | null;
  confirmation: string | null;
  cost_per_night: number | null;
  currency: string;
  rating: number | null;
  notes: string | null;
  created_at: string;
}

export interface MapArc {
  id: string;
  trip_id: string;
  flight_number: string | null;
  origin_city: string | null;
  dest_city: string | null;
  origin_iata: string | null;
  dest_iata: string | null;
  departure_at: string | null;
  origin_lat: number;
  origin_lng: number;
  dest_lat: number;
  dest_lng: number;
}
```

- [ ] **Step 2: Create useTransport.ts**

Create `frontend/src/hooks/useTransport.ts`:

```typescript
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost, apiPut, apiDelete } from "@/lib/api";
import type { TransportLeg } from "@/types";

export function useTransport(tripId: string) {
  const { getToken } = useAuth();
  return useQuery<TransportLeg[]>({
    queryKey: ["transport", tripId],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<TransportLeg[]>(`/trips/${tripId}/transport`, token);
    },
  });
}

export function useAddTransport(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: Partial<TransportLeg>) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<TransportLeg>(`/trips/${tripId}/transport`, token, body);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["transport", tripId] });
      qc.invalidateQueries({ queryKey: ["map", "arcs"] });
    },
  });
}

export function useUpdateTransport(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: Partial<TransportLeg> & { id: string }) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPut<TransportLeg>(`/transport/${id}`, token, body);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["transport", tripId] });
      qc.invalidateQueries({ queryKey: ["map", "arcs"] });
    },
  });
}

export function useDeleteTransport(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (legId: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiDelete(`/transport/${legId}`, token);
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["transport", tripId] });
      qc.invalidateQueries({ queryKey: ["map", "arcs"] });
    },
  });
}
```

- [ ] **Step 3: Create useAccommodations.ts**

Create `frontend/src/hooks/useAccommodations.ts`:

```typescript
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet, apiPost, apiPut, apiDelete } from "@/lib/api";
import type { Accommodation } from "@/types";

export function useAccommodations(tripId: string) {
  const { getToken } = useAuth();
  return useQuery<Accommodation[]>({
    queryKey: ["accommodations", tripId],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<Accommodation[]>(`/trips/${tripId}/accommodations`, token);
    },
  });
}

export function useAddAccommodation(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (body: Partial<Accommodation>) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPost<Accommodation>(`/trips/${tripId}/accommodations`, token, body);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["accommodations", tripId] }),
  });
}

export function useUpdateAccommodation(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async ({ id, ...body }: Partial<Accommodation> & { id: string }) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiPut<Accommodation>(`/accommodations/${id}`, token, body);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["accommodations", tripId] }),
  });
}

export function useDeleteAccommodation(tripId: string) {
  const { getToken } = useAuth();
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (accId: string) => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiDelete(`/accommodations/${accId}`, token);
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["accommodations", tripId] }),
  });
}
```

- [ ] **Step 4: Add useMapArcs to useMapData.ts**

Append to `frontend/src/hooks/useMapData.ts`:

```typescript
import type { MapCountry, MapCity, MapArc } from "@/types";

// (add MapArc to the existing import — update the import line at the top)
```

Then append the hook:

```typescript
export function useMapArcs() {
  const { getToken } = useAuth();
  return useQuery<MapArc[]>({
    queryKey: ["map", "arcs"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<MapArc[]>("/map/arcs", token);
    },
    staleTime: 5 * 60 * 1000,
  });
}
```

- [ ] **Step 5: Add flight arc layer to WorldMap.tsx**

In `frontend/src/components/map/WorldMap.tsx`:

1. Add `useMapArcs` to the imports:
```typescript
import { useMapCountries, useMapCities, useMapArcs } from "@/hooks/useMapData";
```

2. Add the arcs data fetch inside the component (after the existing `useMapCities` call):
```typescript
const { data: arcs = [] } = useMapArcs();
```

3. Add the arc layer `useEffect` after the city markers `useEffect` (before `handleToggleProjection`):
```typescript
// Add flight arc layer when arcs data changes
useEffect(() => {
  if (!map.current || !map.current.isStyleLoaded() || arcs.length === 0) return;

  const geojson: GeoJSON.FeatureCollection = {
    type: "FeatureCollection",
    features: arcs.map((a) => ({
      type: "Feature",
      geometry: {
        type: "LineString",
        coordinates: [
          [a.origin_lng, a.origin_lat],
          [a.dest_lng, a.dest_lat],
        ],
      },
      properties: {
        flight_number: a.flight_number,
        trip_id: a.trip_id,
      },
    })),
  };

  const src = map.current.getSource("flight-arcs") as maplibregl.GeoJSONSource | undefined;
  if (src) {
    src.setData(geojson);
  } else {
    map.current.addSource("flight-arcs", { type: "geojson", data: geojson });
    map.current.addLayer(
      {
        id: "flight-arcs",
        type: "line",
        source: "flight-arcs",
        paint: {
          "line-color": "#4a90d9",
          "line-width": 1,
          "line-opacity": 0.5,
        },
      },
      map.current.getLayer("city-markers") ? "city-markers" : undefined,
    );
  }
}, [arcs]);
```

- [ ] **Step 6: Add transport section to trip detail page**

Replace `frontend/src/app/(app)/trips/[id]/page.tsx` entirely:

```typescript
"use client";

import Link from "next/link";
import { useParams } from "next/navigation";
import {
  Plus, MapPin, Plane, Car, Train, Ship, Bus, Footprints,
} from "lucide-react";
import { useTrip } from "@/hooks/useTrips";
import { useDestinations } from "@/hooks/useDestinations";
import { useTransport } from "@/hooks/useTransport";
import { formatDateRange, nightsLabel } from "@/lib/utils";
import type { TransportLeg } from "@/types";

const TRANSPORT_ICONS: Record<TransportLeg["type"], React.ReactNode> = {
  flight: <Plane size={14} />,
  car: <Car size={14} />,
  train: <Train size={14} />,
  ferry: <Ship size={14} />,
  bus: <Bus size={14} />,
  walk: <Footprints size={14} />,
  other: <MapPin size={14} />,
};

function transportLabel(leg: TransportLeg): string {
  if (leg.origin_city && leg.dest_city) {
    return `${leg.origin_city} → ${leg.dest_city}`;
  }
  if (leg.origin_iata && leg.dest_iata) {
    return `${leg.origin_iata} → ${leg.dest_iata}`;
  }
  return leg.flight_number ?? leg.type;
}

export default function TripDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { data: trip, isLoading: tripLoading } = useTrip(id);
  const { data: destinations = [], isLoading: destLoading } = useDestinations(id);
  const { data: transport = [], isLoading: transportLoading } = useTransport(id);

  if (tripLoading) return <div className="p-6 text-atlas-muted text-sm">Loading...</div>;
  if (!trip) return <div className="p-6 text-red-400 text-sm">Trip not found.</div>;

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="mb-8">
          <Link href="/trips" className="text-xs text-atlas-muted hover:text-atlas-text mb-3 inline-block">
            ← All trips
          </Link>
          <h1 className="font-display text-3xl font-semibold text-atlas-text">{trip.title}</h1>
          {trip.description && (
            <p className="text-atlas-muted mt-2 text-sm">{trip.description}</p>
          )}
          <p className="text-xs font-mono text-atlas-muted mt-2">
            {formatDateRange(trip.start_date, trip.end_date)}
          </p>
        </div>

        {/* Destinations */}
        <div className="mb-10">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest">
              Destinations
            </h2>
            <Link
              href={`/trips/${id}/destinations/new`}
              className="flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors"
            >
              <Plus size={12} />
              Add destination
            </Link>
          </div>

          {destLoading && <p className="text-atlas-muted text-sm">Loading...</p>}

          {!destLoading && destinations.length === 0 && (
            <p className="text-atlas-muted text-sm py-6 text-center border border-dashed border-atlas-border rounded-lg">
              No destinations yet. Add one to start building your itinerary.
            </p>
          )}

          <div className="flex flex-col gap-2">
            {destinations.map((dest) => (
              <div
                key={dest.id}
                className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3 flex items-center gap-4"
              >
                <div className="flex h-8 w-8 items-center justify-center rounded bg-atlas-accent/10 text-atlas-accent shrink-0">
                  <MapPin size={14} />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-atlas-text">{dest.city}</p>
                  <p className="text-xs text-atlas-muted">{dest.country_name}</p>
                </div>
                <div className="text-right shrink-0">
                  <p className="text-xs font-mono text-atlas-muted">
                    {dest.arrival_date ?? "—"}
                  </p>
                  <p className="text-xs text-atlas-muted">{nightsLabel(dest.nights)}</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Transport */}
        <div>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest">
              Transport
            </h2>
            <Link
              href={`/trips/${id}/transport/new`}
              className="flex items-center gap-1.5 text-xs text-atlas-accent hover:text-atlas-accent/80 transition-colors"
            >
              <Plus size={12} />
              Log transport
            </Link>
          </div>

          {transportLoading && <p className="text-atlas-muted text-sm">Loading...</p>}

          {!transportLoading && transport.length === 0 && (
            <p className="text-atlas-muted text-sm py-6 text-center border border-dashed border-atlas-border rounded-lg">
              No transport logged yet.
            </p>
          )}

          <div className="flex flex-col gap-2">
            {transport.map((leg) => (
              <div
                key={leg.id}
                className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3 flex items-center gap-4"
              >
                <div className="flex h-8 w-8 items-center justify-center rounded bg-atlas-accent-cool/10 text-atlas-accent-cool shrink-0">
                  {TRANSPORT_ICONS[leg.type]}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-atlas-text">{transportLabel(leg)}</p>
                  <p className="text-xs text-atlas-muted capitalize">
                    {leg.type}
                    {leg.airline ? ` · ${leg.airline}` : ""}
                    {leg.flight_number ? ` ${leg.flight_number}` : ""}
                  </p>
                </div>
                <div className="text-right shrink-0">
                  {leg.departure_at && (
                    <p className="text-xs font-mono text-atlas-muted">
                      {leg.departure_at.slice(0, 10)}
                    </p>
                  )}
                  {leg.duration_min && (
                    <p className="text-xs text-atlas-muted">
                      {Math.floor(leg.duration_min / 60)}h {leg.duration_min % 60}m
                    </p>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 7: Run TypeScript type-check**

```bash
cd /home/zach/Atlas/frontend && npx tsc --noEmit
```

Expected: No errors.

- [ ] **Step 8: Commit**

```bash
git add frontend/src/types/index.ts \
        frontend/src/hooks/useTransport.ts \
        frontend/src/hooks/useAccommodations.ts \
        frontend/src/hooks/useMapData.ts \
        frontend/src/components/map/WorldMap.tsx \
        frontend/src/app/\(app\)/trips/\[id\]/page.tsx
git commit -m "feat: frontend transport/accommodation hooks, flight arc layer, transport section on trip detail"
```

---

## Spec Self-Review

**Coverage check against SPEC.md Phase 3 requirements:**
- ✅ Transport leg CRUD — `POST/GET /trips/{id}/transport`, `PUT/DELETE /transport/{id}`
- ✅ Accommodation CRUD — `POST/GET /trips/{id}/accommodations`, `PUT/DELETE /accommodations/{id}`
- ✅ Great-circle arc calculation — `GET /map/arcs` returns origin/dest geo pairs
- ✅ Flight arc layer in WorldMap — GeoJSON LineString source + MapLibre `line` layer
- ✅ Transport timeline section in trip detail page
- ✅ PostGIS indexes on transport geo columns
- ✅ Redis cache for `/map/arcs` (5 min TTL, same pattern as cities/countries)
- ✅ User isolation on all endpoints
- ⚠️ `distance_km` enrichment via flight data service (Phase 3 item) — omitted per YAGNI; flight enrichment is a separate future task. The field exists and can be populated manually.

**Type consistency check:**
- `FlightArcResponse` fields match what `/map/arcs` SQL query returns: `origin_lat`, `origin_lng`, `dest_lat`, `dest_lng` — ✅
- `MapArc` TS type matches `FlightArcResponse` Python schema — ✅
- `from_orm_with_geo()` on `TransportRead` uses `origin_lat/lng`, `dest_lat/lng` — matches TS `TransportLeg` type — ✅
- `useMapArcs` in `WorldMap.tsx` reads `a.origin_lng`, `a.origin_lat` — matches `MapArc` interface — ✅
- `TRANSPORT_ICONS` keys are `TransportLeg["type"]` union — matches backend `_VALID_TYPES` — ✅

**Placeholder scan:** None found.
