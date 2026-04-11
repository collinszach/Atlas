# CLAUDE.md — Atlas: International Travel Tracker

## Project Identity

**Atlas** is a personal travel intelligence platform: part archive, part journal, part trip planner.
It captures where you've been (past), tracks where you are (present), and helps you decide where to go next (future).
It is built for real travelers who want data fidelity — not an Instagram grid.

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
- **Cache:** Redis 7 (trip stats, geo lookups, rate limiting)
- **Background tasks:** APScheduler (flight data sync, weather fetch)
- **HTTP client:** httpx (async)

### Infrastructure (Docker Compose)
```
services: atlas-frontend, atlas-backend, atlas-db (postgres+postgis), atlas-redis, atlas-minio
```
All services on `atlas-network` bridge. PostgreSQL data and MinIO buckets on named volumes.

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
│   ├── app/
│   │   ├── (auth)/              # Clerk auth pages
│   │   ├── (app)/
│   │   │   ├── layout.tsx       # Authenticated shell
│   │   │   ├── map/             # Globe/map view
│   │   │   ├── trips/           # Trip list + detail
│   │   │   │   ├── [id]/
│   │   │   │   │   ├── page.tsx
│   │   │   │   │   ├── photos/
│   │   │   │   │   ├── timeline/
│   │   │   │   │   └── transport/
│   │   │   ├── plan/            # Future trips + bucket list
│   │   │   ├── discover/        # AI destination recommendations
│   │   │   ├── stats/           # Analytics dashboard
│   │   │   └── settings/
│   │   └── api/                 # Next.js API routes (thin proxy to FastAPI)
│   ├── components/
│   │   ├── map/
│   │   │   ├── WorldMap.tsx     # MapLibre GL globe
│   │   │   ├── TripLayer.tsx    # Country/city highlight layers
│   │   │   ├── FlightArc.tsx    # Animated great-circle arcs
│   │   │   └── CityMarker.tsx
│   │   ├── trips/
│   │   │   ├── TripCard.tsx
│   │   │   ├── TripTimeline.tsx
│   │   │   ├── CityChip.tsx
│   │   │   └── TransportLeg.tsx
│   │   ├── photos/
│   │   │   ├── PhotoGrid.tsx
│   │   │   ├── PhotoUploader.tsx
│   │   │   └── Lightbox.tsx
│   │   ├── planner/
│   │   │   ├── ItineraryBuilder.tsx
│   │   │   ├── BucketList.tsx
│   │   │   └── DestinationCard.tsx
│   │   └── ui/                  # Shared primitives
│   ├── lib/
│   │   ├── api.ts               # Typed API client
│   │   ├── maplibre.ts          # Map helpers, style config
│   │   └── utils.ts
│   └── types/
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
│   │   │   ├── trip.py
│   │   │   ├── destination.py
│   │   │   ├── transport.py
│   │   │   ├── photo.py
│   │   │   ├── accommodation.py
│   │   │   └── bucket_list.py
│   │   ├── schemas/             # Pydantic request/response
│   │   ├── routers/
│   │   │   ├── trips.py
│   │   │   ├── destinations.py
│   │   │   ├── transport.py
│   │   │   ├── photos.py
│   │   │   ├── planner.py
│   │   │   ├── discover.py      # AI recommendations
│   │   │   └── stats.py
│   │   ├── services/
│   │   │   ├── storage.py       # MinIO/S3 abstraction
│   │   │   ├── geo.py           # PostGIS helpers, geocoding
│   │   │   ├── flight.py        # Flight data enrichment
│   │   │   └── ai.py            # Claude API for recommendations
│   │   └── tasks/
│   │       ├── scheduler.py
│   │       └── weather_sync.py
│   ├── migrations/              # Alembic
│   └── tests/
│
└── scripts/
    ├── seed_countries.py        # Load Natural Earth country data → PostGIS
    ├── import_trip.py           # CLI: bulk import from CSV/JSON
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

-- Trips (the top-level container)
trips
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid()
  user_id       VARCHAR REFERENCES users(id) ON DELETE CASCADE
  title         VARCHAR NOT NULL
  description   TEXT
  status        VARCHAR CHECK (status IN ('past','active','planned','dream'))
  start_date    DATE
  end_date      DATE
  cover_photo_id UUID                -- FK → photos.id (nullable)
  tags          VARCHAR[]
  visibility    VARCHAR DEFAULT 'private' CHECK (visibility IN ('private','shared','public'))
  created_at    TIMESTAMPTZ DEFAULT now()
  updated_at    TIMESTAMPTZ DEFAULT now()

