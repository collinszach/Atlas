# Atlas Phase 1 Design — Foundation

**Date:** 2026-04-11
**Status:** Approved
**Scope:** Docker Compose stack, DB schema, Clerk auth, Trip/Destination CRUD, MapLibre globe, basic trip UI

---

## Overview

Phase 1 establishes every load-bearing layer Atlas needs to run: containerized services, the PostGIS schema, user identity via Clerk, the CRUD surface for trips and destinations, and the world map globe with country choropleth. By end of Phase 1, a user can sign in, add a trip, log destinations, and see those destinations reflected on an interactive globe.

---

## Service Topology

All services run in Docker Compose on a single `atlas-network` bridge. No host-native services — all five containers start with `docker compose up`.

```
atlas-network (bridge)
├── atlas-db        postgres:16-postgis    :5432 (internal)
├── atlas-redis     redis:7-alpine         :6379 (internal)
├── atlas-minio     minio/minio            :9000/:9001 (9001 = console, dev only)
├── atlas-backend   fastapi + uvicorn      :8000 (exposed, dev)
└── atlas-frontend  next.js 14             :3000 (exposed, dev)
```

`docker-compose.prod.yml` overrides ports to internal-only and adds Nginx reverse proxy. Phase 1 ships only `docker-compose.yml` (dev-friendly defaults).

---

## Database Schema (Phase 1 migrations)

### Migration 001 — Core tables

```sql
-- users (mirror of Clerk, populated via webhook)
CREATE TABLE users (
  id            VARCHAR PRIMARY KEY,          -- Clerk user_id
  email         VARCHAR UNIQUE NOT NULL,
  display_name  VARCHAR,
  avatar_url    VARCHAR,
  home_country  CHAR(2),
  created_at    TIMESTAMPTZ DEFAULT now(),
  preferences   JSONB DEFAULT '{}'
);

-- trips
CREATE TABLE trips (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       VARCHAR NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title         VARCHAR NOT NULL,
  description   TEXT,
  status        VARCHAR NOT NULL DEFAULT 'past'
                  CHECK (status IN ('past','active','planned','dream')),
  start_date    DATE,
  end_date      DATE,
  cover_photo_id UUID,                        -- FK added Phase 2
  tags          VARCHAR[] DEFAULT '{}',
  visibility    VARCHAR NOT NULL DEFAULT 'private'
                  CHECK (visibility IN ('private','shared','public')),
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX trips_user_id_idx ON trips(user_id);

-- destinations
CREATE TABLE destinations (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id        UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id        VARCHAR NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  city           VARCHAR NOT NULL,
  country_code   CHAR(2) NOT NULL,
  country_name   VARCHAR NOT NULL,
  region         VARCHAR,
  location       GEOGRAPHY(POINT,4326),
  arrival_date   DATE,
  departure_date DATE,
  nights         INTEGER GENERATED ALWAYS AS
                   (CASE WHEN departure_date IS NOT NULL AND arrival_date IS NOT NULL
                    THEN departure_date - arrival_date ELSE NULL END) STORED,
  notes          TEXT,
  rating         SMALLINT CHECK (rating BETWEEN 1 AND 5),
  order_index    INTEGER DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX destinations_user_id_idx  ON destinations(user_id);
CREATE INDEX destinations_trip_id_idx  ON destinations(trip_id);
CREATE INDEX destinations_location_idx ON destinations USING GIST (location);
```

### Migration 002 — Materialized view + stub tables

