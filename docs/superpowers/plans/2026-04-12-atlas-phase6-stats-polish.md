# Atlas Phase 6 — Stats + Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the stats dashboard, timeline view, data export, shared trip links, and public profile that complete the Atlas feature set.

**Architecture:** A new `backend/app/routers/stats.py` serves aggregate queries via `text()` SQL (consistent with `map.py`). A new `backend/app/routers/export.py` streams JSON/CSV responses. Shared trip links use Redis-backed random tokens. Public profile adds a `username` column to `users` (migration 008) and a new `/profile` router. The stats page replaces a placeholder; `/u/[username]` is a new Next.js route.

**Tech Stack:** FastAPI, SQLAlchemy 2.0 async `text()` queries, Python `csv` + `io.StringIO` for CSV, `secrets.token_urlsafe` for share tokens, Redis TTL keys, Next.js 14 App Router, TanStack Query v5, Recharts for stat bar (optional), Tailwind/Atlas tokens.

**Note — already done from Phase 6 spec:**
- Materialized view refresh on destination write: `_refresh_country_visits` background task in `destinations.py` ✓
- Redis caching for map layers: `map_cache.py` with 5-min TTL ✓

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `backend/app/routers/stats.py` | `GET /stats`, `GET /stats/timeline` |
| Create | `backend/app/routers/export.py` | `GET /export/json`, `GET /export/csv` |
| Modify | `backend/app/routers/trips.py` | Add `POST /trips/{id}/share` |
| Create | `backend/app/routers/shared.py` | `GET /shared/{token}` (public, no auth) |
| Create | `backend/app/routers/profile.py` | `GET /profile/{username}` (public) |
| Create | `backend/migrations/versions/008_user_username.py` | Add `username VARCHAR UNIQUE NULL` to users |
| Modify | `backend/app/models/user.py` | Add `username: Mapped[str | None]` field |
| Modify | `backend/app/schemas/user.py` | Add `username` to UserRead + new UserUpdate |
| Modify | `backend/app/main.py` | Register stats, export, shared, profile routers |
| Create | `backend/tests/test_stats.py` | Auth + aggregate value tests |
| Create | `backend/tests/test_export.py` | Auth + content-type tests |
| Create | `backend/tests/test_share.py` | Auth + token generation + public view tests |
| Modify | `frontend/src/types/index.ts` | Add `StatsResponse`, `TimelineTrip`, `ShareResponse`, `PublicProfile` |
| Create | `frontend/src/hooks/useStats.ts` | `useStats`, `useStatsTimeline` |
| Modify | `frontend/src/app/(app)/stats/page.tsx` | Replace placeholder with stat cards + timeline |
| Modify | `frontend/src/app/(app)/trips/[id]/page.tsx` | Add share button + copy-URL UI |
| Create | `frontend/src/app/u/[username]/page.tsx` | Public profile page |
| Modify | `frontend/src/app/(app)/settings/page.tsx` | Add username input field |

---

### Task 1: Stats backend router

**Files:**
- Create: `backend/app/routers/stats.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_stats.py`

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_stats.py`:

```python
import pytest
from httpx import AsyncClient
from tests.conftest import TEST_USER_ID

STATS_URL = "/api/v1/stats"
TIMELINE_URL = "/api/v1/stats/timeline"


@pytest.mark.asyncio
async def test_stats_requires_auth(client: AsyncClient):
    res = await client.get(STATS_URL)
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_timeline_requires_auth(client: AsyncClient):
    res = await client.get(TIMELINE_URL)
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_stats_returns_structure(auth_client: AsyncClient):
    res = await auth_client.get(STATS_URL)
    assert res.status_code == 200
    data = res.json()
    assert "countries_visited" in data
    assert "trips_count" in data
    assert "nights_away" in data
    assert "total_distance_km" in data
    assert "co2_kg_estimate" in data
    assert "most_visited_country" in data
    assert "most_visited_country_code" in data
    assert "longest_trip_title" in data
    assert "longest_trip_days" in data
    assert isinstance(data["countries_visited"], int)
    assert isinstance(data["total_distance_km"], float)


@pytest.mark.asyncio
async def test_timeline_returns_list(auth_client: AsyncClient):
    res = await auth_client.get(TIMELINE_URL)
    assert res.status_code == 200
    assert isinstance(res.json(), list)
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/zach/Atlas/backend && python3 -m pytest tests/test_stats.py -v
```
Expected: FAILED — `test_stats_requires_auth` and `test_timeline_requires_auth` will 404 (routes don't exist).

- [ ] **Step 3: Create `backend/app/routers/stats.py`**

```python
import logging
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/stats", tags=["stats"])

# kg CO2 per km (economy class, DEFRA short-haul average)
CO2_PER_KM = 0.255


class StatsResponse(BaseModel):
    countries_visited: int
    trips_count: int
    nights_away: int
    total_distance_km: float
    co2_kg_estimate: float
    most_visited_country: str | None
    most_visited_country_code: str | None
    longest_trip_title: str | None
    longest_trip_days: int | None


class TimelineTrip(BaseModel):
    id: str
    title: str
    status: str
    start_date: str | None
    end_date: str | None
    destination_count: int


