# Atlas Phase 1 — Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Atlas backend — Docker Compose stack, PostGIS schema, Clerk JWT auth, Trip/Destination CRUD, and map data endpoints that power the globe choropleth.

**Architecture:** FastAPI with async SQLAlchemy on PostgreSQL+PostGIS. All data is user-scoped via Clerk JWT. Redis caches map layer data (5-min TTL). Country seed script populates base polygon data for the choropleth. `country_visits` materialized view is refreshed as a FastAPI background task after destination writes.

**Tech Stack:** Python 3.12, FastAPI, SQLAlchemy 2.0 async, Alembic, PostgreSQL 16 + PostGIS, Redis 7, Clerk JWT (`jwks-client`), pytest + pytest-asyncio + httpx, Docker Compose

**Frontend plan:** `docs/superpowers/plans/2026-04-11-atlas-phase1-frontend.md` — execute after this plan passes all quality gates.

---

## File Map

```
Atlas/
├── docker-compose.yml                  CREATE — all 5 services
├── .env.example                        CREATE — all required vars
├── .claudeignore                       CREATE — .env*, .superpowers/, etc.
│
└── backend/
    ├── Dockerfile                      CREATE
    ├── requirements.txt                CREATE
    ├── alembic.ini                     CREATE
    ├── app/
    │   ├── main.py                     CREATE — FastAPI app, routers, CORS
    │   ├── config.py                   CREATE — pydantic-settings Settings
    │   ├── database.py                 CREATE — async engine, session dep, sync engine
    │   ├── auth.py                     CREATE — Clerk JWT dep + webhook HMAC verify
    │   ├── models/
    │   │   ├── __init__.py             CREATE
    │   │   ├── user.py                 CREATE — User model
    │   │   ├── trip.py                 CREATE — Trip model
    │   │   ├── destination.py          CREATE — Destination model (PostGIS)
    │   │   ├── transport.py            CREATE — TransportLeg stub
    │   │   └── accommodation.py        CREATE — Accommodation stub
    │   ├── schemas/
    │   │   ├── __init__.py             CREATE
    │   │   ├── user.py                 CREATE — UserSync Pydantic schema
    │   │   ├── trip.py                 CREATE — TripCreate/Read/Update
    │   │   └── destination.py          CREATE — DestinationCreate/Read/Update
    │   ├── routers/
    │   │   ├── __init__.py             CREATE
    │   │   ├── users.py                CREATE — POST /users/sync (webhook)
    │   │   ├── trips.py                CREATE — CRUD /trips
    │   │   ├── destinations.py         CREATE — CRUD /trips/{id}/destinations
    │   │   └── map.py                  CREATE — GET /map/countries, /map/cities
    │   └── services/
    │       ├── __init__.py             CREATE
    │       └── map_cache.py            CREATE — Redis helpers for map layer caching
    ├── migrations/
    │   ├── env.py                      CREATE
    │   ├── script.py.mako              CREATE (standard Alembic template)
    │   └── versions/
    │       ├── 001_core_tables.py      CREATE
    │       ├── 002_views_stubs.py      CREATE
    │       └── 003_country_polygons.py CREATE
    ├── scripts/
    │   └── seed_countries.py           CREATE — Natural Earth 110m → countries table
    └── tests/
        ├── conftest.py                 CREATE — test app, async client, fixtures
        ├── test_auth.py                CREATE — JWT and webhook tests
        ├── test_trips.py               CREATE — Trip CRUD tests
        ├── test_destinations.py        CREATE — Destination CRUD tests
        └── test_map.py                 CREATE — Map endpoint tests
```

---

## Task 1: Project skeleton, Docker Compose, and .env.example

**Files:**
- Create: `Atlas/docker-compose.yml`
- Create: `Atlas/.env.example`
- Create: `Atlas/.claudeignore`
- Create: `Atlas/backend/requirements.txt`
- Create: `Atlas/backend/Dockerfile`
- Create: `Atlas/backend/alembic.ini`

- [ ] **Step 1: Create .claudeignore (first)**

Create `Atlas/.claudeignore`:
```
.env
.env.*
!.env.example
.superpowers/
__pycache__/
*.pyc
.pytest_cache/
node_modules/
.next/
*.pem
*.key
minio-data/
postgres-data/
```

- [ ] **Step 2: Create .env.example**

Create `Atlas/.env.example`:
```bash
# Database
POSTGRES_DB=atlas
POSTGRES_USER=atlas
POSTGRES_PASSWORD=changeme
DATABASE_URL=postgresql+asyncpg://atlas:changeme@atlas-db:5432/atlas
DATABASE_URL_SYNC=postgresql+psycopg2://atlas:changeme@atlas-db:5432/atlas

# Redis
REDIS_URL=redis://atlas-redis:6379/0

# Clerk
CLERK_SECRET_KEY=sk_live_...
CLERK_WEBHOOK_SECRET=whsec_...
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_...

# MinIO (photos — Phase 2+; provisioned now)
MINIO_ENDPOINT=atlas-minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET_PHOTOS=atlas-photos
MINIO_PUBLIC_URL=http://localhost:9000
STORAGE_BACKEND=minio

# Protomaps (free dev key — replace with self-hosted PMTiles in Phase 6)
NEXT_PUBLIC_PROTOMAPS_KEY=...

# AI (Phase 5)
ANTHROPIC_API_KEY=sk-ant-...

# Optional: flight enrichment (Phase 3)
AVIATIONSTACK_API_KEY=

# App
APP_ENV=development
```

- [ ] **Step 3: Create docker-compose.yml**

Create `Atlas/docker-compose.yml`:
```yaml
services:
  atlas-db:
    image: postgis/postgis:16-3.4
    container_name: atlas-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - atlas-network

  atlas-redis:
    image: redis:7-alpine
    container_name: atlas-redis
    restart: unless-stopped
    command: redis-server --save 60 1
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 5
    networks:
      - atlas-network

  atlas-minio:
    image: minio/minio:latest
    container_name: atlas-minio
    restart: unless-stopped
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: ${MINIO_ACCESS_KEY}
      MINIO_ROOT_PASSWORD: ${MINIO_SECRET_KEY}
    volumes:
      - minio_data:/data
    ports:
      - "9000:9000"
      - "9001:9001"
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - atlas-network

  atlas-backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: atlas-backend
    restart: unless-stopped
    env_file: .env
    ports:
      - "8000:8000"
    depends_on:
      atlas-db:
        condition: service_healthy
      atlas-redis:
        condition: service_healthy
    volumes:
      - ./backend:/app
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
    networks:
      - atlas-network

  atlas-frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: atlas-frontend
    restart: unless-stopped
    env_file: .env
    ports:
      - "3000:3000"
    depends_on:
      - atlas-backend
    volumes:
      - ./frontend:/app
      - /app/node_modules
      - /app/.next
    networks:
      - atlas-network

networks:
  atlas-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  minio_data:
```