-- Destinations (cities/places within a trip)
destinations
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid()
  trip_id       UUID REFERENCES trips(id) ON DELETE CASCADE
  user_id       VARCHAR REFERENCES users(id) ON DELETE CASCADE
  city          VARCHAR NOT NULL
  country_code  CHAR(2) NOT NULL     -- ISO 3166-1 alpha-2
  country_name  VARCHAR NOT NULL
  region        VARCHAR              -- state/province
  location      GEOGRAPHY(POINT,4326) -- PostGIS point (lng, lat)
  arrival_date  DATE
  departure_date DATE
  nights        INTEGER GENERATED ALWAYS AS (departure_date - arrival_date) STORED
  notes         TEXT
  rating        SMALLINT CHECK (rating BETWEEN 1 AND 5)
  order_index   INTEGER              -- position within trip itinerary
  created_at    TIMESTAMPTZ DEFAULT now()

-- Transport Legs (flights, cars, trains, ferries, buses)
transport_legs
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid()
  trip_id       UUID REFERENCES trips(id) ON DELETE CASCADE
  user_id       VARCHAR REFERENCES users(id) ON DELETE CASCADE
  type          VARCHAR NOT NULL CHECK (type IN ('flight','car','train','ferry','bus','walk','other'))
  -- Flight-specific
  flight_number VARCHAR
  airline       VARCHAR
  origin_iata   CHAR(3)
  dest_iata     CHAR(3)
  origin_city   VARCHAR
  dest_city     VARCHAR
  -- General
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

-- Accommodations
accommodations
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid()
  trip_id       UUID REFERENCES trips(id) ON DELETE CASCADE
  destination_id UUID REFERENCES destinations(id) ON DELETE SET NULL
  user_id       VARCHAR REFERENCES users(id) ON DELETE CASCADE
  name          VARCHAR NOT NULL
  type          VARCHAR CHECK (type IN ('hotel','airbnb','hostel','house','camping','other'))
  address       TEXT
  location      GEOGRAPHY(POINT,4326)
  check_in      TIMESTAMPTZ
  check_out     TIMESTAMPTZ
  confirmation  VARCHAR
  cost_per_night NUMERIC(10,2)
  currency      CHAR(3) DEFAULT 'USD'
  rating        SMALLINT CHECK (rating BETWEEN 1 AND 5)
  notes         TEXT

-- Photos
photos
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid()
  user_id       VARCHAR REFERENCES users(id) ON DELETE CASCADE
  trip_id       UUID REFERENCES trips(id) ON DELETE CASCADE
  destination_id UUID REFERENCES destinations(id) ON DELETE SET NULL
  storage_key   VARCHAR NOT NULL     -- MinIO/R2 object key
  thumbnail_key VARCHAR              -- auto-generated 400px thumbnail
  original_filename VARCHAR
  caption       TEXT
  taken_at      TIMESTAMPTZ          -- EXIF datetime if available
  location      GEOGRAPHY(POINT,4326) -- EXIF GPS if available
  width         INTEGER
  height        INTEGER
  size_bytes    BIGINT
  is_cover      BOOLEAN DEFAULT false
  order_index   INTEGER
  created_at    TIMESTAMPTZ DEFAULT now()

-- Bucket List / Future Destinations
bucket_list
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid()
  user_id       VARCHAR REFERENCES users(id) ON DELETE CASCADE
  country_code  CHAR(2)
  country_name  VARCHAR
  city          VARCHAR
  priority      SMALLINT DEFAULT 3 CHECK (priority BETWEEN 1 AND 5)
  reason        TEXT                 -- why do you want to go
  ideal_season  VARCHAR              -- 'spring','summer','fall','winter','any'
  estimated_cost NUMERIC(10,2)
  trip_id       UUID REFERENCES trips(id) ON DELETE SET NULL  -- links to a planned trip
  ai_summary    TEXT                 -- Claude-generated destination brief
  created_at    TIMESTAMPTZ DEFAULT now()

-- Country visit rollup (materialized, for map layer performance)
-- Refreshed on INSERT/UPDATE to destinations
country_visits (MATERIALIZED VIEW)
  user_id       VARCHAR
  country_code  CHAR(2)
  country_name  VARCHAR
  visit_count   INTEGER
  first_visit   DATE
  last_visit    DATE
  total_nights  INTEGER
  trip_ids      UUID[]
```

### PostGIS Indexes
```sql
CREATE INDEX destinations_location_idx ON destinations USING GIST (location);
CREATE INDEX transport_legs_origin_idx ON transport_legs USING GIST (origin_geo);
CREATE INDEX transport_legs_dest_idx   ON transport_legs USING GIST (dest_geo);
CREATE INDEX photos_location_idx       ON photos USING GIST (location);
```

---

## API Design

All routes under `/api/v1/`. All routes require `Authorization: Bearer <clerk_jwt>`. User ID extracted from JWT — never trusted from request body.

```
GET    /trips                        List user's trips (paginated, filter by status)
POST   /trips                        Create trip
GET    /trips/{id}                   Trip detail + destinations + transport
PUT    /trips/{id}                   Update trip
DELETE /trips/{id}                   Soft delete