```sql
-- country_visits (materialized — refreshed via background task after destination writes)
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
GROUP BY d.user_id, d.country_code;

CREATE UNIQUE INDEX country_visits_uid_cc ON country_visits(user_id, country_code);

-- transport_legs (Phase 3 feature — stubbed now to avoid FK re-migrations)
CREATE TABLE transport_legs (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id   UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id   VARCHAR NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type      VARCHAR NOT NULL DEFAULT 'flight',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- accommodations (Phase 3 — stubbed)
CREATE TABLE accommodations (
  id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id   UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  user_id   VARCHAR NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name      VARCHAR NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

### Migration 003 — Natural Earth country polygons

```sql
-- countries (base geography — seeded from Natural Earth 110m data)
CREATE TABLE countries (
  code        CHAR(2) PRIMARY KEY,   -- ISO 3166-1 alpha-2
  name        VARCHAR NOT NULL,
  name_long   VARCHAR,
  continent   VARCHAR,
  geometry    GEOMETRY(MULTIPOLYGON, 4326)
);
CREATE INDEX countries_geometry_idx ON countries USING GIST (geometry);
```

Seed: `scripts/seed_countries.py` downloads Natural Earth 110m admin-0 shapefile and bulk-loads into `countries` via psycopg2 + shapely. Runs as a one-time init container (`atlas-seed`) that exits after completion.

---

## Authentication — Clerk Integration

### Backend: FastAPI JWT middleware

```
Every request → ClerkJWTMiddleware
  ├── /health               → pass-through (no auth)
  ├── /api/v1/users/sync    → HMAC verify CLERK_WEBHOOK_SECRET (not JWT)
  └── all other /api/v1/*   → verify Clerk JWT → extract user_id → attach to request.state
```

`auth.py` uses `clerk-backend` Python SDK (`jwks_client` pattern). User ID is always sourced from the verified JWT — never from the request body.

### Webhook: user sync

`POST /api/v1/users/sync` handles `user.created` and `user.updated` events from Clerk. Upserts into `users` table. Required before any trip can be created (FK constraint).

### Frontend: Clerk provider

`ClerkProvider` wraps the entire `(app)` layout. `useAuth()` / `useUser()` hooks provide user state. The `middleware.ts` (Next.js) protects all `(app)/*` routes, redirecting unauthenticated users to `/sign-in`.

---

## API Endpoints (Phase 1)

All routes: `/api/v1/`. All require JWT except noted.

```
POST  /users/sync              Clerk webhook (HMAC, not JWT)
GET   /health                  Health check (no auth)

GET   /trips                   List user's trips (paginated: ?page=1&limit=20&status=)
POST  /trips                   Create trip
GET   /trips/{id}              Trip detail + destinations + transport stubs
PUT   /trips/{id}              Update trip
DELETE /trips/{id}             Hard delete (CASCADE to destinations). Phase 6 adds soft-delete/archive.

POST  /trips/{id}/destinations      Add destination → refresh country_visits async
GET   /trips/{id}/destinations      List destinations in trip
PUT   /destinations/{id}            Update destination → refresh country_visits async
DELETE /destinations/{id}           Remove destination → refresh country_visits async

GET   /map/countries            Country visit summary for choropleth (cached in Redis, 5-min TTL)
GET   /map/cities               All visited city points for markers
```

---

## Map Implementation (Phase 1)

### Component: `WorldMap.tsx`

- `MapLibre GL JS` with `maplibre-gl` npm package
- **Projection:** `globe` on init, toggle to `mercator` stored in `localStorage`
- **Style:** Custom dark style JSON defined in `lib/maplibre.ts`. Uses Protomaps CDN for Phase 1 tiles (no key, no download). Swap to self-hosted PMTiles in Phase 6.
- **Tile source:** Protomaps public CDN (`https://api.protomaps.com/tiles/v4/{z}/{x}/{y}.pbf?key=...`) using their free dev key for Phase 1. No MinIO setup required for tiles until Phase 6. MinIO is provisioned in Phase 1 Docker Compose but only used for photos (Phase 2).

### Layer stack (established in Phase 1, some empty until data exists):

| Order | Layer ID | Source | Phase 1 active? |
|---|---|---|---|
| 1 | `country-fill` | countries + country_visits | Yes — choropleth |
| 2 | `country-border` | countries | Yes — outline |
| 3 | `city-markers` | /map/cities | Yes — if destinations exist |
| 4 | `flight-arcs` | /map/arcs | Stubbed (Phase 3) |
| 5 | `bucket-ghost` | bucket_list | Stubbed (Phase 4) |
| 6 | `photo-clusters` | photos | Stubbed (Phase 2) |

**Choropleth logic:** Country fill color mapped from `visit_count`:
- 0 visits, on bucket list → `#374151` (dim)
- 0 visits, not on list → transparent (base tile color)
- 1 visit → `#1e4a7a`
- 2–4 visits → `#2e6aaa`
- 5+ visits → `#4a90d9`
- Planned trip → `#c9a84c` (gold, overrides visit count)

### Interactions (Phase 1):

- **Click country** → slide-in panel (right, 380px) showing country name, visit count, first/last visit, list of trips. Close on outside click or ESC.
- **Click city marker** → tooltip with city name and dates. Full panel in Phase 2.
- **Globe/flat toggle** → button top-right of map. Calls `map.setProjection()`.
- **Map filter bar** → stub only Phase 1 (filter by year/status added Phase 4).

---

## App Shell + Navigation

**Layout:** Icon sidebar rail (52px). Map is always the hero — the sidebar never overlaps the map.

```
┌──┬────────────────────────────────────────────┐
│  │                                            │
│  │           WorldMap (full height)           │
│  │                                            │
│  │                             ┌─ slide panel │
│  │                             │  (380px)     │
│  │                             │              │
│  │                             └──────────────│
└──┴────────────────────────────────────────────┘
```

**Sidebar icons (top to bottom):**
- Globe/Map (active state = gold)
- Trips list
- Plan (future trips + bucket list)
- Discover (AI recommendations)
- Stats
- ─ (divider)
- Settings (bottom)
- User avatar (bottom)

**Active route:** icon gets gold fill + subtle gold left border. No labels — tooltips on hover (Radix `Tooltip`).

---

## Frontend Pages (Phase 1)

| Route | Component | Notes |
|---|---|---|
| `/` (redirects to `/map`) | — | — |
| `/(app)/map` | `WorldMap` + country panel | Primary view |
| `/(app)/trips` | `TripList` | Cards grid, filter by status |
| `/(app)/trips/[id]` | `TripDetail` | Summary + destination timeline + transport stub |
| `/(app)/trips/[id]/new-destination` | `DestinationForm` | Add destination modal/page |
| `/(auth)/sign-in` | Clerk `<SignIn />` | Clerk-hosted or embedded component |
| `/(auth)/sign-up` | Clerk `<SignUp />` | Same |

---

## Design System Tokens Applied

Per CLAUDE.md:

```css
--atlas-bg:          #0a0e1a;
--atlas-surface:     #111827;
--atlas-border:      #1e2d45;
--atlas-accent:      #c9a84c;   /* gold — active state, CTAs */
--atlas-accent-cool: #4a90d9;   /* ocean blue — visited countries, links */
--atlas-text:        #e2e8f0;
--atlas-text-muted:  #64748b;
```

Fonts: `Playfair Display` (trip titles), `IBM Plex Sans` (body), `IBM Plex Mono` (codes, dates).

---

## Environment Variables (.env.example additions)

```bash
# Clerk
CLERK_SECRET_KEY=sk_live_...
CLERK_WEBHOOK_SECRET=whsec_...
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_...

