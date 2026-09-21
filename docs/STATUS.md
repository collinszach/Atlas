# Atlas — Build Status

_Last updated: 2026-09-20 · verified against the running stack and the code, not from memory._

## TL;DR

Atlas is a **flight radar + personal flight logbook**. Three surfaces: a **FastAPI backend**
(most complete, live on the NUC), a **SwiftUI iOS app** (Skywatch is the strongest part), and a
**Next.js web frontend** (feature-complete for flights, but deployed nowhere).

The Aug 18 pivot (`76cdb98`) dropped trips, destinations, accommodations and the bucket list.
It landed in the backend and web frontend; iOS was brought onto the post-pivot API on
2026-09-20 (`5534b01`).

---

## Current state by surface

### Backend (FastAPI) — live
Running on the NUC (`atlas-backend`, `atlas-db`, `atlas-redis`), `/health` green, 22 routes:
flights CRUD, photos, `/map/arcs`, `/stats`, `/transport/enrich-flight`, and the full Skywatch
surface (overhead, search, aircraft detail, airport boards, devices, alerts, preferences).
13 Alembic migrations, 23 pytest modules.

**Known gaps:**
- **MinIO is not running** — no `minio_data` volume has ever existed, so the backend logs
  `MinIO bucket init failed ... continuing without photo storage` at every boot and all photo
  upload/serve paths fail. Needs the host ports remapped to 9002/9003 (`:9000` is taken on that
  box) and `MINIO_PUBLIC_URL` updated to match.
- **Deployment is a hand-synced bind mount** of `/home/zach/atlas/backend` → `/app` with
  uvicorn `--reload`. There is no build or pull step, and `/home/zach` is an unrelated git repo,
  so merging a branch here does **not** update what's deployed.
- airplanes.live now gates its free API behind manual approval; a local dump1090 receiver via
  `DUMP1090_URL` avoids the gate and is preferred.

### iOS (SwiftUI) — on the post-pivot API
Tabs: **Map · Sky · Flights · Stats**.
- **Sky (Skywatch)** — the most developed surface: live ADS-B, radar view, alerts, bookmarks,
  aircraft/type pages, airport boards, ATC audio, Live Activity widget, AR sky view.
- **Flights** — logbook per `SPEC-flight-ui.md` D1: glass cards (airline pill, mono date,
  ORIG → DEST over a dashed great-circle, mono meta line), search, log-a-flight, detail with
  photos.
- **Map** — live aircraft via MapKit; arcs loaded but not yet drawn.
- **Stats** — bento grid over the six fields `/stats` returns.

**Known gaps:**
- Nothing past sign-in has been exercised against real data since the repoint — the Flights
  list, photo upload and delete are unverified end-to-end.
- Flight cards can't show aircraft type or registration (the mockup's `A320 · N834JB`) because
  `transport_legs` stores neither.
- Photo upload will fail until MinIO is up.
- No offline cache; every screen hits the network.
- 401s don't trigger `AuthManager.refreshToken()` and retry.

### Web frontend (Next.js) — built, not deployed
Flights list/detail/new, map (MapLibre globe + arcs), stats, settings, photo grid/uploader/
lightbox, landing page, hooks per domain, vitest tests.

**Known gaps:** `.env.local` still points `NEXT_PUBLIC_API_BASE` at `localhost:8000`; there is
no `atlas-frontend` container running and no Vercel project wired up. Live overhead tracking is
iOS-only and has not been ported here.

---

## Next moves

1. **Bring up MinIO** — the only thing standing between the photo feature and working.
2. **Walk the iOS Flights tab signed in** — first real end-to-end exercise since the repoint.
3. **Decide where the web app lives** (Vercel per CLAUDE.md, or a container on the NUC) and
   point it at the NUC backend.
4. **Document the backend deploy step**, or replace the bind mount with something reproducible.
5. Then Phase 5: data export (JSON/CSV) and public profile / shared logbook links.

---

## Doc map

- `CLAUDE.md` — project identity, stack, data model, API surface. Current.
- `PRODUCT.md` / `DESIGN.md` — product and visual system. **Both still carry travel-tracker
  framing** (countries visited, trip titles, bucket-list color tokens) and need a pass.
- `docs/SPEC-flight-ui.md` — the flight UI contract + mockup. Current; EPIC D partially built.
- `docs/SPEC-skywatch.md`, `docs/SPEC-planefinder-gap.md` — Skywatch specs.
- `docs/FEATURE-RESEARCH.md`, `docs/STRATEGY-competitive.md` — competitive research.
- `docs/SPEC-app-pages.md` — older page-by-page spec; superseded in places by
  `SPEC-planefinder-gap.md`.