- [ ] **Step 4: Create backend/requirements.txt**

Create `Atlas/backend/requirements.txt`:
```
fastapi==0.115.5
uvicorn[standard]==0.32.1
sqlalchemy[asyncio]==2.0.36
alembic==1.14.0
asyncpg==0.30.0
psycopg2-binary==2.9.10
geoalchemy2==0.17.0
pydantic==2.10.3
pydantic-settings==2.7.0
redis[hiredis]==5.2.1
httpx==0.28.1
svix==1.45.0
python-multipart==0.0.20
pytest==8.3.4
pytest-asyncio==0.24.0
pytest-cov==6.0.0
shapely==2.0.6
fiona==1.10.1
```

- [ ] **Step 5: Create backend/Dockerfile**

Create `Atlas/backend/Dockerfile`:
```dockerfile
FROM python:3.12-slim

RUN apt-get update && apt-get install -y \
    gdal-bin \
    libgdal-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

ENV GDAL_CONFIG=/usr/bin/gdal-config

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

- [ ] **Step 6: Create backend/alembic.ini**

Create `Atlas/backend/alembic.ini`:
```ini
[alembic]
script_location = migrations
file_template = %%(rev)s_%%(slug)s
prepend_sys_path = .
version_path_separator = os
sqlalchemy.url = driver://user:pass@localhost/dbname

[loggers]
keys = root,sqlalchemy,alembic

[handlers]
keys = console

[formatters]
keys = generic

[logger_root]
level = WARN
handlers = console
qualname =

[logger_sqlalchemy]
level = WARN
handlers =
qualname = sqlalchemy.engine

[logger_alembic]
level = INFO
handlers =
qualname = alembic

[handler_console]
class = StreamHandler
args = (sys.stderr,)
level = NOTSET
formatter = generic

[formatter_generic]
format = %(levelname)-5.5s [%(name)s] %(message)s
datefmt = %H:%M:%S
```

- [ ] **Step 7: Commit**

```bash
cd /home/zach/Atlas
git add docker-compose.yml .env.example .claudeignore backend/requirements.txt backend/Dockerfile backend/alembic.ini
git commit -m "feat(atlas): add Docker Compose stack, backend Dockerfile, and project skeleton"
```

---

## Task 2: Config, database, and app entry point

**Files:**
- Create: `backend/app/config.py`
- Create: `backend/app/database.py`
- Create: `backend/app/main.py`
- Create: `backend/app/__init__.py`

- [ ] **Step 1: Write failing test for config loading**

Create `backend/tests/conftest.py` (base only — will expand in later tasks):
```python
import pytest
import os

# Override env before any app imports
os.environ.setdefault("POSTGRES_DB", "atlas_test")
os.environ.setdefault("POSTGRES_USER", "atlas")
os.environ.setdefault("POSTGRES_PASSWORD", "testpass")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://atlas:testpass@localhost:5432/atlas_test")
os.environ.setdefault("DATABASE_URL_SYNC", "postgresql+psycopg2://atlas:testpass@localhost:5432/atlas_test")
os.environ.setdefault("REDIS_URL", "redis://localhost:6379/1")
os.environ.setdefault("CLERK_SECRET_KEY", "sk_test_fake")
os.environ.setdefault("CLERK_WEBHOOK_SECRET", "whsec_fake1234567890abcdef1234567890ab")
os.environ.setdefault("MINIO_ACCESS_KEY", "minioadmin")
os.environ.setdefault("MINIO_SECRET_KEY", "minioadmin")
```

Create `backend/tests/__init__.py` (empty).

Create `backend/tests/test_config.py`:
```python
def test_settings_load():
    from app.config import settings
    assert settings.database_url.startswith("postgresql")
    assert settings.redis_url.startswith("redis://")
    assert settings.clerk_secret_key != ""
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /home/zach/Atlas/backend
python -m pytest tests/test_config.py -v
```
Expected: `ModuleNotFoundError: No module named 'app'`

- [ ] **Step 3: Create app/config.py**

Create `backend/app/__init__.py` (empty).

Create `backend/app/config.py`:
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

    # App
    app_env: str = "development"


settings = Settings()
```

- [ ] **Step 4: Run test to verify it passes**

```bash
cd /home/zach/Atlas/backend
python -m pytest tests/test_config.py -v
```
Expected: `PASSED`

- [ ] **Step 5: Create app/database.py**

```python
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker
from sqlalchemy import create_engine

from app.config import settings


class Base(DeclarativeBase):
    pass


engine = create_async_engine(settings.database_url, echo=False)
async_session_factory = async_sessionmaker(engine, expire_on_commit=False)

# Sync engine for migrations and scripts
sync_engine = create_engine(settings.database_url_sync, echo=False)
SyncSession = sessionmaker(sync_engine)


async def get_db() -> AsyncSession:
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

- [ ] **Step 6: Create app/main.py**

```python
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import users, trips, destinations, map as map_router

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Atlas backend starting")
    yield
    logger.info("Atlas backend shutting down")