# DB
DATABASE_URL=postgresql+asyncpg://atlas:password@atlas-db:5432/atlas
REDIS_URL=redis://atlas-redis:6379/0

# MinIO (tiles + future photos)
MINIO_ENDPOINT=atlas-minio:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=minioadmin
MINIO_BUCKET_PHOTOS=atlas-photos
MINIO_PUBLIC_URL=http://localhost:9000

# Storage backend (minio | s3)
STORAGE_BACKEND=minio

# Protomaps (free dev key for Phase 1 tiles — replace with self-hosted PMTiles in Phase 6)
NEXT_PUBLIC_PROTOMAPS_KEY=...

# AI (Phase 5 — stub now)
ANTHROPIC_API_KEY=sk-ant-...

# Optional: flight enrichment (Phase 3)
AVIATIONSTACK_API_KEY=
```

---

## Quality Gates

Before Phase 1 is marked complete:

- [ ] **Raj:** `EXPLAIN ANALYZE` on `/map/countries` and `/map/cities` — must be < 100ms with PostGIS indexes
- [ ] **Dev:** Every trip/destination endpoint returns 401 if JWT is missing or invalid
- [ ] **Dev:** User cannot read or modify another user's trips (test with two Clerk test users)
- [ ] **SOC:** MinIO bucket `atlas-photos` has no public policy; tiles bucket has read-only policy
- [ ] **Kai + Nina:** Every component passes TypeScript strict compilation (`npm run type-check`)
- [ ] **Raj:** `country_visits` materialized view refreshes correctly after destination create/delete

---

## What Phase 1 Does NOT Include

- Photo upload or EXIF extraction (Phase 2)
- Transport legs full schema (Phase 3)
- AI recommendations (Phase 5)
- Map filter bar (Phase 4)
- Public profiles / shared trip links (Phase 6)
- Production Nginx / `docker-compose.prod.yml` (Phase 6)
