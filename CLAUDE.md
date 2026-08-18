# CLAUDE.md — Atlas: Flight Radar

## Project Identity

**Atlas** is a personal flight radar and logbook: flight radar / plane-finder, but better.
It tracks live aircraft overhead (Skywatch: ADS-B spotting, airport boards, push alerts — iOS),
and logs the flights and routes you've personally flown, with photos, distance, and time-in-air
stats, traced as great-circle arcs on a dark cartographic map.

---

## Behavioral Contracts

- **Predict before acting.** State which files you will touch and why before writing any code.
- **Trace dependency graph first.** Understand what calls what before modifying data models or APIs.
- **Surgical edits only.** Never rewrite a working module to fix an adjacent bug.
- **No boilerplate comments.** No `# This function does X` comments that restate the code.
- **Conventional commits.** `feat:`, `fix:`, `refactor:`, `chore:` — always.
- **Fail loudly.** Raise specific exceptions with context. No silent `except: pass`.
- **Type everything.** TypeScript strict mode on frontend. Pydantic models on backend. No `any`.
- **Test the seam.** When adding a feature, write the integration test at the API boundary first.

---

## Stack

### Frontend
- **Framework:** Next.js 14 (App Router), TypeScript, strict mode
- **Styling:** Tailwind CSS + CSS variables for theme tokens
- **Maps:** MapLibre GL JS (consistent with nSwell)
- **State:** Zustand for client state; React Query (TanStack) for server state
- **Auth:** Clerk (client-side hooks + middleware)
- **Photo viewer:** Yet Another React Lightbox (yarl)
- **Charts/stats:** Recharts
- **Drag & drop:** dnd-kit (itinerary builder)
- **Forms:** React Hook Form + Zod

### Backend
- **Framework:** FastAPI (Python 3.12)
- **ORM:** SQLAlchemy 2.0 (async) + Alembic migrations
- **Database:** PostgreSQL 16 + PostGIS extension
- **Auth validation:** Clerk JWT verification via `clerk-backend` SDK
- **Photo storage:** MinIO (local NUC) — S3-compatible, swap to Cloudflare R2 via env var
- **Cache:** Redis 7 (flight stats, geo lookups, rate limiting)
- **Background tasks:** APScheduler (flight data sync, weather fetch)
- **HTTP client:** httpx (async)

### Infrastructure
- **Frontend hosting:** Vercel (Next.js deployment)
- **Backend hosting:** Local NUC (Docker Compose)
  - Services: `atlas-backend`, `atlas-db` (postgres+postgis), `atlas-redis`, `atlas-minio`
  - All services on `atlas-network` bridge. PostgreSQL data and MinIO buckets on named volumes.

---

## Repository Structure

```
atlas/
├── CLAUDE.md
├── SPEC.md
├── BUILD_PLAN.md
├── docker-compose.yml
├── docker-compose.prod.yml
├── .env.example
├── .claudeignore
│
├── frontend/
│   ├── src/app/
│   │   ├── (auth)/              # Clerk auth pages
│   │   ├── (app)/
│   │   │   ├── layout.tsx       # Authenticated shell
│   │   │   ├── map/             # Globe/map view (flight arcs)
│   │   │   ├── flights/         # Flight log: list, detail, photos, new
│   │   │   ├── stats/           # Flight stats dashboard
│   │   │   └── settings/
│   │   └── api/                 # Next.js API routes (thin proxy to FastAPI)
│   ├── src/components/
│   │   ├── map/                 # WorldMap.tsx (MapLibre GL globe, arcs-only), MapControls
│   │   ├── flights/              # FlightCard.tsx, FlightForm.tsx
│   │   ├── photos/               # PhotoGrid.tsx, PhotoUploader.tsx, Lightbox.tsx
│   │   └── ui/                   # Shared primitives
│   ├── src/hooks/                # useFlights, usePhotos, useStats, useMapData, useUser
│   ├── src/lib/
│   │   ├── api.ts               # Typed API client
│   │   ├── maplibre.ts          # Map helpers, style config
│   │   └── utils.ts
│   └── src/types/
│       └── index.ts             # Shared type definitions
│
├── backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── config.py            # Settings from env
│   │   ├── database.py          # Async engine + session
│   │   ├── auth.py              # Clerk JWT middleware
│   │   ├── models/
│   │   │   ├── user.py
│   │   │   ├── transport.py     # TransportLeg — the flights you've flown
│   │   │   ├── photo.py         # attached to a flown flight
│   │   │   └── skywatch.py      # Device, SkywatchPreference, AircraftAlert, NotableType, ...
│   │   ├── schemas/              # Pydantic request/response
│   │   ├── routers/
│   │   │   ├── transport.py     # /flights CRUD + /transport/enrich-flight
│   │   │   ├── photos.py        # photos on a flight
│   │   │   ├── map.py           # /map/arcs
│   │   │   ├── stats.py         # flight stats
│   │   │   ├── skywatch.py      # live ADS-B overhead, airport boards, alerts (iOS)
│   │   │   └── users.py
│   │   ├── services/
│   │   │   ├── storage.py       # MinIO/S3 abstraction
│   │   │   ├── adsb/            # airplanes.live + local dump1090 resolver
│   │   │   ├── skywatch/        # alert rules, watcher, APNs, NL prefs
│   │   │   ├── flightroute.py, aircraft_db.py, aircraft_photos.py, airport_schedule.py
│   │   │   └── search.py
│   │   └── tasks/
│   │       └── scheduler.py     # skywatch watch cycle
│   ├── migrations/              # Alembic
│   └── tests/
│
├── iOS/                          # Skywatch: live map, alerts, bookmarks, airport pages
│
└── scripts/
    └── export_backup.py
```