app = FastAPI(
    title="Atlas API",
    version="0.1.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users.router, prefix="/api/v1")
app.include_router(trips.router, prefix="/api/v1")
app.include_router(destinations.router, prefix="/api/v1")
app.include_router(map_router.router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok"}
```

Create `backend/app/routers/__init__.py` (empty).
Create `backend/app/models/__init__.py` (empty).
Create `backend/app/schemas/__init__.py` (empty).
Create `backend/app/services/__init__.py` (empty).

- [ ] **Step 7: Write and run health endpoint test**

Add to `backend/tests/conftest.py`:
```python
import pytest
from httpx import AsyncClient, ASGITransport

@pytest.fixture
async def client():
    from app.main import app
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        yield ac
```

Create `backend/tests/test_main.py`:
```python
import pytest

@pytest.mark.asyncio
async def test_health(client):
    response = await client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

Run:
```bash
cd /home/zach/Atlas/backend
python -m pytest tests/test_main.py -v
```
Expected: `PASSED`

- [ ] **Step 8: Commit**

```bash
cd /home/zach/Atlas
git add backend/app/ backend/tests/
git commit -m "feat(atlas): add config, database engine, FastAPI app entry point, health endpoint"
```

---

## Task 3: SQLAlchemy models

**Files:**
- Create: `backend/app/models/user.py`
- Create: `backend/app/models/trip.py`
- Create: `backend/app/models/destination.py`
- Create: `backend/app/models/transport.py`
- Create: `backend/app/models/accommodation.py`

- [ ] **Step 1: Write failing test**

Create `backend/tests/test_models.py`:
```python
def test_user_model_has_required_columns():
    from app.models.user import User
    cols = {c.name for c in User.__table__.columns}
    assert {"id", "email", "display_name", "created_at"}.issubset(cols)

def test_trip_model_has_required_columns():
    from app.models.trip import Trip
    cols = {c.name for c in Trip.__table__.columns}
    assert {"id", "user_id", "title", "status", "visibility"}.issubset(cols)

def test_destination_model_has_location_column():
    from app.models.destination import Destination
    col_names = {c.name for c in Destination.__table__.columns}
    assert "location" in col_names
```

Run to verify failure:
```bash
python -m pytest tests/test_models.py -v
```
Expected: `ModuleNotFoundError`

- [ ] **Step 2: Create app/models/user.py**

```python
from datetime import datetime
from sqlalchemy import String, DateTime, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True)
    email: Mapped[str] = mapped_column(String, unique=True, nullable=False)
    display_name: Mapped[str | None] = mapped_column(String, nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String, nullable=True)
    home_country: Mapped[str | None] = mapped_column(String(2), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    preferences: Mapped[dict] = mapped_column(JSONB, server_default="{}")
```

- [ ] **Step 3: Create app/models/trip.py**

```python
import uuid
from datetime import datetime, date
from sqlalchemy import String, DateTime, Date, ForeignKey, func, text
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Trip(Base):
    __tablename__ = "trips"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    title: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str | None] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String, nullable=False, server_default="past")
    start_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    end_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    cover_photo_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    tags: Mapped[list[str]] = mapped_column(ARRAY(String), server_default="{}")
    visibility: Mapped[str] = mapped_column(String, nullable=False, server_default="private")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    destinations: Mapped[list["Destination"]] = relationship("Destination", back_populates="trip", lazy="selectin")
```

- [ ] **Step 4: Create app/models/destination.py**

```python
import uuid
from datetime import datetime, date
from sqlalchemy import String, DateTime, Date, Integer, SmallInteger, Text, ForeignKey, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from geoalchemy2 import Geography

from app.database import Base


class Destination(Base):
    __tablename__ = "destinations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    trip_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("trips.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    city: Mapped[str] = mapped_column(String, nullable=False)
    country_code: Mapped[str] = mapped_column(String(2), nullable=False)
    country_name: Mapped[str] = mapped_column(String, nullable=False)
    region: Mapped[str | None] = mapped_column(String, nullable=True)
    location: Mapped[object | None] = mapped_column(Geography(geometry_type="POINT", srid=4326), nullable=True)
    arrival_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    departure_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    nights: Mapped[int | None] = mapped_column(Integer, nullable=True)  # computed in Python; DB GENERATED col added via migration
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    rating: Mapped[int | None] = mapped_column(SmallInteger, nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, server_default="0")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    trip: Mapped["Trip"] = relationship("Trip", back_populates="destinations")
```

- [ ] **Step 5: Create stub models (transport, accommodation)**

Create `backend/app/models/transport.py`:
```python
import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class TransportLeg(Base):
    __tablename__ = "transport_legs"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    trip_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("trips.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    type: Mapped[str] = mapped_column(String, nullable=False, server_default="flight")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

Create `backend/app/models/accommodation.py`:
```python
import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, ForeignKey, func, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Accommodation(Base):
    __tablename__ = "accommodations"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, server_default=text("gen_random_uuid()"))
    trip_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("trips.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd /home/zach/Atlas/backend
python -m pytest tests/test_models.py -v
```
Expected: all 3 tests `PASSED`

- [ ] **Step 7: Commit**

```bash
cd /home/zach/Atlas
git add backend/app/models/
git commit -m "feat(atlas): add SQLAlchemy models — User, Trip, Destination, transport/accommodation stubs"
```

---

## Task 4: Alembic migrations

**Files:**
- Create: `backend/migrations/env.py`
- Create: `backend/migrations/script.py.mako`
- Create: `backend/migrations/versions/001_core_tables.py`
- Create: `backend/migrations/versions/002_views_stubs.py`
- Create: `backend/migrations/versions/003_country_polygons.py`

- [ ] **Step 1: Create migrations/env.py**

```python
import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

from app.config import settings
from app.database import Base
# Import all models so their metadata is registered
from app.models import user, trip, destination, transport, accommodation  # noqa

config = context.config
config.set_main_option("sqlalchemy.url", settings.database_url.replace("+asyncpg", ""))

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

- [ ] **Step 2: Create migrations/script.py.mako**

```mako
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
Create Date: ${create_date}

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
import geoalchemy2
${imports if imports else ""}

revision: str = ${repr(up_revision)}
down_revision: Union[str, None] = ${repr(down_revision)}
branch_labels: Union[str, Sequence[str], None] = ${repr(branch_labels)}
depends_on: Union[str, Sequence[str], None] = ${repr(depends_on)}


def upgrade() -> None:
    ${upgrades if upgrades else "pass"}


def downgrade() -> None:
    ${downgrades if downgrades else "pass"}
```

Create `backend/migrations/__init__.py` (empty).
Create `backend/migrations/versions/__init__.py` (empty).

- [ ] **Step 3: Create migration 001 — core tables**

Create `backend/migrations/versions/001_core_tables.py`:
```python
"""core tables: users, trips, destinations

Revision ID: 001
Revises:
Create Date: 2026-04-11
"""
from typing import Union, Sequence
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID, JSONB, ARRAY
import geoalchemy2

revision = "001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
    op.execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

    op.create_table(
        "users",
        sa.Column("id", sa.String, primary_key=True),
        sa.Column("email", sa.String, unique=True, nullable=False),
        sa.Column("display_name", sa.String, nullable=True),
        sa.Column("avatar_url", sa.String, nullable=True),
        sa.Column("home_country", sa.String(2), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("preferences", JSONB, server_default="{}"),
    )

    op.create_table(
        "trips",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String, nullable=False),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("status", sa.String, nullable=False, server_default="past"),
        sa.Column("start_date", sa.Date, nullable=True),
        sa.Column("end_date", sa.Date, nullable=True),
        sa.Column("cover_photo_id", UUID(as_uuid=True), nullable=True),
        sa.Column("tags", ARRAY(sa.String), server_default="{}"),
        sa.Column("visibility", sa.String, nullable=False, server_default="private"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("trips_user_id_idx", "trips", ["user_id"])

    op.create_table(
        "destinations",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("trip_id", UUID(as_uuid=True), sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("city", sa.String, nullable=False),
        sa.Column("country_code", sa.String(2), nullable=False),
        sa.Column("country_name", sa.String, nullable=False),
        sa.Column("region", sa.String, nullable=True),
        sa.Column("location", geoalchemy2.Geography(geometry_type="POINT", srid=4326), nullable=True),
        sa.Column("arrival_date", sa.Date, nullable=True),
        sa.Column("departure_date", sa.Date, nullable=True),
        sa.Column("nights", sa.Integer, nullable=True),
        sa.Column("notes", sa.Text, nullable=True),
        sa.Column("rating", sa.SmallInteger, nullable=True),
        sa.Column("order_index", sa.Integer, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )
    op.create_index("destinations_user_id_idx", "destinations", ["user_id"])
    op.create_index("destinations_trip_id_idx", "destinations", ["trip_id"])
    op.execute("CREATE INDEX destinations_location_idx ON destinations USING GIST (location)")


def downgrade() -> None:
    op.drop_table("destinations")
    op.drop_table("trips")
    op.drop_table("users")
```

- [ ] **Step 4: Create migration 002 — materialized view and stubs**

Create `backend/migrations/versions/002_views_stubs.py`:
```python
"""country_visits materialized view and stub tables

Revision ID: 002
Revises: 001
Create Date: 2026-04-11
"""
from typing import Union, Sequence
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = "002"
down_revision = "001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("""
        CREATE MATERIALIZED VIEW country_visits AS
        SELECT
          d.user_id,
          d.country_code,
          MAX(d.country_name)               AS country_name,
          COUNT(DISTINCT d.trip_id)         AS visit_count,
          MIN(d.arrival_date)               AS first_visit,
          MAX(d.departure_date)             AS last_visit,
          COALESCE(SUM(d.nights), 0)        AS total_nights,
          ARRAY_AGG(DISTINCT d.trip_id)     AS trip_ids
        FROM destinations d
        GROUP BY d.user_id, d.country_code
    """)
    op.execute("CREATE UNIQUE INDEX country_visits_uid_cc ON country_visits(user_id, country_code)")

    op.create_table(
        "transport_legs",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("trip_id", UUID(as_uuid=True), sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("type", sa.String, nullable=False, server_default="flight"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )

    op.create_table(
        "accommodations",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("trip_id", UUID(as_uuid=True), sa.ForeignKey("trips.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.String, sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()")),
    )


def downgrade() -> None:
    op.drop_table("accommodations")
    op.drop_table("transport_legs")
    op.execute("DROP MATERIALIZED VIEW IF EXISTS country_visits")
```

- [ ] **Step 5: Create migration 003 — country polygons**

Create `backend/migrations/versions/003_country_polygons.py`:
```python
"""countries table for Natural Earth polygon data

Revision ID: 003
Revises: 002
Create Date: 2026-04-11
"""
from typing import Union, Sequence
from alembic import op
import sqlalchemy as sa
import geoalchemy2

revision = "003"
down_revision = "002"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "countries",
        sa.Column("code", sa.String(2), primary_key=True),
        sa.Column("name", sa.String, nullable=False),
        sa.Column("name_long", sa.String, nullable=True),
        sa.Column("continent", sa.String, nullable=True),
        sa.Column("geometry", geoalchemy2.Geometry(geometry_type="MULTIPOLYGON", srid=4326), nullable=True),
    )
    op.execute("CREATE INDEX countries_geometry_idx ON countries USING GIST (geometry)")


def downgrade() -> None:
    op.drop_table("countries")
```

- [ ] **Step 6: Apply migrations (requires running containers)**

```bash
cd /home/zach/Atlas
cp .env.example .env   # fill in real values before running
docker compose up atlas-db -d
docker compose exec atlas-backend alembic upgrade head
```

Expected output: three migration steps completing without errors.

- [ ] **Step 7: Commit**

```bash
cd /home/zach/Atlas
git add backend/migrations/
git commit -m "feat(atlas): add Alembic migrations 001-003 — core tables, country_visits view, country polygons"
```

---

## Task 5: Clerk auth — JWT middleware and webhook handler

**Files:**
- Create: `backend/app/auth.py`
- Create: `backend/app/schemas/user.py`
- Create: `backend/app/routers/users.py`
- Create: `backend/tests/test_auth.py`

- [ ] **Step 1: Write failing auth tests**

Create `backend/tests/test_auth.py`:
```python
import pytest
from unittest.mock import patch, MagicMock


@pytest.mark.asyncio
async def test_missing_auth_header_returns_401(client):
    response = await client.get("/api/v1/trips")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_invalid_token_returns_401(client):
    response = await client.get("/api/v1/trips", headers={"Authorization": "Bearer notavalidtoken"})
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_webhook_missing_svix_headers_returns_400(client):
    response = await client.post("/api/v1/users/sync", json={"type": "user.created", "data": {}})
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_health_requires_no_auth(client):
    response = await client.get("/health")
    assert response.status_code == 200
```

Run to verify failures:
```bash
python -m pytest tests/test_auth.py -v
```
Expected: 3 failures (routers not created yet), 1 pass (health).

- [ ] **Step 2: Create app/auth.py**

```python
import logging
from typing import Annotated

import httpx
from fastapi import Depends, HTTPException, Request, status
from jose import JWTError, jwt

from app.config import settings

logger = logging.getLogger(__name__)

_jwks_cache: dict | None = None


async def _get_jwks() -> dict:
    global _jwks_cache
    if _jwks_cache is None:
        async with httpx.AsyncClient() as client:
            # Clerk JWKS endpoint derived from the secret key prefix
            # For production: https://<clerk-frontend-api>/.well-known/jwks.json
            # We use the Clerk backend verification approach via jose
            resp = await client.get("https://api.clerk.com/v1/jwks", headers={"Authorization": f"Bearer {settings.clerk_secret_key}"})
            resp.raise_for_status()
            _jwks_cache = resp.json()
    return _jwks_cache


async def get_current_user_id(request: Request) -> str:
    """Extract and verify Clerk JWT. Returns Clerk user_id string."""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing authorization header")

    token = auth_header.removeprefix("Bearer ").strip()
    try:
        jwks = await _get_jwks()
        # Find the matching key by kid in the token header
        unverified_header = jwt.get_unverified_header(token)
        kid = unverified_header.get("kid")
        key = next((k for k in jwks.get("keys", []) if k["kid"] == kid), None)
        if key is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Unknown signing key")
        payload = jwt.decode(token, key, algorithms=["RS256"])
        user_id: str = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload")
        return user_id
    except JWTError as exc:
        logger.warning("JWT validation failed: %s", exc)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")


CurrentUser = Annotated[str, Depends(get_current_user_id)]


def verify_webhook_signature(request: Request, payload: bytes) -> None:
    """Verify Clerk webhook via svix signature headers."""
    import svix
    wh = svix.Webhook(settings.clerk_webhook_secret)
    try:
        wh.verify(
            payload,
            {
                "svix-id": request.headers.get("svix-id", ""),
                "svix-timestamp": request.headers.get("svix-timestamp", ""),
                "svix-signature": request.headers.get("svix-signature", ""),
            },
        )
    except Exception as exc:
        logger.warning("Webhook verification failed: %s", exc)
        raise HTTPException(status_code=400, detail="Invalid webhook signature")
```

- [ ] **Step 3: Create app/schemas/user.py**

```python
from pydantic import BaseModel


class ClerkWebhookUser(BaseModel):
    id: str
    email_addresses: list[dict]
    first_name: str | None = None
    last_name: str | None = None
    image_url: str | None = None


class UserRead(BaseModel):
    id: str
    email: str
    display_name: str | None
    avatar_url: str | None

    model_config = {"from_attributes": True}
```

- [ ] **Step 4: Create app/routers/users.py**

```python
import logging
from fastapi import APIRouter, Request, Depends
from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert

from app.auth import verify_webhook_signature, CurrentUser
from app.database import get_db
from app.models.user import User
from app.schemas.user import UserRead

logger = logging.getLogger(__name__)
router = APIRouter(tags=["users"])


@router.post("/users/sync", status_code=204)
async def sync_user(request: Request, db=Depends(get_db)):
    """Clerk webhook — upsert user on create/update events."""
    raw_body = await request.body()
    verify_webhook_signature(request, raw_body)

    event = await request.json()
    event_type = event.get("type")
    if event_type not in ("user.created", "user.updated"):
        return  # Ignore other event types

    data = event.get("data", {})
    user_id = data.get("id")
    emails = data.get("email_addresses", [])
    primary_email = next(
        (e["email_address"] for e in emails if e.get("id") == data.get("primary_email_address_id")),
        emails[0]["email_address"] if emails else None,
    )
    if not user_id or not primary_email:
        logger.warning("Webhook missing user_id or email: %s", data)
        return

    display_name = " ".join(filter(None, [data.get("first_name"), data.get("last_name")])) or None

    stmt = (
        insert(User)
        .values(id=user_id, email=primary_email, display_name=display_name, avatar_url=data.get("image_url"))
        .on_conflict_do_update(
            index_elements=["id"],
            set_={"email": primary_email, "display_name": display_name, "avatar_url": data.get("image_url")},
        )
    )
    await db.execute(stmt)
    logger.info("Upserted user %s", user_id)


@router.get("/users/me", response_model=UserRead)
async def get_me(user_id: CurrentUser, db=Depends(get_db)):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="User not found — complete sign-up first")
    return user
```

- [ ] **Step 5: Run auth tests**

```bash
cd /home/zach/Atlas/backend
python -m pytest tests/test_auth.py -v
```
Expected: all 4 tests `PASSED` (missing/invalid token → 401, missing svix headers → 400, health → 200).

Note: JWT tests pass because the mock token `notavalidtoken` cannot be decoded by jose, raising JWTError → 401.

- [ ] **Step 6: Commit**

```bash
cd /home/zach/Atlas
git add backend/app/auth.py backend/app/schemas/user.py backend/app/routers/users.py backend/tests/test_auth.py
git commit -m "feat(atlas): add Clerk JWT middleware, webhook user-sync handler"
```

---

## Task 6: Trip CRUD

**Files:**
- Create: `backend/app/schemas/trip.py`
- Create: `backend/app/routers/trips.py`
- Create: `backend/tests/test_trips.py`

- [ ] **Step 1: Write failing trip tests**

First, expand `backend/tests/conftest.py` to add an authenticated client fixture:
```python
# Add to existing conftest.py

TEST_USER_ID = "user_test_atlas_001"
TEST_USER_EMAIL = "test@atlas.dev"

@pytest.fixture
async def authed_client(client):
    """Client with a mocked valid JWT that resolves to TEST_USER_ID."""
    from unittest.mock import patch, AsyncMock

    async def mock_get_current_user_id(request):
        return TEST_USER_ID

    with patch("app.auth.get_current_user_id", new=mock_get_current_user_id):
        # Also patch the Depends resolution
        from app import auth
        original = auth.get_current_user_id
        auth.get_current_user_id = mock_get_current_user_id
        yield client
        auth.get_current_user_id = original

@pytest.fixture(autouse=True)
async def seed_test_user(authed_client):
    """Ensure the test user row exists in the DB before each test."""
    # We can't rely on webhooks in tests — insert directly
    pass  # Overridden once DB fixtures are live
```

Create `backend/tests/test_trips.py`:
```python
import pytest


@pytest.mark.asyncio
async def test_create_trip(authed_client):
    response = await authed_client.post(
        "/api/v1/trips",
        json={"title": "Japan Spring 2025", "status": "past", "visibility": "private"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["title"] == "Japan Spring 2025"
    assert "id" in body


@pytest.mark.asyncio
async def test_list_trips_empty(authed_client):
    response = await authed_client.get("/api/v1/trips")
    assert response.status_code == 200
    assert response.json()["items"] == []


@pytest.mark.asyncio
async def test_get_trip_not_found(authed_client):
    response = await authed_client.get("/api/v1/trips/00000000-0000-0000-0000-000000000000")
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_cannot_read_another_users_trip(authed_client):
    """User isolation: trip created by user A is not visible to user B."""
    # Create trip as test user
    create_resp = await authed_client.post(
        "/api/v1/trips",
        json={"title": "Private Trip"},
    )
    trip_id = create_resp.json()["id"]

    # Override user_id to simulate a different user
    from unittest.mock import patch
    async def different_user(request):
        return "user_different_002"

    with patch("app.auth.get_current_user_id", new=different_user):
        response = await authed_client.get(f"/api/v1/trips/{trip_id}")
    assert response.status_code == 404
```

Run to verify failures:
```bash
python -m pytest tests/test_trips.py -v
```
Expected: failures because router not created yet.

- [ ] **Step 2: Create app/schemas/trip.py**

```python
import uuid
from datetime import datetime, date
from typing import Optional
from pydantic import BaseModel


class TripCreate(BaseModel):
    title: str
    description: Optional[str] = None
    status: str = "past"
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    tags: list[str] = []
    visibility: str = "private"


class TripUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    tags: Optional[list[str]] = None
    visibility: Optional[str] = None


class TripRead(BaseModel):
    id: uuid.UUID
    user_id: str
    title: str
    description: Optional[str]
    status: str
    start_date: Optional[date]
    end_date: Optional[date]
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

- [ ] **Step 3: Create app/routers/trips.py**

```python
import logging
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.trip import Trip
from app.schemas.trip import TripCreate, TripRead, TripUpdate, TripListResponse

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/trips", tags=["trips"])


@router.get("", response_model=TripListResponse)
async def list_trips(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    status: Optional[str] = None,
):
    q = select(Trip).where(Trip.user_id == user_id)
    if status:
        q = q.where(Trip.status == status)

    total_result = await db.execute(select(func.count()).select_from(q.subquery()))
    total = total_result.scalar_one()

    q = q.order_by(Trip.updated_at.desc()).offset((page - 1) * limit).limit(limit)
    result = await db.execute(q)
    trips = result.scalars().all()

    return TripListResponse(items=list(trips), total=total, page=page, limit=limit)


@router.post("", response_model=TripRead, status_code=201)
async def create_trip(
    body: TripCreate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    trip = Trip(user_id=user_id, **body.model_dump())
    db.add(trip)
    await db.flush()
    await db.refresh(trip)
    return trip


@router.get("/{trip_id}", response_model=TripRead)
async def get_trip(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip


@router.put("/{trip_id}", response_model=TripRead)
async def update_trip(
    trip_id: uuid.UUID,
    body: TripUpdate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    for k, v in body.model_dump(exclude_none=True).items():
        setattr(trip, k, v)
    await db.flush()
    await db.refresh(trip)
    return trip


@router.delete("/{trip_id}", status_code=204)
async def delete_trip(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    await db.delete(trip)
```

- [ ] **Step 4: Run trip tests**

```bash
cd /home/zach/Atlas/backend
python -m pytest tests/test_trips.py -v
```
Expected: all 4 tests `PASSED`. Note: these tests require a running PostgreSQL — run inside `docker compose exec atlas-backend pytest tests/test_trips.py` if running locally.

- [ ] **Step 5: Commit**

```bash
cd /home/zach/Atlas
git add backend/app/schemas/trip.py backend/app/routers/trips.py backend/tests/test_trips.py
git commit -m "feat(atlas): add Trip CRUD endpoints with user isolation"
```

---

## Task 7: Destination CRUD + country_visits refresh

**Files:**
- Create: `backend/app/schemas/destination.py`
- Create: `backend/app/routers/destinations.py`
- Create: `backend/tests/test_destinations.py`

- [ ] **Step 1: Write failing destination tests**

Create `backend/tests/test_destinations.py`:
```python
import pytest


async def create_test_trip(client) -> str:
    resp = await client.post("/api/v1/trips", json={"title": "Test Trip"})
    assert resp.status_code == 201
    return resp.json()["id"]


@pytest.mark.asyncio
async def test_add_destination(authed_client):
    trip_id = await create_test_trip(authed_client)
    response = await authed_client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={
            "city": "Tokyo",
            "country_code": "JP",
            "country_name": "Japan",
            "arrival_date": "2025-03-15",
            "departure_date": "2025-03-22",
        },
    )
    assert response.status_code == 201
    body = response.json()
    assert body["city"] == "Tokyo"
    assert body["nights"] == 7


@pytest.mark.asyncio
async def test_add_destination_with_coordinates(authed_client):
    trip_id = await create_test_trip(authed_client)
    response = await authed_client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={
            "city": "Paris",
            "country_code": "FR",
            "country_name": "France",
            "latitude": 48.8566,
            "longitude": 2.3522,
        },
    )
    assert response.status_code == 201
    body = response.json()
    assert body["latitude"] == pytest.approx(48.8566, abs=0.001)


@pytest.mark.asyncio
async def test_destination_belongs_to_trip(authed_client):
    trip_id = await create_test_trip(authed_client)
    await authed_client.post(
        f"/api/v1/trips/{trip_id}/destinations",
        json={"city": "Osaka", "country_code": "JP", "country_name": "Japan"},
    )
    response = await authed_client.get(f"/api/v1/trips/{trip_id}/destinations")
    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["city"] == "Osaka"
```

Run to verify failures:
```bash
python -m pytest tests/test_destinations.py -v
```
Expected: failures — router not created.

- [ ] **Step 2: Create app/schemas/destination.py**

```python
import uuid
from datetime import datetime, date
from typing import Optional
from pydantic import BaseModel, model_validator


class DestinationCreate(BaseModel):
    city: str
    country_code: str
    country_name: str
    region: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    arrival_date: Optional[date] = None
    departure_date: Optional[date] = None
    notes: Optional[str] = None
    rating: Optional[int] = None
    order_index: int = 0

    @model_validator(mode="after")
    def validate_coordinates(self):
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("Provide both latitude and longitude, or neither")
        return self


class DestinationUpdate(BaseModel):
    city: Optional[str] = None
    country_code: Optional[str] = None
    country_name: Optional[str] = None
    region: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    arrival_date: Optional[date] = None
    departure_date: Optional[date] = None
    notes: Optional[str] = None
    rating: Optional[int] = None
    order_index: Optional[int] = None


class DestinationRead(BaseModel):
    id: uuid.UUID
    trip_id: uuid.UUID
    user_id: str
    city: str
    country_code: str
    country_name: str
    region: Optional[str]
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    arrival_date: Optional[date]
    departure_date: Optional[date]
    nights: Optional[int]
    notes: Optional[str]
    rating: Optional[int]
    order_index: int
    created_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_with_geo(cls, dest) -> "DestinationRead":
        """Extract lat/lng from GeoAlchemy2 WKBElement."""
        from geoalchemy2.shape import to_shape
        lat = lng = None
        if dest.location is not None:
            pt = to_shape(dest.location)
            lng, lat = pt.x, pt.y
        data = {c.name: getattr(dest, c.name) for c in dest.__table__.columns}
        data["latitude"] = lat
        data["longitude"] = lng
        return cls(**data)
```

- [ ] **Step 3: Create app/routers/destinations.py**

```python
import logging
import uuid
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession
from geoalchemy2.shape import from_shape
from shapely.geometry import Point

from app.auth import CurrentUser
from app.database import get_db
from app.models.destination import Destination
from app.models.trip import Trip
from app.schemas.destination import DestinationCreate, DestinationRead, DestinationUpdate

logger = logging.getLogger(__name__)
router = APIRouter(tags=["destinations"])


async def _refresh_country_visits(user_id: str) -> None:
    """Refresh country_visits materialized view for a user. Called as background task."""
    from app.database import async_session_factory
    async with async_session_factory() as db:
        await db.execute(text("REFRESH MATERIALIZED VIEW CONCURRENTLY country_visits"))
        await db.commit()
    logger.info("Refreshed country_visits for user %s", user_id)


async def _get_trip_or_404(trip_id: uuid.UUID, user_id: str, db: AsyncSession) -> Trip:
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip


@router.get("/trips/{trip_id}/destinations", response_model=list[DestinationRead])
async def list_destinations(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    await _get_trip_or_404(trip_id, user_id, db)
    result = await db.execute(
        select(Destination)
        .where(Destination.trip_id == trip_id, Destination.user_id == user_id)
        .order_by(Destination.order_index, Destination.arrival_date)
    )
    dests = result.scalars().all()
    return [DestinationRead.from_orm_with_geo(d) for d in dests]


@router.post("/trips/{trip_id}/destinations", response_model=DestinationRead, status_code=201)
async def add_destination(
    trip_id: uuid.UUID,
    body: DestinationCreate,
    user_id: CurrentUser,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    await _get_trip_or_404(trip_id, user_id, db)

    nights = None
    if body.arrival_date and body.departure_date:
        nights = (body.departure_date - body.arrival_date).days

    location = None
    if body.latitude is not None and body.longitude is not None:
        location = from_shape(Point(body.longitude, body.latitude), srid=4326)

    dest = Destination(
        trip_id=trip_id,
        user_id=user_id,
        city=body.city,
        country_code=body.country_code,
        country_name=body.country_name,
        region=body.region,
        location=location,
        arrival_date=body.arrival_date,
        departure_date=body.departure_date,
        nights=nights,
        notes=body.notes,
        rating=body.rating,
        order_index=body.order_index,
    )
    db.add(dest)
    await db.flush()
    await db.refresh(dest)
    background_tasks.add_task(_refresh_country_visits, user_id)
    return DestinationRead.from_orm_with_geo(dest)


@router.put("/destinations/{dest_id}", response_model=DestinationRead)
async def update_destination(
    dest_id: uuid.UUID,
    body: DestinationUpdate,
    user_id: CurrentUser,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Destination).where(Destination.id == dest_id, Destination.user_id == user_id))
    dest = result.scalar_one_or_none()
    if dest is None:
        raise HTTPException(status_code=404, detail="Destination not found")

    update_data = body.model_dump(exclude_none=True)
    lat = update_data.pop("latitude", None)
    lng = update_data.pop("longitude", None)
    if lat is not None and lng is not None:
        dest.location = from_shape(Point(lng, lat), srid=4326)

    for k, v in update_data.items():
        setattr(dest, k, v)

    if dest.arrival_date and dest.departure_date:
        dest.nights = (dest.departure_date - dest.arrival_date).days

    await db.flush()
    await db.refresh(dest)
    background_tasks.add_task(_refresh_country_visits, user_id)
    return DestinationRead.from_orm_with_geo(dest)


@router.delete("/destinations/{dest_id}", status_code=204)
async def delete_destination(
    dest_id: uuid.UUID,
    user_id: CurrentUser,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Destination).where(Destination.id == dest_id, Destination.user_id == user_id))
    dest = result.scalar_one_or_none()
    if dest is None:
        raise HTTPException(status_code=404, detail="Destination not found")
    await db.delete(dest)
    background_tasks.add_task(_refresh_country_visits, user_id)
```

- [ ] **Step 4: Run destination tests**

```bash
cd /home/zach/Atlas/backend
python -m pytest tests/test_destinations.py -v
```
Expected: all 3 tests `PASSED` (run inside Docker for full PostGIS support).

- [ ] **Step 5: Commit**

```bash
cd /home/zach/Atlas
git add backend/app/schemas/destination.py backend/app/routers/destinations.py backend/tests/test_destinations.py
git commit -m "feat(atlas): add Destination CRUD with PostGIS coordinates + country_visits background refresh"
```

---

## Task 8: Map data endpoints + Redis cache

**Files:**
- Create: `backend/app/services/map_cache.py`
- Create: `backend/app/routers/map.py`
- Create: `backend/tests/test_map.py`

- [ ] **Step 1: Write failing map tests**

Create `backend/tests/test_map.py`:
```python
import pytest


@pytest.mark.asyncio
async def test_map_countries_requires_auth(client):
    response = await client.get("/api/v1/map/countries")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_map_countries_returns_list(authed_client):
    response = await authed_client.get("/api/v1/map/countries")
    assert response.status_code == 200
    body = response.json()
    assert isinstance(body, list)


@pytest.mark.asyncio
async def test_map_cities_returns_list(authed_client):
    response = await authed_client.get("/api/v1/map/cities")
    assert response.status_code == 200
    body = response.json()
    assert isinstance(body, list)
```

Run to verify failures:
```bash
python -m pytest tests/test_map.py -v
```
Expected: first test passes (auth guard), other 2 fail.

- [ ] **Step 2: Create app/services/map_cache.py**

```python
import json
import logging
from typing import Any

import redis.asyncio as aioredis

from app.config import settings

logger = logging.getLogger(__name__)
MAP_TTL = 300  # 5 minutes

_redis: aioredis.Redis | None = None


def get_redis() -> aioredis.Redis:
    global _redis
    if _redis is None:
        _redis = aioredis.from_url(settings.redis_url, decode_responses=True)
    return _redis


async def get_cached(key: str) -> Any | None:
    try:
        value = await get_redis().get(key)
        return json.loads(value) if value else None
    except Exception as exc:
        logger.warning("Redis get failed for %s: %s", key, exc)
        return None


async def set_cached(key: str, value: Any, ttl: int = MAP_TTL) -> None:
    try:
        await get_redis().setex(key, ttl, json.dumps(value))
    except Exception as exc:
        logger.warning("Redis set failed for %s: %s", key, exc)
```

- [ ] **Step 3: Create app/routers/map.py**

```python
import logging
from sqlalchemy import text
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from geoalchemy2.shape import to_shape

from app.auth import CurrentUser
from app.database import get_db
from app.services.map_cache import get_cached, set_cached

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/map", tags=["map"])


@router.get("/countries")
async def get_map_countries(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """Country visit summary for choropleth layer. Cached 5 min per user."""
    cache_key = f"map:countries:{user_id}"
    cached = await get_cached(cache_key)
    if cached is not None:
        return cached

    result = await db.execute(
        text("""
            SELECT
                cv.country_code,
                cv.country_name,
                cv.visit_count,
                cv.first_visit::text,
                cv.last_visit::text,
                cv.total_nights,
                cv.trip_ids::text[]
            FROM country_visits cv
            WHERE cv.user_id = :user_id
        """),
        {"user_id": user_id},
    )
    rows = result.mappings().all()
    data = [dict(r) for r in rows]
    await set_cached(cache_key, data)
    return data


@router.get("/cities")
async def get_map_cities(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
):
    """All visited city points for marker layer. Cached 5 min per user."""
    cache_key = f"map:cities:{user_id}"
    cached = await get_cached(cache_key)
    if cached is not None:
        return cached

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
    data = [dict(r) for r in rows]
    await set_cached(cache_key, data)
    return data
```

- [ ] **Step 4: Run map tests**

```bash
cd /home/zach/Atlas/backend
python -m pytest tests/test_map.py -v
```
Expected: all 3 tests `PASSED`.

- [ ] **Step 5: Commit**

```bash
cd /home/zach/Atlas
git add backend/app/services/map_cache.py backend/app/routers/map.py backend/tests/test_map.py
git commit -m "feat(atlas): add map data endpoints (/map/countries, /map/cities) with Redis cache"
```

---

## Task 9: Country seed script

**Files:**
- Create: `backend/scripts/seed_countries.py`

- [ ] **Step 1: Create the seed script**

Create `backend/scripts/seed_countries.py`:
```python
#!/usr/bin/env python3
"""
Seed the countries table from Natural Earth 110m admin-0 data.

Usage (from inside the backend container):
    python scripts/seed_countries.py

Downloads ~1MB shapefile on first run. Safe to re-run (upserts by country code).
"""
import io
import logging
import os
import urllib.request
import zipfile

import psycopg2
from shapely.geometry import mapping, shape
import fiona

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

NE_URL = "https://naciscdn.org/naturalearth/110m/cultural/ne_110m_admin_0_countries.zip"
DATABASE_URL = os.environ["DATABASE_URL_SYNC"]

ISO_A2_FIELD = "ISO_A2"
NAME_FIELD = "NAME"
NAME_LONG_FIELD = "NAME_LONG"
CONTINENT_FIELD = "CONTINENT"


def download_shapefile() -> bytes:
    logger.info("Downloading Natural Earth 110m countries shapefile...")
    with urllib.request.urlopen(NE_URL) as resp:
        return resp.read()


def parse_shapefile(zip_bytes: bytes) -> list[dict]:
    records = []
    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
        shp_name = next(n for n in zf.namelist() if n.endswith(".shp"))
        # Extract to /tmp for fiona
        zf.extractall("/tmp/ne_countries")

    with fiona.open(f"/tmp/ne_countries/{shp_name.split('/')[-1]}") as src:
        for feature in src:
            props = feature["properties"]
            iso = props.get(ISO_A2_FIELD, "").strip()
            if not iso or iso in ("-99", ""):
                continue
            geom = shape(feature["geometry"])
            if geom.geom_type == "Polygon":
                from shapely.geometry import MultiPolygon
                geom = MultiPolygon([geom])
            records.append({
                "code": iso,
                "name": props.get(NAME_FIELD, ""),
                "name_long": props.get(NAME_LONG_FIELD, ""),
                "continent": props.get(CONTINENT_FIELD, ""),
                "wkt": geom.wkt,
            })
    logger.info("Parsed %d country records", len(records))
    return records


def seed(records: list[dict]) -> None:
    # Convert postgresql+psycopg2:// URL to a psycopg2-compatible DSN
    dsn = DATABASE_URL.replace("postgresql+psycopg2://", "postgresql://")
    conn = psycopg2.connect(dsn)
    cur = conn.cursor()

    upserted = 0
    for rec in records:
        cur.execute(
            """
            INSERT INTO countries (code, name, name_long, continent, geometry)
            VALUES (%s, %s, %s, %s, ST_Multi(ST_GeomFromText(%s, 4326)))
            ON CONFLICT (code) DO UPDATE SET
                name = EXCLUDED.name,
                name_long = EXCLUDED.name_long,
                continent = EXCLUDED.continent,
                geometry = EXCLUDED.geometry
            """,
            (rec["code"], rec["name"], rec["name_long"], rec["continent"], rec["wkt"]),
        )
        upserted += 1

    conn.commit()
    cur.close()
    conn.close()
    logger.info("Upserted %d countries", upserted)


if __name__ == "__main__":
    zip_bytes = download_shapefile()
    records = parse_shapefile(zip_bytes)
    seed(records)
    logger.info("Country seed complete.")
```

- [ ] **Step 2: Run seed script inside backend container**

```bash
docker compose exec atlas-backend python scripts/seed_countries.py
```
Expected output:
```
INFO Downloading Natural Earth 110m countries shapefile...
INFO Parsed 177 country records
INFO Upserted 177 countries
INFO Country seed complete.
```

- [ ] **Step 3: Verify**

```bash
docker compose exec atlas-db psql -U atlas -d atlas -c "SELECT COUNT(*) FROM countries;"
```
Expected: `177` (or similar — Natural Earth 110m has ~177 countries).

- [ ] **Step 4: Commit**

```bash
cd /home/zach/Atlas
git add backend/scripts/seed_countries.py
git commit -m "feat(atlas): add country seed script from Natural Earth 110m data"
```

---

## Task 10: Integration smoke test + quality gates

**Files:**
- Modify: `backend/tests/conftest.py` (finalize DB-backed test fixtures)

- [ ] **Step 1: Run full test suite inside Docker**

```bash
docker compose exec atlas-backend pytest tests/ -v --tb=short
```
Expected: all tests pass.

- [ ] **Step 2: Raj quality gate — EXPLAIN ANALYZE on map queries**

```bash
docker compose exec atlas-db psql -U atlas -d atlas -c "
EXPLAIN ANALYZE
SELECT cv.country_code, cv.visit_count
FROM country_visits cv
WHERE cv.user_id = 'test_user';
"
```
Expected: sequential scan on materialized view — sub-millisecond for small data. The unique index `country_visits_uid_cc` covers this query.

```bash
docker compose exec atlas-db psql -U atlas -d atlas -c "
EXPLAIN ANALYZE
SELECT city, ST_Y(location::geometry), ST_X(location::geometry)
FROM destinations
WHERE user_id = 'test_user' AND location IS NOT NULL;
"
```
Expected: index scan on `destinations_user_id_idx`. PostGIS functions are cheap on small geometry.

- [ ] **Step 3: SOC quality gate — verify user isolation**

```bash
# Create two test users and verify trips don't cross
docker compose exec atlas-backend pytest tests/test_trips.py::test_cannot_read_another_users_trip -v
```
Expected: `PASSED`.

- [ ] **Step 4: Final commit**

```bash
cd /home/zach/Atlas
git add .
git commit -m "feat(atlas): Phase 1 backend complete — migrations, auth, CRUD, map endpoints"
```

---

## Phase 1 Backend Quality Checklist

Before marking Phase 1 backend done, verify all of these:

- [ ] `docker compose up` starts all 5 services cleanly
- [ ] `alembic upgrade head` runs all 3 migrations without errors
- [ ] Seed script populates 177 countries
- [ ] `GET /health` returns `{"status": "ok"}` with no auth
- [ ] `GET /api/v1/trips` returns 401 without JWT
- [ ] `GET /api/v1/trips` returns 200 with valid JWT
- [ ] Trip created by user A returns 404 when requested by user B
- [ ] Destination with lat/lng stores and returns coordinates correctly
- [ ] `GET /api/v1/map/countries` returns list (empty OK if no destinations)
- [ ] `GET /api/v1/map/cities` returns list with lat/lng fields
- [ ] All pytest tests pass inside `atlas-backend` container
