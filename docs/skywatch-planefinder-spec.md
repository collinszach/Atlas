# Skywatch: Plane Finder–parity spec

## Goal
Make Skywatch a genuinely better clone of Plane Finder / Flightradar24-style apps for the aviation enthusiast — not a personal flight-companion (see the Flighty-framing removal from this session: no "my booked flight," no gate/delay alerts). Every feature below is scoped to "any aircraft, any airport," which is what a spotter/enthusiast actually wants.

## Current state (already built)
- Live ADS-B map with filters, layers, search (`Features/Map/MapView.swift`)
- Ambient radar home + "special right now" carousel + nearby list (`Features/Skywatch/SkyView.swift`)
- Universal search by flight#/callsign/reg/hex/type/squawk → `AircraftDetailSheet`
- Aircraft detail: photo, route label, live telemetry, airframe DB lookup (manufacturer/owner/type), "why special" badges, mini-map, Watch (Live Activity)
- Aircraft type browsing (`AircraftTypePage`)
- Bookmarks (aircraft + airports)
- Alerts: rare/military/emergency squawk feed + natural-language preference rules + quiet hours
- ATC audio streaming by airport ICAO (`ATCPlayer`, `atc_feeds.json`)
- AR sky view (camera + compass overlay of overhead aircraft)
- Airport page: identity, local time, ATC feed, live aircraft nearby — **departures/arrivals explicitly stubbed out** (`AirportPage.swift`: "Departure/arrival boards require a paid schedule API — out of scope")

## Gap: Airport Departures & Arrivals (this session's ask)

### The data problem, stated plainly
ADS-B (what Skywatch already ingests via `airplanes_live`/`dump1090`) gives you *live positions of aircraft in the air*. It does **not** give you a scheduled departures/arrivals board — that's airline/airport schedule data, a fundamentally different data source. Three ways to get it, in order of recommendation:

| Option | Cost | Coverage | Notes |
|---|---|---|---|
| **AeroDataBox** (RapidAPI) | Free tier: 300 calls/mo, then paid | Good global schedule + live status | Same family as `adsbdb` we already use for airframe lookups; has a dedicated `/airports/icao/{icao}/flights` endpoint returning scheduled + estimated + actual times |
| **AviationStack** | Free tier: 100 calls/mo (HTTPS locked to paid) | Good | Already listed as an optional env var in `CLAUDE.md` (`AVIATIONSTACK_API_KEY`) for the travel-journal's flight enrichment — could be shared |
| **Derive from ADS-B alone** | Free | Weak | Approximate "recent departures" by watching aircraft whose `on_ground→airborne` transition happened near the airport, and "recent arrivals" the reverse. No *future* schedule, no flight numbers for aircraft not yet visible. Good as a free fallback, bad as a primary feature. |

**Recommendation:** AeroDataBox free tier to start (300 calls/mo covers a handful of airports refreshed a few times a day comfortably with backend caching), same client pattern as `aircraft_db.py`. Cache aggressively (15–30 min TTL) since schedules don't change second-to-second. Gate the feature behind an env var like the existing `AVIATIONSTACK_API_KEY` pattern so it degrades gracefully (falls back to the ADS-B-derived "recent activity" list) if no key is configured.

### Feature spec: Departures & Arrivals board

**Backend** (new, in `backend/app/services/`):
- `airport_schedule.py` — AeroDataBox client, same shape as `aircraft_db.py` (cache dict + TTL + `NamedTuple` result). Fetches `{icao}` departures/arrivals for a rolling ±12h window.
- New router endpoints in `skywatch.py`:
  - `GET /skywatch/airports/{icao}/departures`
  - `GET /skywatch/airports/{icao}/arrivals`
  - Response: list of `{flight_number, airline, aircraft_type, scheduled_time, estimated_time, actual_time, status, origin/dest_iata, gate?, terminal?}`

**iOS** (`Features/Map/AirportPage.swift`):
- Replace `boardsNote` with a segmented control: **Departures / Arrivals**.
- Each row: flight number + airline logo/initial badge, destination or origin IATA + city name, scheduled time (with estimated/actual struck-through-and-replaced if delayed), status pill (On Time / Delayed / Departed / Landed / Cancelled — semantic color, not color-only per the accessibility rule already in `ui-ux-pro-max` guidance we installed this session).
- Tapping a row: if the flight is currently airborne and visible on ADS-B, deep-link into `AircraftDetailSheet` (reuse existing search-by-callsign resolution). If not yet airborne or already landed, show a lightweight static detail sheet (no live telemetry section).
- Pull-to-refresh; auto-refresh every 5 min while the page is open (cheaper than Skywatch's 15s aircraft-position refresh — schedules don't need that cadence).
- Empty/degraded state: if no API key is configured server-side, show the ADS-B-derived "recent activity" list instead with a small "Live-derived, not a full schedule" caption — never a dead end.

## Full Plane Finder–parity checklist

Organized by priority. ✅ = already have it (from the state above). 🆕 = this spec adds it. ⏸ = deliberately excluded (Flighty-style personal tracking).

**Core map & tracking**
- ✅ Live global ADS-B map, filters (altitude/airline/military/type), layers
- ✅ Aircraft detail sheet (photo, route, telemetry, airframe DB, mini-map)
- ✅ Search by flight#/callsign/reg/hex/type/squawk
- ✅ Watch + Live Activity (Lock Screen / Dynamic Island) for a spotted aircraft
- ✅ AR sky view

**Airports**
- ✅ Airport identity page, local time, ATC audio, live aircraft nearby
- 🆕 Departures/arrivals board (this spec)
- 🆕 Airport-level stats: busiest routes today, most common aircraft type seen, live movement count (cheap to compute from cached ADS-B history, good "enthusiast" flavor)

**Discovery & alerts**
- ✅ Rare/military/emergency alert feed with NL preference rules, quiet hours
- ✅ Bookmarks (aircraft + airports)
- 🆕 **Airport bookmarking → departure/arrival digest**: optional push notification for "N departures from your bookmarked airport in the next hour" (spotter session planning — not personal-flight framing, this is "what's about to be interesting at KJFK," same as watching a webcam)
- 🆕 Aircraft type "spotted" log / life-list (classic plane-spotter behavior: track every registration you've personally seen, like a birder's life list) — could live entirely client-side (Core Data / SwiftData) keyed on hex+date, no backend needed for v1

**Data & polish**
- ✅ Aircraft photo lookup
- 🆕 Route history / playback for a specific aircraft's last N hours (requires storing ADS-B position history server-side — check if `services/adsb` already persists positions or only proxies live; if not persisted, this needs a new table + retention policy, flag as a separate follow-up spec, not bundled into this one)
- ⏸ "My flight" booking import, gate/boarding notifications, delay alerts tied to a personal itinerary — explicitly out of scope per this session's pivot away from Flighty framing

## Recommended build order
1. Departures/Arrivals board (backend service + 2 endpoints + `AirportPage` UI) — the concrete ask.
2. Airport-level stats (cheap, reuses departures/arrivals + existing overhead cache).
3. Spotted aircraft life-list (client-only, no backend dependency, ships independently).
4. Bookmarked-airport digest notification (needs push infra decision: reuse existing APNs device registration from Skywatch alerts).
5. Route history/playback — separate spec once position-persistence is decided.

## Open decision before implementation
Which schedule data source to key up (AeroDataBox vs AviationStack vs ADS-B-derived-only) — recommend AeroDataBox per the table above, but this needs an account/API key decision from you before backend work starts.