GET    /trips/{id}/destinations      All destinations in trip
POST   /trips/{id}/destinations      Add destination
PUT    /destinations/{id}            Update destination
DELETE /destinations/{id}            Remove destination

GET    /trips/{id}/transport         All transport legs
POST   /trips/{id}/transport         Log a transport leg
PUT    /transport/{id}               Update leg
DELETE /transport/{id}               Remove leg

GET    /trips/{id}/photos            Photos for trip (paginated)
POST   /trips/{id}/photos/upload     Multipart upload → MinIO → returns photo record
DELETE /photos/{id}                  Delete photo + storage object

GET    /map/countries                Country visit summary (for map choropleth)
GET    /map/cities                   All visited city points (for map markers)
GET    /map/arcs                     All flight arcs (origin/dest geo pairs)

GET    /stats                        Aggregate stats for user
GET    /stats/heatmap                Visit count by country for heatmap
GET    /stats/timeline               Trips over time (for timeline view)

GET    /bucket-list                  User's bucket list
POST   /bucket-list                  Add item
PUT    /bucket-list/{id}             Update priority, link to trip
DELETE /bucket-list/{id}             Remove item

POST   /discover/recommend           AI destination recommendation (body: preferences)
POST   /discover/destination-brief   AI brief for a specific country/city
GET    /discover/best-time/{country} Best travel months (weather + crowd data)