---

## Data Model

### Core Principle
**All data is user-scoped.** Every table has `user_id` (Clerk user ID string). No row-level data is accessible without a matching JWT. Enforce at the FastAPI middleware layer, not just the query layer.

### Schema

```sql
-- Users (mirror of Clerk, synced via webhook)
users
  id            VARCHAR PRIMARY KEY  -- Clerk user_id
  email         VARCHAR UNIQUE NOT NULL
  display_name  VARCHAR
  avatar_url    VARCHAR
  home_country  CHAR(2)              -- ISO 3166-1 alpha-2
  created_at    TIMESTAMPTZ DEFAULT now()
  preferences   JSONB DEFAULT '{}'   -- theme, units, privacy

-- Transport Legs (the flights you've flown — standalone, not trip-scoped)
transport_legs
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid()
  user_id       VARCHAR REFERENCES users(id) ON DELETE CASCADE
  flight_number VARCHAR
  airline       VARCHAR
  origin_iata   CHAR(3)
  dest_iata     CHAR(3)
  origin_city   VARCHAR
  dest_city     VARCHAR
  departure_at  TIMESTAMPTZ
  arrival_at    TIMESTAMPTZ
  duration_min  INTEGER
  distance_km   NUMERIC(10,2)
  seat_class    VARCHAR              -- economy, business, first
  booking_ref   VARCHAR
  cost          NUMERIC(10,2)
  currency      CHAR(3) DEFAULT 'USD'
  notes         TEXT
  -- Geo (computed or entered)
  origin_geo    GEOGRAPHY(POINT,4326)
  dest_geo      GEOGRAPHY(POINT,4326)
  created_at    TIMESTAMPTZ DEFAULT now()

-- Photos (attached to a flown flight — e.g. the plane, boarding pass)
photos
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
  user_id         VARCHAR REFERENCES users(id) ON DELETE CASCADE
  transport_leg_id UUID REFERENCES transport_legs(id) ON DELETE CASCADE
  storage_key     VARCHAR NOT NULL     -- MinIO/R2 object key
  thumbnail_key   VARCHAR              -- auto-generated 400px thumbnail
  original_filename VARCHAR
  caption         TEXT
  taken_at        TIMESTAMPTZ          -- EXIF datetime if available
  latitude        NUMERIC
  longitude       NUMERIC              -- EXIF GPS if available
  width           INTEGER
  height          INTEGER
  size_bytes      BIGINT
  is_cover        BOOLEAN DEFAULT false
  order_index     INTEGER
  created_at      TIMESTAMPTZ DEFAULT now()
```

Skywatch tables (`skywatch_devices`, `skywatch_preferences`, `aircraft_alerts`, `notable_types`,
`mil_callsign_prefixes`) back the live ADS-B spotting feature — see `backend/app/models/skywatch.py`.

### PostGIS Indexes
```sql
CREATE INDEX transport_legs_origin_idx ON transport_legs USING GIST (origin_geo);
CREATE INDEX transport_legs_dest_idx   ON transport_legs USING GIST (dest_geo);
```

---

## API Design

