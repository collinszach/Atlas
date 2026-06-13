# Atlas — Build Status & Roadmap

_Last updated: 2026-06-13_

## TL;DR

Three surfaces exist: a **FastAPI backend** (most complete), a **Next.js web frontend**
(feature-rich), and a **SwiftUI iOS app** (newest, now building & running). As of this
update the **iOS app compiles, installs, launches, and passes its unit tests** on the
simulator — the blockers were a non-existent Clerk SDK version, a wrong Clerk module/API,
and a missing `CFBundleExecutable` that blocked installation.

---

## Current State by Surface

### Backend (FastAPI) — ~80% of spec
**Done:** models (trip, destination, transport, accommodation, photo, bucket_list, user),
routers for all of the above + map/discover/stats, services (ai, storage, open_meteo,
map_cache), Alembic migrations 001–007, broad pytest suite.
**Gaps / unverified:**
- Not verified to boot against a live Postgres+PostGIS+Redis+MinIO stack (no end-to-end run done here).
- `country_visits` materialized-view refresh strategy on destination write — confirm trigger exists.
- Photo upload → MinIO streaming + async thumbnail/EXIF pipeline — confirm background task wiring.
- Clerk JWT verification middleware — confirm it validates against the same Clerk instance the iOS `pk_test` key points to.
- Rate limiting, Redis caching of map layers (<500ms budget) — confirm implemented vs stubbed.

### Web frontend (Next.js) — ~75% of spec
**Done:** auth pages, app shell + sidebar, trips list/detail/new, destinations, photos
(grid/uploader/lightbox), map (WorldMap/CountryPanel/filter bar), plan, stats, discover,
settings; hooks for every domain; vitest tests.
**Gaps:** MapLibre globe polish (arcs animation, photo clusters, ghost bucket pins),
itinerary builder (dnd-kit) not present, accommodations UI, shared/public trip pages
(`/u/{username}`), AI itinerary assist UI.

### iOS (SwiftUI) — ~40% of spec, NOW RUNNING ✅
**Done:** xcodegen project, theme, tab shell (Map/Trips/Plan/Stats), Clerk password
sign-in, API client + Codable models, trips list+detail, map (city markers + flight arc
polylines via MapKit), plan (future trips + bucket list), stats (timeline).
**Gaps (biggest leverage):**
- **Photos** — no upload/grid/lightbox on iOS at all.
- **Transport & accommodation editing** — read-only; no create/edit forms.
- **Trip/destination create & edit** — list/detail are read-only.
- **Discover (AI)** — no recommendations/brief screens.
- **Sign-up, OAuth (Google/Apple), session refresh on 401** — only email+password sign-in.
- **Offline cache** — every screen hits the network; no local persistence.
- **Map** uses MapKit, not the spec's MapLibre/globe aesthetic (acceptable native tradeoff, but no choropleth country fills).

---

## Make-It-Work Punch List (near term)

1. **Verify the full backend stack boots** via `docker-compose up` and the iOS app can
   actually sign in + load `/trips`. The iOS `Config.apiBase` points at `192.168.1.12:8000`
   (the NUC) — confirm reachable from the simulator/device.
2. **iOS 401 handling:** `AuthManager.refreshToken()` exists but isn't invoked on API 401s.
   Wire the APIClient to call it and retry once.
3. **iOS create/edit flows** for trips → destinations → transport (the app is currently
   a read-only viewer of seed data).
4. **iOS photos** — the single highest-value missing feature for a travel archive.
5. **Backend confirm:** materialized view refresh, photo pipeline, Redis map cache.

---

## "Best Travel App on the Planet" — Differentiators

Tiered by impact. The moat is **data fidelity + intelligence**, not another photo grid.

### Tier 1 — Capture without friction (this is what makes people actually log trips)
- **Auto-import from email**: parse flight/hotel confirmations (Gmail/Apple Mail) into
  transport legs + accommodations automatically. Kills manual entry, the #1 churn driver.
- **Photo-driven trip reconstruction**: ingest a photo library, cluster by EXIF GPS + time,
  and *propose* a trip with destinations and dates pre-filled. User confirms instead of types.
- **Boarding-pass / Apple Wallet scan** → flight leg with route, distance, CO2 auto-computed.
- **Live location capture** (opt-in): passively builds the "present" layer the spec promises.

### Tier 2 — Intelligence (the Claude differentiator)
- **Personalized recommendations grounded in real history** (already specced) — make it
  conversational, not a form. "Where should I go in October that's like Lisbon but cheaper?"
- **Pre-trip briefing agent**: visa rules for the user's actual passport, weather vs their
  historical comfort, crowd calendars, neighborhood-level lodging advice.
- **Itinerary co-pilot**: drag-drop builder + AI that respects travel time between stops,
  opening hours, and the user's pace from past trips.
- **Post-trip auto-journal**: turn photos + timeline + notes into a shareable narrative.

### Tier 3 — The "explorer's logbook" identity
- **Stats that feel earned**: countries, % of world, distance (× to the moon), longest
  trip, CO2, passport-stamp visual, "you've spent N nights abroad."
- **Beautiful map as the home surface**: globe with choropleth visited countries, animated
  flight arcs, ghost bucket-list pins — the spec's vision, fully realized on web + a native
  MapKit analog on iOS.
- **Shareable public profile** `/u/{username}` and time-limited shared-trip links.
- **Compare with friends**: overlap maps, "you've both been to 12 countries, here's 1 neither has."

### Tier 4 — Platform polish
- Offline-first iOS (SwiftData/Core Data cache, sync on reconnect).
- Widgets & Live Activities (countdown to next trip, current-trip day).
- watchOS companion for in-trip logging.
- Export everything (JSON/CSV/GPX) — own-your-data is a trust differentiator.
- Multi-currency cost rollups with real FX at trip dates.

---

## Recommended Next 3 Moves

1. **Prove the seam end-to-end**: backend up on the NUC, iOS signs in, real trip loads.
   Until this works, nothing else matters.
2. **iOS: trip/destination/transport create+edit + photos** — turn the viewer into a tool.
3. **Email/photo auto-import (Tier 1)** — the single feature that separates Atlas from every
   other travel tracker. Build it on the backend with a Claude extraction pipeline.