@router.get("", response_model=StatsResponse)
async def get_stats(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> StatsResponse:
    """Aggregate travel statistics for the authenticated user."""
    agg = await db.execute(
        text("""
            SELECT
                (SELECT COUNT(*) FROM country_visits WHERE user_id = :uid)::int            AS countries_visited,
                (SELECT COUNT(*) FROM trips WHERE user_id = :uid AND status = 'past')::int AS trips_count,
                (SELECT COALESCE(SUM(nights), 0) FROM destinations
                 WHERE user_id = :uid AND nights IS NOT NULL)::int                         AS nights_away,
                (SELECT COALESCE(SUM(distance_km), 0) FROM transport_legs
                 WHERE user_id = :uid AND type = 'flight'
                   AND distance_km IS NOT NULL)::numeric                                   AS total_distance_km
        """),
        {"uid": user_id},
    )
    row = agg.mappings().one()

    most = await db.execute(
        text("""
            SELECT country_name, country_code
            FROM country_visits
            WHERE user_id = :uid
            ORDER BY visit_count DESC
            LIMIT 1
        """),
        {"uid": user_id},
    )
    most_row = most.mappings().first()

    longest = await db.execute(
        text("""
            SELECT title, (end_date - start_date) AS days
            FROM trips
            WHERE user_id = :uid
              AND start_date IS NOT NULL
              AND end_date IS NOT NULL
              AND end_date > start_date
            ORDER BY days DESC
            LIMIT 1
        """),
        {"uid": user_id},
    )
    longest_row = longest.mappings().first()

    total_km = float(row["total_distance_km"])
    return StatsResponse(
        countries_visited=row["countries_visited"],
        trips_count=row["trips_count"],
        nights_away=row["nights_away"],
        total_distance_km=total_km,
        co2_kg_estimate=round(total_km * CO2_PER_KM, 1),
        most_visited_country=most_row["country_name"] if most_row else None,
        most_visited_country_code=most_row["country_code"] if most_row else None,
        longest_trip_title=longest_row["title"] if longest_row else None,
        longest_trip_days=int(longest_row["days"]) if longest_row else None,
    )


@router.get("/timeline", response_model=list[TimelineTrip])
async def get_timeline(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> list[TimelineTrip]:
    """Past trips ordered by start_date for the horizontal timeline view."""
    result = await db.execute(
        text("""
            SELECT
                t.id::text,
                t.title,
                t.status,
                t.start_date::text,
                t.end_date::text,
                COUNT(d.id)::int AS destination_count
            FROM trips t
            LEFT JOIN destinations d ON d.trip_id = t.id
            WHERE t.user_id = :uid
              AND t.status IN ('past', 'active')
            GROUP BY t.id
            ORDER BY t.start_date ASC NULLS LAST, t.created_at ASC
        """),
        {"uid": user_id},
    )
    rows = result.mappings().all()
    return [TimelineTrip(**r) for r in rows]
```

- [ ] **Step 4: Register the router in `backend/app/main.py`**

Add after the existing imports:
```python
from app.routers.stats import router as stats_router
```

Add after `app.include_router(discover_router, prefix="/api/v1")`:
```python
app.include_router(stats_router, prefix="/api/v1")
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd /home/zach/Atlas/backend && python3 -m pytest tests/test_stats.py -v
```
Expected: 4 PASSED (or ERRORS only from DB connectivity — all test logic correct).

- [ ] **Step 6: Run full suite**

```bash
cd /home/zach/Atlas/backend && python3 -m pytest --tb=short -q
```
Expected: same pass count as before, no regressions.

- [ ] **Step 7: Commit**

```bash
cd /home/zach/Atlas && git add backend/app/routers/stats.py backend/app/main.py backend/tests/test_stats.py
git commit -m "feat(stats): add GET /stats and GET /stats/timeline endpoints"
```

---

### Task 2: Stats frontend page

**Files:**
- Create: `frontend/src/hooks/useStats.ts`
- Modify: `frontend/src/types/index.ts`
- Modify: `frontend/src/app/(app)/stats/page.tsx`

- [ ] **Step 1: Add types to `frontend/src/types/index.ts`**

Append after `DestinationBriefResponse`:

```typescript
export interface StatsResponse {
  countries_visited: number;
  trips_count: number;
  nights_away: number;
  total_distance_km: number;
  co2_kg_estimate: number;
  most_visited_country: string | null;
  most_visited_country_code: string | null;
  longest_trip_title: string | null;
  longest_trip_days: number | null;
}

export interface TimelineTrip {
  id: string;
  title: string;
  status: string;
  start_date: string | null;
  end_date: string | null;
  destination_count: number;
}
```

- [ ] **Step 2: Create `frontend/src/hooks/useStats.ts`**

```typescript
import { useQuery } from "@tanstack/react-query";
import { useAuth } from "@clerk/nextjs";
import { apiGet } from "@/lib/api";
import type { StatsResponse, TimelineTrip } from "@/types";

export function useStats() {
  const { getToken } = useAuth();
  return useQuery<StatsResponse>({
    queryKey: ["stats"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<StatsResponse>("/stats", token);
    },
    staleTime: 5 * 60 * 1000,
  });
}

export function useStatsTimeline() {
  const { getToken } = useAuth();
  return useQuery<TimelineTrip[]>({
    queryKey: ["stats", "timeline"],
    queryFn: async () => {
      const token = await getToken();
      if (!token) throw new Error("Not authenticated");
      return apiGet<TimelineTrip[]>("/stats/timeline", token);
    },
    staleTime: 5 * 60 * 1000,
  });
}
```

- [ ] **Step 3: Verify TypeScript compiles**

```bash
cd /home/zach/Atlas/frontend && npx tsc --noEmit 2>&1 | grep -v Lightbox | head -20
```
Expected: no errors.

- [ ] **Step 4: Replace `frontend/src/app/(app)/stats/page.tsx`**

```typescript
"use client";

import { Globe, Plane, Moon, MapPin, TreePine, Clock } from "lucide-react";
import { useStats, useStatsTimeline } from "@/hooks/useStats";
import type { TimelineTrip } from "@/types";

function StatCard({
  icon: Icon,
  label,
  value,
  sub,
}: {
  icon: React.ElementType;
  label: string;
  value: string | number;
  sub?: string;
}) {
  return (
    <div className="rounded-lg border border-atlas-border bg-atlas-surface px-5 py-4 flex items-start gap-4">
      <div className="flex h-9 w-9 items-center justify-center rounded bg-atlas-accent/10 text-atlas-accent shrink-0 mt-0.5">
        <Icon size={16} strokeWidth={1.5} />
      </div>
      <div>
        <p className="text-xs text-atlas-muted uppercase tracking-widest">{label}</p>
        <p className="text-2xl font-semibold text-atlas-text font-mono mt-0.5">{value}</p>
        {sub && <p className="text-xs text-atlas-muted mt-0.5">{sub}</p>}
      </div>
    </div>
  );
}

function TimelineCard({ trip }: { trip: TimelineTrip }) {
  const year = trip.start_date ? trip.start_date.slice(0, 4) : "—";
  return (
    <a
      href={`/trips/${trip.id}`}
      className="flex-shrink-0 w-44 rounded-lg border border-atlas-border bg-atlas-surface p-4 flex flex-col gap-2 hover:border-atlas-accent/40 transition-colors"
    >
      <span className="text-xs font-mono text-atlas-accent">{year}</span>
      <p className="text-sm font-medium text-atlas-text leading-snug line-clamp-2">{trip.title}</p>
      <div className="flex items-center gap-1.5 text-xs text-atlas-muted mt-auto">
        <MapPin size={10} />
        <span>{trip.destination_count} {trip.destination_count === 1 ? "stop" : "stops"}</span>
      </div>
    </a>
  );
}

export default function StatsPage() {
  const { data: stats, isLoading: statsLoading } = useStats();
  const { data: timeline = [], isLoading: timelineLoading } = useStatsTimeline();

  const fmtKm = (km: number) =>
    km >= 1000 ? `${(km / 1000).toFixed(1)}k km` : `${Math.round(km)} km`;

  return (
    <div className="h-full overflow-y-auto p-6">
      <div className="max-w-4xl mx-auto">
        <div className="mb-8">
          <h1 className="text-xl font-semibold text-atlas-text font-display mb-1">Stats</h1>
          <p className="text-sm text-atlas-muted">Your travel at a glance.</p>
        </div>

        {/* Stat cards */}
        {statsLoading && (
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-10">
            {Array.from({ length: 6 }).map((_, i) => (
              <div key={i} className="rounded-lg border border-atlas-border bg-atlas-surface h-24 animate-pulse" />
            ))}
          </div>
        )}

        {stats && (
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 mb-10">
            <StatCard icon={Globe} label="Countries" value={stats.countries_visited} />
            <StatCard icon={Plane} label="Trips" value={stats.trips_count} />
            <StatCard icon={Moon} label="Nights Away" value={stats.nights_away} />
            <StatCard
              icon={Plane}
              label="Distance Flown"
              value={fmtKm(stats.total_distance_km)}
            />
            <StatCard
              icon={TreePine}
              label="CO₂ Estimate"
              value={`${(stats.co2_kg_estimate / 1000).toFixed(1)}t`}
              sub="Economy class, DEFRA avg"
            />
            {stats.longest_trip_title && (
              <StatCard
                icon={Clock}
                label="Longest Trip"
                value={`${stats.longest_trip_days}d`}
                sub={stats.longest_trip_title}
              />
            )}
            {stats.most_visited_country && (
              <StatCard
                icon={MapPin}
                label="Most Visited"
                value={stats.most_visited_country}
                sub={stats.most_visited_country_code ?? undefined}
              />
            )}
          </div>
        )}

        {/* Timeline */}
        <div>
          <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest mb-4">
            Trip Timeline
          </h2>

          {timelineLoading && (
            <div className="flex gap-3 overflow-x-auto pb-2">
              {Array.from({ length: 5 }).map((_, i) => (
                <div key={i} className="flex-shrink-0 w-44 h-28 rounded-lg border border-atlas-border bg-atlas-surface animate-pulse" />
              ))}
            </div>
          )}

          {!timelineLoading && timeline.length === 0 && (
            <p className="text-atlas-muted text-sm py-6 text-center border border-dashed border-atlas-border rounded-lg">
              No past trips yet. Log a trip with status &ldquo;past&rdquo; to see it here.
            </p>
          )}

          {timeline.length > 0 && (
            <div className="flex gap-3 overflow-x-auto pb-2 scrollbar-thin scrollbar-track-atlas-bg scrollbar-thumb-atlas-border">
              {timeline.map((trip) => (
                <TimelineCard key={trip.id} trip={trip} />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 5: Verify TypeScript compiles**

```bash
cd /home/zach/Atlas/frontend && npx tsc --noEmit 2>&1 | grep -v Lightbox | head -20
```
Expected: no errors.

- [ ] **Step 6: Commit**

```bash
cd /home/zach/Atlas && git add frontend/src/types/index.ts frontend/src/hooks/useStats.ts frontend/src/app/\(app\)/stats/page.tsx
git commit -m "feat(stats): add stats page with stat cards and horizontal timeline"
```

---

### Task 3: Data export

**Files:**
- Create: `backend/app/routers/export.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_export.py`
- Modify: `frontend/src/app/(app)/settings/page.tsx`

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_export.py`:

```python
import pytest
from httpx import AsyncClient

JSON_URL = "/api/v1/export/json"
CSV_URL = "/api/v1/export/csv"


@pytest.mark.asyncio
async def test_export_json_requires_auth(client: AsyncClient):
    res = await client.get(JSON_URL)
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_export_csv_requires_auth(client: AsyncClient):
    res = await client.get(CSV_URL)
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_export_json_content_type(auth_client: AsyncClient):
    res = await auth_client.get(JSON_URL)
    assert res.status_code == 200
    assert "application/json" in res.headers["content-type"]
    assert res.headers.get("content-disposition", "").startswith("attachment")
    data = res.json()
    assert "trips" in data
    assert "exported_at" in data


@pytest.mark.asyncio
async def test_export_csv_content_type(auth_client: AsyncClient):
    res = await auth_client.get(CSV_URL)
    assert res.status_code == 200
    assert "text/csv" in res.headers["content-type"]
    assert res.headers.get("content-disposition", "").startswith("attachment")
    # CSV must have a header row
    first_line = res.text.split("\n")[0]
    assert "city" in first_line
    assert "country_name" in first_line
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/zach/Atlas/backend && python3 -m pytest tests/test_export.py -v
```
Expected: FAILED — routes don't exist.

- [ ] **Step 3: Create `backend/app/routers/export.py`**

```python
import csv
import io
import json
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from fastapi.responses import Response, StreamingResponse
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import CurrentUser
from app.database import get_db
from app.models.destination import Destination
from app.models.trip import Trip

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/export", tags=["export"])


@router.get("/json")
async def export_json(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> Response:
    """Export all user data as a JSON file."""
    result = await db.execute(
        text("""
            SELECT
                t.id::text           AS id,
                t.title,
                t.description,
                t.status,
                t.start_date::text,
                t.end_date::text,
                t.tags,
                t.visibility,
                t.created_at::text,
                COALESCE(
                    json_agg(
                        json_build_object(
                            'city', d.city,
                            'country_code', d.country_code,
                            'country_name', d.country_name,
                            'arrival_date', d.arrival_date::text,
                            'departure_date', d.departure_date::text,
                            'nights', d.nights,
                            'rating', d.rating,
                            'notes', d.notes
                        ) ORDER BY d.order_index, d.arrival_date
                    ) FILTER (WHERE d.id IS NOT NULL),
                    '[]'
                ) AS destinations
            FROM trips t
            LEFT JOIN destinations d ON d.trip_id = t.id
            WHERE t.user_id = :uid
            GROUP BY t.id
            ORDER BY t.start_date ASC NULLS LAST
        """),
        {"uid": user_id},
    )
    rows = result.mappings().all()
    payload = {
        "exported_at": datetime.now(timezone.utc).isoformat(),
        "user_id": user_id,
        "trips": [dict(r) for r in rows],
    }
    body = json.dumps(payload, default=str, indent=2)
    return Response(
        content=body,
        media_type="application/json",
        headers={"Content-Disposition": 'attachment; filename="atlas-export.json"'},
    )


@router.get("/csv")
async def export_csv(
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    """Export all destinations as a CSV file."""
    result = await db.execute(
        select(Destination)
        .join(Trip, Trip.id == Destination.trip_id)
        .where(Destination.user_id == user_id)
        .order_by(Trip.start_date.asc().nullslast(), Destination.order_index)
    )
    dests = result.scalars().all()

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "trip_id", "city", "country_code", "country_name",
        "arrival_date", "departure_date", "nights", "rating", "notes",
    ])
    for d in dests:
        writer.writerow([
            str(d.trip_id), d.city, d.country_code, d.country_name,
            d.arrival_date, d.departure_date, d.nights, d.rating, d.notes,
        ])

    output.seek(0)
    return StreamingResponse(
        iter([output.getvalue()]),
        media_type="text/csv",
        headers={"Content-Disposition": 'attachment; filename="atlas-destinations.csv"'},
    )
```

- [ ] **Step 4: Register the router in `backend/app/main.py`**

Add import:
```python
from app.routers.export import router as export_router
```

Add after stats router:
```python
app.include_router(export_router, prefix="/api/v1")
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd /home/zach/Atlas/backend && python3 -m pytest tests/test_export.py -v
```
Expected: 4 PASSED (or ERRORS from DB — all logic correct).

- [ ] **Step 6: Add download buttons to `frontend/src/app/(app)/settings/page.tsx`**

Read the existing settings page first, then append an "Export Data" section. The API base is `process.env.NEXT_PUBLIC_API_BASE`:

```typescript
// Add to the settings page — read the existing file first to find the right insertion point.
// Add an "Export Data" card section with two buttons.

// At top of file, add useAuth import if not already present:
import { useAuth } from "@clerk/nextjs";

// In the component, add:
const { getToken } = useAuth();

async function handleExport(format: "json" | "csv") {
  const token = await getToken();
  if (!token) return;
  const base = process.env.NEXT_PUBLIC_API_BASE ?? "http://localhost:8000";
  const res = await fetch(`${base}/api/v1/export/${format}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
  if (!res.ok) return;
  const blob = await res.blob();
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = format === "json" ? "atlas-export.json" : "atlas-destinations.csv";
  a.click();
  URL.revokeObjectURL(url);
}
```

Add to the JSX (inside the page's container):
```tsx
{/* Export Data */}
<div className="rounded-lg border border-atlas-border bg-atlas-surface p-5">
  <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest mb-4">
    Export Data
  </h2>
  <div className="flex gap-3">
    <button
      onClick={() => handleExport("json")}
      className="px-4 py-2 text-xs rounded border border-atlas-border text-atlas-text hover:border-atlas-accent/40 transition-colors"
    >
      Download JSON
    </button>
    <button
      onClick={() => handleExport("csv")}
      className="px-4 py-2 text-xs rounded border border-atlas-border text-atlas-text hover:border-atlas-accent/40 transition-colors"
    >
      Download CSV
    </button>
  </div>
</div>
```

- [ ] **Step 7: Verify TypeScript compiles**

```bash
cd /home/zach/Atlas/frontend && npx tsc --noEmit 2>&1 | grep -v Lightbox | head -20
```
Expected: no errors.

- [ ] **Step 8: Commit**

```bash
cd /home/zach/Atlas && git add backend/app/routers/export.py backend/app/main.py backend/tests/test_export.py frontend/src/app/\(app\)/settings/page.tsx
git commit -m "feat(export): add JSON + CSV data export endpoints and download buttons"
```

---

### Task 4: Shared trip links

**Files:**
- Modify: `backend/app/routers/trips.py`
- Create: `backend/app/routers/shared.py`
- Modify: `backend/app/main.py`
- Create: `backend/tests/test_share.py`
- Modify: `frontend/src/types/index.ts`
- Modify: `frontend/src/app/(app)/trips/[id]/page.tsx`

- [ ] **Step 1: Write the failing tests**

Create `backend/tests/test_share.py`:

```python
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from httpx import AsyncClient
from tests.conftest import TEST_USER_ID

SHARE_URL = "/api/v1/trips/{}/share"
PUBLIC_URL = "/api/v1/shared/{}"


@pytest.mark.asyncio
async def test_share_requires_auth(client: AsyncClient, db_session, seed_test_users):
    from app.models.trip import Trip
    trip = Trip(user_id=TEST_USER_ID, title="Test Trip", status="past", visibility="private")
    db_session.add(trip)
    await db_session.flush()
    res = await client.post(SHARE_URL.format(trip.id))
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_share_trip_returns_token(auth_client: AsyncClient, db_session):
    from app.models.trip import Trip
    trip = Trip(user_id=TEST_USER_ID, title="Tokyo Adventure", status="past", visibility="private")
    db_session.add(trip)
    await db_session.flush()

    with patch("app.routers.trips.get_redis") as mock_get_redis:
        mock_redis = AsyncMock()
        mock_get_redis.return_value = mock_redis
        res = await auth_client.post(SHARE_URL.format(trip.id))

    assert res.status_code == 200
    data = res.json()
    assert "token" in data
    assert "share_url" in data
    assert "expires_at" in data
    assert len(data["token"]) >= 32


@pytest.mark.asyncio
async def test_share_wrong_user_returns_404(auth_client: AsyncClient, db_session, seed_test_users):
    from app.models.trip import Trip
    from tests.conftest import OTHER_USER_ID
    trip = Trip(user_id=OTHER_USER_ID, title="Other Trip", status="past", visibility="public")
    db_session.add(trip)
    await db_session.flush()
    res = await auth_client.post(SHARE_URL.format(trip.id))
    assert res.status_code == 404


@pytest.mark.asyncio
async def test_get_shared_trip_invalid_token(client: AsyncClient):
    with patch("app.routers.shared.get_redis") as mock_get_redis:
        mock_redis = AsyncMock()
        mock_redis.get = AsyncMock(return_value=None)
        mock_get_redis.return_value = mock_redis
        res = await client.get(PUBLIC_URL.format("invalidtoken"))
    assert res.status_code == 404
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /home/zach/Atlas/backend && python3 -m pytest tests/test_share.py -v
```
Expected: FAILED — routes don't exist.

- [ ] **Step 3: Add `POST /trips/{trip_id}/share` to `backend/app/routers/trips.py`**

Add imports at the top of `trips.py`:
```python
import secrets
from datetime import datetime, timezone, timedelta
import json as json_lib
from pydantic import BaseModel as _BaseModel
from app.services.map_cache import get_redis
```

Add a schema class and the new route at the end of `trips.py`:

```python
class ShareResponse(_BaseModel):
    token: str
    share_url: str
    expires_at: str


SHARE_TTL_DAYS = 7


@router.post("/{trip_id}/share", response_model=ShareResponse)
async def share_trip(
    trip_id: uuid.UUID,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> ShareResponse:
    """Generate a time-limited share token for a trip."""
    result = await db.execute(select(Trip).where(Trip.id == trip_id, Trip.user_id == user_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")

    token = secrets.token_urlsafe(32)
    expires_at = datetime.now(timezone.utc) + timedelta(days=SHARE_TTL_DAYS)
    payload = json_lib.dumps({"trip_id": str(trip_id), "user_id": user_id})
    redis = get_redis()
    await redis.setex(f"share:{token}", SHARE_TTL_DAYS * 86400, payload)

    return ShareResponse(
        token=token,
        share_url=f"/shared/{token}",
        expires_at=expires_at.isoformat(),
    )
```

- [ ] **Step 4: Create `backend/app/routers/shared.py`**

```python
import json
import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.destination import Destination
from app.models.trip import Trip
from app.schemas.trip import TripRead
from app.services.map_cache import get_redis

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/shared", tags=["shared"])


@router.get("/{token}", response_model=TripRead)
async def get_shared_trip(
    token: str,
    db: AsyncSession = Depends(get_db),
) -> Trip:
    """Public endpoint — no auth required. Returns a trip via share token."""
    redis = get_redis()
    raw = await redis.get(f"share:{token}")
    if raw is None:
        raise HTTPException(status_code=404, detail="Share link not found or expired")

    data = json.loads(raw)
    trip_id = uuid.UUID(data["trip_id"])

    result = await db.execute(select(Trip).where(Trip.id == trip_id))
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip
```

- [ ] **Step 5: Register routers in `backend/app/main.py`**

Add imports:
```python
from app.routers.shared import router as shared_router
```

Add after export router:
```python
app.include_router(shared_router, prefix="/api/v1")
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd /home/zach/Atlas/backend && python3 -m pytest tests/test_share.py -v
```
Expected: 4 PASSED (or ERRORS from DB — all logic correct).

- [ ] **Step 7: Add `ShareResponse` type and share button to frontend**

In `frontend/src/types/index.ts`, append:

```typescript
export interface ShareResponse {
  token: string;
  share_url: string;
  expires_at: string;
}
```

In `frontend/src/app/(app)/trips/[id]/page.tsx`, read the file first, then add a share button. Find the existing action buttons area (near the edit controls) and add:

```typescript
// Add to imports:
import { apiPost } from "@/lib/api";
import type { ShareResponse } from "@/types";

// Add state inside component:
const [shareUrl, setShareUrl] = useState<string | null>(null);
const [sharing, setSharing] = useState(false);

// Add handler inside component:
async function handleShare() {
  setSharing(true);
  try {
    const token = await getToken();
    if (!token) return;
    const res = await apiPost<ShareResponse>(`/trips/${id}/share`, token, {});
    const fullUrl = `${window.location.origin}${res.share_url}`;
    await navigator.clipboard.writeText(fullUrl);
    setShareUrl(fullUrl);
  } finally {
    setSharing(false);
  }
}

// Add button in JSX near the trip title/actions area:
<button
  onClick={handleShare}
  disabled={sharing}
  className="flex items-center gap-1.5 px-3 py-1.5 text-xs rounded border border-atlas-border text-atlas-muted hover:text-atlas-text hover:border-atlas-accent/40 transition-colors disabled:opacity-50"
>
  <Share2 size={12} />
  {sharing ? "Copying…" : shareUrl ? "Copied!" : "Share"}
</button>
```

Add `Share2` to the lucide-react import.

- [ ] **Step 8: Verify TypeScript compiles**

```bash
cd /home/zach/Atlas/frontend && npx tsc --noEmit 2>&1 | grep -v Lightbox | head -20
```
Expected: no errors.

- [ ] **Step 9: Commit**

```bash
cd /home/zach/Atlas && git add backend/app/routers/trips.py backend/app/routers/shared.py backend/app/main.py backend/tests/test_share.py frontend/src/types/index.ts frontend/src/app/\(app\)/trips/
git commit -m "feat(share): add trip share token generation and public shared view"
```

---

### Task 5: Public profile

**Files:**
- Create: `backend/migrations/versions/008_user_username.py`
- Modify: `backend/app/models/user.py`
- Modify: `backend/app/schemas/user.py` (read first)
- Create: `backend/app/routers/profile.py`
- Modify: `backend/app/main.py`
- Modify: `frontend/src/types/index.ts`
- Create: `frontend/src/app/u/[username]/page.tsx`
- Modify: `frontend/src/app/(app)/settings/page.tsx`

- [ ] **Step 1: Create migration `backend/migrations/versions/008_user_username.py`**

```python
"""add username to users

Revision ID: 008
Revises: 007
Create Date: 2026-04-12
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision = "008"
down_revision = "007"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("username", sa.String(50), nullable=True))
    op.create_unique_constraint("uq_users_username", "users", ["username"])


def downgrade() -> None:
    op.drop_constraint("uq_users_username", "users", type_="unique")
    op.drop_column("users", "username")
```

- [ ] **Step 2: Add `username` to `backend/app/models/user.py`**

Full replacement of the file:

```python
from datetime import datetime
from typing import Any
from sqlalchemy import String, DateTime, func, text
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
    username: Mapped[str | None] = mapped_column(String(50), unique=True, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    preferences: Mapped[dict[str, Any]] = mapped_column(JSONB, server_default=text("'{}'"))
```

- [ ] **Step 3: Read `backend/app/schemas/user.py` and add `username` + `UserUpdate`**

Read the file first:
```bash
cat /home/zach/Atlas/backend/app/schemas/user.py
```

Then add `username: str | None = None` to `UserRead` (if it exists) and create a `UserUpdate` schema that allows updating only `username` and `display_name`:

```python
class UserUpdate(BaseModel):
    username: str | None = None
    display_name: str | None = None

    @model_validator(mode="after")
    def validate_username(self) -> "UserUpdate":
        if self.username is not None:
            if len(self.username) < 3:
                raise ValueError("username must be at least 3 characters")
            if not self.username.replace("_", "").replace("-", "").isalnum():
                raise ValueError("username may only contain letters, numbers, hyphens, and underscores")
        return self
```

Also add `username: str | None` to `UserRead`.

- [ ] **Step 4: Add `PATCH /users/me` to the users router**

Read `backend/app/routers/users.py` first, then add:

```python
@router.patch("/users/me", response_model=UserRead)
async def update_me(
    body: UserUpdate,
    user_id: CurrentUser,
    db: AsyncSession = Depends(get_db),
) -> User:
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(user, k, v)
    try:
        await db.flush()
    except Exception:
        raise HTTPException(status_code=409, detail="Username already taken")
    await db.refresh(user)
    return user
```

- [ ] **Step 5: Create `backend/app/routers/profile.py`**

```python
import logging
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.trip import Trip
from app.models.user import User
from app.schemas.trip import TripRead

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/profile", tags=["profile"])


class PublicProfileResponse(BaseModel):
    username: str
    display_name: str | None
    avatar_url: str | None
    countries_visited: int
    trips: list[TripRead]


@router.get("/{username}", response_model=PublicProfileResponse)
async def get_public_profile(
    username: str,
    db: AsyncSession = Depends(get_db),
) -> PublicProfileResponse:
    """Public endpoint — no auth required."""
    result = await db.execute(select(User).where(User.username == username))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="Profile not found")

    trips_result = await db.execute(
        select(Trip)
        .where(Trip.user_id == user.id, Trip.visibility == "public")
        .order_by(Trip.start_date.desc().nullslast())
    )
    trips = list(trips_result.scalars().all())

    cv_result = await db.execute(
        text("SELECT COUNT(*) FROM country_visits WHERE user_id = :uid"),
        {"uid": user.id},
    )
    countries_visited = cv_result.scalar_one() or 0

    return PublicProfileResponse(
        username=user.username or username,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
        countries_visited=int(countries_visited),
        trips=trips,
    )
```

- [ ] **Step 6: Register in `backend/app/main.py`**

Add import:
```python
from app.routers.profile import router as profile_router
```

Add after shared router:
```python
app.include_router(profile_router, prefix="/api/v1")
```

- [ ] **Step 7: Add types to `frontend/src/types/index.ts`**

Append:

```typescript
export interface PublicProfile {
  username: string;
  display_name: string | null;
  avatar_url: string | null;
  countries_visited: number;
  trips: Trip[];
}
```

- [ ] **Step 8: Create `frontend/src/app/u/[username]/page.tsx`**

Note: this lives outside the `(app)` authenticated layout — it's a public page accessible without login.

```typescript
import type { Metadata } from "next";

const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "http://localhost:8000";

interface Props {
  params: { username: string };
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  return { title: `@${params.username} — Atlas` };
}

async function getProfile(username: string) {
  const res = await fetch(`${API_BASE}/api/v1/profile/${username}`, {
    next: { revalidate: 60 },
  });
  if (!res.ok) return null;
  return res.json();
}

export default async function PublicProfilePage({ params }: Props) {
  const profile = await getProfile(params.username);

  if (!profile) {
    return (
      <div className="min-h-screen bg-atlas-bg flex items-center justify-center">
        <div className="text-center">
          <p className="text-atlas-muted text-sm">Profile not found.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-atlas-bg p-6">
      <div className="max-w-2xl mx-auto">
        <div className="flex items-center gap-4 mb-8">
          {profile.avatar_url && (
            <img
              src={profile.avatar_url}
              alt={profile.display_name ?? profile.username}
              className="h-14 w-14 rounded-full border border-atlas-border"
            />
          )}
          <div>
            <h1 className="text-xl font-semibold text-atlas-text font-display">
              {profile.display_name ?? profile.username}
            </h1>
            <p className="text-sm text-atlas-muted">@{profile.username}</p>
            <p className="text-xs text-atlas-muted mt-0.5">
              {profile.countries_visited} {profile.countries_visited === 1 ? "country" : "countries"} visited
            </p>
          </div>
        </div>

        <div className="flex flex-col gap-3">
          {profile.trips.length === 0 && (
            <p className="text-atlas-muted text-sm py-6 text-center border border-dashed border-atlas-border rounded-lg">
              No public trips yet.
            </p>
          )}
          {profile.trips.map((trip: { id: string; title: string; status: string; start_date: string | null }) => (
            <div
              key={trip.id}
              className="rounded-lg border border-atlas-border bg-atlas-surface px-4 py-3"
            >
              <p className="text-sm font-medium text-atlas-text">{trip.title}</p>
              <p className="text-xs text-atlas-muted capitalize mt-0.5">
                {trip.status}{trip.start_date ? ` · ${trip.start_date.slice(0, 4)}` : ""}
              </p>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 9: Add username field to settings page**

Read `frontend/src/app/(app)/settings/page.tsx` first. Find the existing form fields (or the main content area), and add a "Username" section:

```typescript
// State additions:
const [username, setUsername] = useState("");
const [usernameError, setUsernameError] = useState<string | null>(null);
const [usernameSaving, setUsernameSaving] = useState(false);

// Handler:
async function handleSaveUsername() {
  if (!username.trim()) return;
  setUsernameError(null);
  setUsernameSaving(true);
  try {
    const token = await getToken();
    if (!token) return;
    await apiPatch("/users/me", token, { username: username.trim() });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : "Failed to save";
    setUsernameError(msg.includes("409") ? "Username already taken" : "Failed to save");
  } finally {
    setUsernameSaving(false);
  }
}

// JSX section:
<div className="rounded-lg border border-atlas-border bg-atlas-surface p-5">
  <h2 className="text-sm font-semibold text-atlas-text uppercase tracking-widest mb-4">
    Public Profile
  </h2>
  <div className="flex gap-3">
    <input
      value={username}
      onChange={(e) => setUsername(e.target.value)}
      placeholder="your-username"
      className="flex-1 rounded border border-atlas-border bg-atlas-bg px-3 py-2 text-sm text-atlas-text placeholder:text-atlas-muted focus:outline-none focus:border-atlas-accent font-mono"
    />
    <button
      onClick={handleSaveUsername}
      disabled={!username.trim() || usernameSaving}
      className="px-4 py-2 text-xs rounded bg-atlas-accent text-atlas-bg font-medium hover:bg-atlas-accent/80 transition-colors disabled:opacity-50"
    >
      {usernameSaving ? "Saving…" : "Save"}
    </button>
  </div>
  {usernameError && <p className="text-xs text-red-400 mt-2">{usernameError}</p>}
  {username && !usernameError && !usernameSaving && (
    <p className="text-xs text-atlas-muted mt-2">
      Your profile will be at <span className="font-mono text-atlas-accent">/u/{username}</span>
    </p>
  )}
</div>
```

Also add `apiPatch` to the `@/lib/api` import.

- [ ] **Step 10: Verify TypeScript compiles**

```bash
cd /home/zach/Atlas/frontend && npx tsc --noEmit 2>&1 | grep -v Lightbox | head -20
```
Expected: no errors.

- [ ] **Step 11: Commit**

```bash
cd /home/zach/Atlas && git add backend/migrations/versions/008_user_username.py backend/app/models/user.py backend/app/schemas/user.py backend/app/routers/users.py backend/app/routers/profile.py backend/app/main.py frontend/src/types/index.ts frontend/src/app/u/ frontend/src/app/\(app\)/settings/page.tsx
git commit -m "feat(profile): add username, public profile page, and PATCH /users/me"
```

---

## Completion Checklist

- [ ] `GET /stats` returns all 9 stat fields with correct types
- [ ] `GET /stats/timeline` returns past + active trips ordered by start_date
- [ ] `GET /export/json` returns `Content-Disposition: attachment` with trips array
- [ ] `GET /export/csv` returns CSV with header row including `city`, `country_name`
- [ ] `POST /trips/{id}/share` generates a token, stores in Redis, returns share_url
- [ ] `GET /shared/{token}` returns trip without auth for valid tokens, 404 for expired/missing
- [ ] `GET /profile/{username}` returns public trips + country count without auth
- [ ] `PATCH /users/me` updates username with uniqueness enforcement (409 on conflict)
- [ ] Stats page: 6+ stat cards render, timeline is horizontally scrollable
- [ ] Settings page: Export Data section with JSON + CSV buttons; Username section
- [ ] `/u/[username]` page: renders profile + public trips without auth redirect
- [ ] Backend tests pass: `python3 -m pytest tests/test_stats.py tests/test_export.py tests/test_share.py -v`
- [ ] TypeScript compiles: `cd frontend && npx tsc --noEmit`