POST   /transport/enrich-flight      Given flight number + date → enrich with route/distance/duration
```

---

## Map Implementation

### MapLibre GL Configuration
- **Projection:** Globe (3D) by default, toggle to flat Mercator
- **Style:** Dark ocean base (consistent with nSwell aesthetic) using a self-hosted style or Protomaps tiles
- **Do not** use Mapbox — stay MapLibre + free tile sources

### Map Layers (render in this order)
1. **Country choropleth** — filled polygons from `country_visits` view; color intensity = visit count
2. **City markers** — clustered points for visited cities; click → city detail sidebar
3. **Flight arcs** — animated great-circle arcs for all logged flights; color by trip
4. **Future pins** — bucket list destinations shown as outline/ghost markers
5. **Photo clusters** — optional layer: cluster photos by GPS location (EXIF)

### Tile Source
- Use **Protomaps** (free, self-hostable PMTiles) for country boundaries + base tiles
- Seed `public.countries` table from Natural Earth 110m data for PostGIS polygon queries

### Interactions
- Click country → slide-in panel: trips there, photos, stats, "Add to bucket list"
- Click city marker → city detail: dates visited, photos, transport to/from
- Click flight arc → transport leg detail
- Map filter bar: filter by year, trip, transport type

---

## Photo System

### Upload Flow
1. Client selects files → React Hook Form multipart POST to `/api/v1/trips/{id}/photos/upload`
2. FastAPI receives file → streams to MinIO via `aiobotocore`
3. Background task: generate 400px thumbnail via Pillow, extract EXIF (datetime, GPS)
4. If EXIF GPS → write `location` on photo record
5. Return photo record immediately; thumbnail status updated async

### Storage Keys
```
photos/{user_id}/{trip_id}/{photo_id}.{ext}
thumbnails/{user_id}/{trip_id}/{photo_id}_thumb.webp
```

### Photo Browser UI
- **Grid view:** Masonry layout per trip/destination; lazy loaded
- **Lightbox:** Full-screen viewer with caption, date, location map mini-inset
- **Map view toggle:** Plot EXIF-geotagged photos on mini-map within trip
- **Upload:** Drag-drop zone with progress bars; batch upload up to 50 at once
- **Cover selection:** Any photo can be set as trip cover; shown on trip card

---

## AI Integration (Claude API)

### Destination Recommendations — `/discover/recommend`
```python
# Request body
{
  "preferences": {
    "climate": "warm",
    "duration_days": 10,
    "budget": "moderate",       # budget / moderate / luxury
    "interests": ["hiking", "food", "history"],
    "avoid_crowds": true,
    "departure_region": "North America",
    "travel_month": "October"
  },
  "already_visited": ["FR", "JP", "MX", "IT"]  # ISO codes from user's history
}
```

System prompt includes:
- User's full visit history (countries + cities + ratings)
- User's bucket list
- Explicit preferences from request
- Instruction: return structured JSON with 3 recommendations, each with: country, city, why_you'll_love_it (personalized to their history), best_time, rough_cost, getting_there hint

### Destination Brief — `/discover/destination-brief`
On-demand one-pager for any country/city the user is considering:
- Overview, best months, visa requirements for common passports, rough costs, must-do activities, food highlights, transport options within country
- Cached in Redis for 24h per destination

### Pre-trip Itinerary Assist
Within the planner, user can request AI-generated day-by-day itinerary for a destination set. Returns structured JSON that populates the `ItineraryBuilder` component.

---

## Authentication + Multi-User

### Clerk Configuration
- Provider: Clerk (handles OAuth, magic link, MFA)
- Social logins: Google, Apple
- After sign-up webhook → POST `/api/v1/users/sync` → upsert `users` table
- JWT verification: FastAPI middleware validates Clerk JWT on every request
- User isolation: every DB query filters `WHERE user_id = current_user_id`

### Data Sharing
- Trips have `visibility` field: `private` / `shared` / `public`
- Shared trips: generate a signed URL (time-limited, no auth required to view)
- Public trips: appear in a read-only public profile at `/u/{username}`

---

## Build Phases

### Phase 1 — Foundation (Week 1–2)
- [ ] Docker Compose: postgres+postgis, redis, minio, backend, frontend
- [ ] Alembic migrations: users, trips, destinations
- [ ] Clerk auth integration (frontend + backend JWT middleware)
- [ ] CRUD: trips + destinations
- [ ] World map: MapLibre GL globe + country choropleth from `country_visits`
- [ ] City markers layer
- [ ] Basic trip list + trip detail page

### Phase 2 — Photos (Week 2–3)
- [ ] MinIO bucket setup + IAM policy
- [ ] Photo upload API + MinIO streaming
- [ ] EXIF extraction (datetime + GPS) via Pillow/exifread
- [ ] Thumbnail generation (async background task)
- [ ] Photo grid + lightbox component
- [ ] Trip cover photo selection

### Phase 3 — Transport (Week 3–4)
- [ ] Transport leg CRUD
- [ ] Flight enrichment service (manual entry + optional AviationStack lookup)
- [ ] Great-circle arc calculation + MapLibre arc layer
- [ ] Accommodation CRUD
- [ ] Transport timeline view within trip detail

### Phase 4 — Planning (Week 4–5)
- [ ] Bucket list CRUD
- [ ] Future trips (`status = 'planned'`) with ghost markers on map
- [ ] Itinerary builder (dnd-kit drag-drop day planning)
- [ ] Best-time-to-visit API (Open-Meteo historical climate data)
- [ ] Map filter bar (year, trip, status)

### Phase 5 — AI + Discovery (Week 5–6)
- [ ] Claude API integration (destination recommendations)
- [ ] Destination brief endpoint + UI
- [ ] AI itinerary assist (structured JSON → itinerary builder)
- [ ] Bucket list AI enrichment (auto-populate `ai_summary` on add)

### Phase 6 — Stats + Polish (Week 6–7)
- [ ] Stats dashboard: countries visited, total distance flown, nights away, most visited country, longest trip, CO2 estimate
- [ ] Timeline view (horizontal scrollable trip history)
- [ ] Data export (JSON + CSV)
- [ ] Public profile + shared trip links
- [ ] Performance: materialized view refresh strategy, Redis caching for map layers

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

# AI
ANTHROPIC_API_KEY=sk-ant-...

# Optional: flight enrichment
AVIATIONSTACK_API_KEY=...

# Frontend
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_live_...
NEXT_PUBLIC_API_BASE=http://localhost:8000
NEXT_PUBLIC_MAPTILER_KEY=...     # or use Protomaps (free, preferred)
```

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
- Display: `Playfair Display` (trip titles, country names)
- Body: `IBM Plex Sans` (UI copy, stats)
- Mono: `IBM Plex Mono` (flight numbers, dates, coordinates)

---

## Performance Constraints

- Map layer data (countries + cities) must load in < 500ms — cache in Redis, invalidate on destination write
- Photo grid: lazy load with `next/image`, serve thumbnails only in grid view
- Trip list: paginate at 20 trips per page
- PostGIS country polygon queries: use simplified 110m geometry for map, 10m only for precise point-in-polygon on upload
- Materialized view `country_visits`: refresh CONCURRENTLY triggered by destination write (no lock)

---

## What Claude Code Should Never Do

- Never expose another user's data — `user_id` filter is mandatory on every query, not optional
- Never delete photos from MinIO without also deleting the DB record (and vice versa) — wrap in a transaction + storage call, rollback if storage fails
- Never commit `.env` — `.claudeignore` must include `.env*`
- Never rewrite a migration — always add a new one
- Never embed the Anthropic API key in frontend code — all AI calls go through the FastAPI backend
- Never use Mapbox SDK — MapLibre GL only
- Never store Clerk user data beyond what's needed — `email`, `display_name`, `avatar_url` only