All routes under `/api/v1/`. All routes require `Authorization: Bearer <clerk_jwt>`. User ID extracted from JWT — never trusted from request body.

```
GET    /flights                      List user's flown flights
POST   /flights                      Log a flight
PUT    /flights/{id}                 Update a flight
DELETE /flights/{id}                 Remove a flight

GET    /flights/{id}/photos          Photos for a flight
POST   /flights/{id}/photos/upload   Multipart upload → MinIO → returns photo record
DELETE /photos/{id}                  Delete photo + storage object
POST   /photos/{id}/set-cover        Mark a photo as the flight's cover

GET    /map/arcs                     All flight arcs (origin/dest geo pairs)

GET    /stats                        Flight stats: distance, hours in air, top airline, CO2

POST   /transport/enrich-flight      Given flight number + date → enrich with route/distance/duration

GET    /skywatch/overhead            Live aircraft near a lat/lon (ADS-B)
GET    /skywatch/search              Search aircraft by flight/reg/hex/type/squawk
GET    /skywatch/aircraft/{hex}      Single-aircraft detail: route, photo, airframe, trail
GET    /skywatch/airports/{iata}/departures
GET    /skywatch/airports/{iata}/arrivals
POST   /skywatch/devices             Register a device for push alerts
POST   /skywatch/location            Update a device's last known location
```

---

## Map Implementation

### MapLibre GL Configuration
- **Projection:** Globe (3D) by default, toggle to flat Mercator
- **Style:** Dark ocean base (consistent with nSwell aesthetic) using a self-hosted style or Protomaps tiles
- **Do not** use Mapbox — stay MapLibre + free tile sources

### Map Layers (render in this order)
1. **Base map** — country borders/water on a dark ocean base
2. **Flight arcs** — great-circle arcs for every logged flight, drawn from `/map/arcs`

### Tile Source
- Use **Protomaps** (free, self-hostable PMTiles) for base map tiles

### Interactions
- Click flight arc → flight detail
- Toggle globe (3D) vs. flat Mercator projection

Live ADS-B overhead tracking (aircraft-as-dots-on-a-map, in real time) is a separate surface —
currently iOS-only, via Skywatch's `SkyView`/`LiveMapView` (MKMapView), not this web MapLibre map.

---

## Photo System

### Upload Flow
1. Client selects files → multipart POST to `/api/v1/flights/{id}/photos/upload`
2. FastAPI receives file → streams to MinIO via `aiobotocore`
3. Background task: generate 400px thumbnail via Pillow, extract EXIF (datetime, GPS)
4. If EXIF GPS → write `latitude`/`longitude` on photo record
5. Return photo record immediately; thumbnail status updated async

### Storage Keys
```
photos/{user_id}/{flight_id}/{photo_id}.{ext}
thumbnails/{user_id}/{flight_id}/{photo_id}_thumb.webp
```

### Photo Browser UI
- **Grid view:** Masonry layout per flight; lazy loaded
- **Lightbox:** Full-screen viewer with caption, date, location map mini-inset
- **Upload:** Drag-drop zone with progress bars; batch upload up to 50 at once
- **Cover selection:** Any photo can be set as a flight's cover

---

## Authentication + Multi-User

### Clerk Configuration
- Provider: Clerk (handles OAuth, magic link, MFA)
- Social logins: Google, Apple
- After sign-up webhook → POST `/api/v1/users/sync` → upsert `users` table
- JWT verification: FastAPI middleware validates Clerk JWT on every request
- User isolation: every DB query filters `WHERE user_id = current_user_id`

---

## Build Phases

### Phase 1 — Foundation
- [x] Docker Compose: postgres+postgis, redis, minio, backend, frontend
- [x] Alembic migrations: users, transport_legs, photos
- [x] Clerk auth integration (frontend + backend JWT middleware)
- [x] Flight log CRUD (`/flights`)
- [x] World map: MapLibre GL globe + flight-arc layer from `/map/arcs`
- [x] Flight list + flight detail page

### Phase 2 — Photos
- [x] MinIO bucket setup + IAM policy
- [x] Photo upload API + MinIO streaming, re-pointed to flights
- [x] EXIF extraction (datetime + GPS) via Pillow/exifread
- [x] Thumbnail generation (async background task)
- [x] Photo grid + lightbox component
- [x] Flight cover photo selection

### Phase 3 — Skywatch (live ADS-B, iOS)
- [x] Live overhead aircraft (airplanes.live + optional local dump1090 receiver)
- [x] Airport departures/arrivals board
- [x] Push alerts (notable types, military, emergency squawks, watchlist)
- [x] Aircraft search, type pages, bookmarks/life-list
- [ ] Port live overhead tracking to the web frontend (currently iOS-only)

### Phase 4 — Flight enrichment + stats
- [x] Flight enrichment service (manual entry + optional AviationStack lookup)
- [x] Great-circle arc calculation + MapLibre arc layer
- [x] Flight stats: distance, hours in air, top airline, most-flown airport, CO2 estimate

### Phase 5 — Polish
- [ ] Data export (JSON + CSV)
- [ ] Public profile + shared flight-log links

---

## Environment Variables

```bash
# Backend
DATABASE_URL=postgresql+asyncpg://atlas:password@atlas-db:5432/atlas
REDIS_URL=redis://atlas-redis:6379/0
CLERK_SECRET_KEY=sk_live_...
CLERK_WEBHOOK_SECRET=whsec_...

# Storage — swap STORAGE_BACKEND to switch NUC ↔ cloud
STORAGE_BACKEND=minio            # or: s3 (Cloudflare R2)
MINIO_ENDPOINT=atlas-minio:9000
MINIO_ACCESS_KEY=...
MINIO_SECRET_KEY=...
MINIO_BUCKET=atlas-photos
MINIO_PUBLIC_URL=http://localhost:9000

# If using Cloudflare R2 instead:
# R2_ENDPOINT=https://<account>.r2.cloudflarestorage.com
# R2_ACCESS_KEY_ID=...
# R2_SECRET_ACCESS_KEY=...
# R2_BUCKET=atlas-photos
# R2_PUBLIC_URL=https://photos.yourdomain.com

# Optional: flight enrichment
AVIATIONSTACK_API_KEY=...

# Skywatch (live ADS-B)
AIRPLANES_LIVE_BASE=https://api.airplanes.live/v2   # requires manual project approval — see below
DUMP1090_URL=                    # optional local receiver, preferred/merged over the network source
APNS_KEY_ID=...
APNS_TEAM_ID=...
APNS_AUTH_KEY=...

# Frontend
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_...
NEXT_PUBLIC_API_BASE=http://localhost:8000
NEXT_PUBLIC_MAPTILER_KEY=...     # or use Protomaps (free, preferred)
```

**airplanes.live note:** the free API now gates access behind manual approval — email them your
project description before requests will succeed (a User-Agent header alone is not sufficient).
A local `dump1090`/`readsb` receiver (RTL-SDR) via `DUMP1090_URL` avoids this gate entirely and
is preferred when available; `DataSourceResolver` merges both sources, preferring local data.

---

## Design System

**Aesthetic:** Dark cartographic — deep navy/slate backgrounds, aged-map parchment accents, geographic texture. Not travel-blog pastel. Think mission control meets explorer's logbook.

**Color tokens:**
```css
--atlas-bg:          #0a0e1a;   /* deep navy */
--atlas-surface:     #111827;   /* card backgrounds */
--atlas-border:      #1e2d45;   /* subtle borders */
--atlas-accent:      #c9a84c;   /* antique gold */
--atlas-accent-cool: #4a90d9;   /* ocean blue for map */
--atlas-text:        #e2e8f0;
--atlas-text-muted:  #64748b;
--atlas-visited:     #4a90d9;   /* country fill: visited */
--atlas-planned:     #c9a84c;   /* country fill: planned */
--atlas-bucket:      #374151;   /* country fill: on bucket list */
```

**Typography:**
- Display: `Playfair Display` (flight routes, headings)
- Body: `IBM Plex Sans` (UI copy, stats)
- Mono: `IBM Plex Mono` (flight numbers, dates, coordinates)

---

## Performance Constraints

- Map layer data (flight arcs) must load in < 500ms — cache in Redis, invalidate on flight write
- Photo grid: lazy load with `next/image`, serve thumbnails only in grid view
- Flight list: paginate results

---

## What Claude Code Should Never Do

- Never expose another user's data — `user_id` filter is mandatory on every query, not optional
- Never delete photos from MinIO without also deleting the DB record (and vice versa) — wrap in a transaction + storage call, rollback if storage fails
- Never commit `.env` — `.claudeignore` must include `.env*`
- Never rewrite a migration — always add a new one
- Never use Mapbox SDK — MapLibre GL only
- Never store Clerk user data beyond what's needed — `email`, `display_name`, `avatar_url` only