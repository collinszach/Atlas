# SPEC — Atlas Flight UI revamp

_Owner: PM/Architect (Opus) · designed via impeccable · mockups: `docs/mockups/atlas-flight-ui.html`_

## Direction
Atlas pivots from travel journal to **flight tracker** (Skywatch + FR24/Plane-Finder-class).
Visual language: **dark, modular, glassy, flashy** — electric **blue → cyan** accent, bold
**SF Pro Rounded** headings, **mono** for all flight data (callsigns, FL, distances, dates),
glass used *functionally* (over the live map, floating sheets), **bento/varied** modules (never
identical card grids), solid type (no gradient text). Design system already in `Theme.swift`
(`AtlasGradient`, `.atlasCard`, rounded `AtlasFont.display`). No serif anywhere.

Four tabs: **Map · Sky · Flights · Stats** (trip planning removed). Mockup is the visual contract.

## Screen contracts (translate mockup → SwiftUI)
- **Map** — clean flat dark `Map`; live aircraft as rotated plane glyphs (cyan = airline, blue =
  selected, amber = military); a floating **glass header capsule** ("Live map · N in view · LIVE");
  a **bottom glass sheet** listing nearest flights (airline badge, callsign, type · route · FL, distance).
- **Sky** — **radar**: concentric range rings + sweep + you-dot + colored blips; a **"Special right
  now"** horizontal strip of glass cards (MILITARY / RARE / EMERGENCY); a glass **nearby list**.
- **Flights** — **logbook**: modular glass cards, airline pill + date, big **route (ORIG → DEST)** with
  dashed great-circle, mono aircraft/reg/duration/distance line; hero subtitle stat.
- **Stats** — **bento grid**: one wide hero tile (km flown, cyan), varied small tiles (countries,
  flights, hours, nights), a wide "most flown / top airline" tile. Varied sizes = modular.

## Epics & stories (build order)

### EPIC A — Design system finish (foundation)
- **A1** As a user, every screen uses the new dark/glass/rounded system. _AC:_ no serif; `AtlasFont.display`
  is rounded; accent is blue→cyan; `.atlasCard` glass modifier used for modules. ✅ (shipped: Theme, shell, sign-in, map)
- **A2** Reusable SwiftUI components: `GlassCard`, `StatTile`, `AirlineBadge`, `AircraftRow`, `Pill`,
  `BentoGrid`. _AC:_ each has loading + empty + pressed states; used across all four screens.

### EPIC B — Sky (live radar) revamp  ← highest value
- **B1** Radar view: range rings, sweep animation, you-dot, blips colored by class. _AC:_ blips map to live
  `/skywatch/overhead`; military=amber, rare=violet, emergency=red, normal=cyan; reduced-motion disables sweep.
- **B2** "Special right now" strip: glass cards for aircraft with matches, tap → detail. _AC:_ only non-empty
  matches; shows trigger label + airline/type + distance; empty state "clear skies."
- **B3** Nearby list (glass) with `AircraftRow` (airline badge, name, type · distance · FL, chevron).
- **B4** Aircraft detail sheet: airline, flight #, type, registration, altitude/speed/heading/squawk,
  distance, why-special. _AC:_ mono data; map mini-inset; "track" affordance.

### EPIC C — Map revamp
- **C1** Replace city/arc markers with **live aircraft glyphs** (rotated by heading) from a new
  bounding-box ADS-B query. _AC:_ pan/zoom refetches the visible box; ~10–15s refresh.
- **C2** Glass header capsule + bottom **nearest-flights sheet** (detents). _AC:_ tap a flight → detail/track.
- **C3** Tap aircraft on map → same detail sheet as B4; selected glyph highlights blue.

### EPIC D — Flights logbook revamp
- **D1** Replace Trips list with **flight-centric logbook cards** (route, airline, aircraft, date, duration).
  _AC:_ data from transport legs; newest first; airline resolved (reuse backend airline map).
- **D2** Flight detail: full leg info + map route arc + aircraft photo (planespotters, free).
- **D3** "Log a flight" stays (flight form already exists); restyle to glass.

### EPIC E — Stats bento
- **E1** Bento grid of varied tiles from `/stats`: hero km tile, countries, flights, hours-in-air, nights,
  most-flown airport, top airline. _AC:_ real `/stats`; needs backend additions (hours-in-air, top airline, most-flown airport).
- **E2** Backend: extend `/stats` with `hours_in_air`, `top_airline`, `most_flown_airport`.

### EPIC F — FR24-class features (free data; phased, see SPEC-flight-ui future)
- **F1** Bounding-box global ADS-B endpoint `/live/box?bounds=` (airplanes.live area query).
- **F2** Route enrichment (origin→dest) via adsbdb callsign→route; show on map + detail.
- **F3** Aircraft photos via planespotters API (by reg/hex), cached.
- **F4** Search: by flight #, callsign, registration, airport, type, squawk → jump to aircraft.
- **F5** Flight trail / breadcrumb (airplanes.live trace) drawn on map.
- **F6** Filters (altitude, airline, type, military, emergency).
- **F7** (paid, later) Airport boards + historical playback via AeroDataBox/FlightAware.

## Build sequencing
1. **A2** components → **B1–B4 Sky** (the signature, biggest visual win).
2. **C1–C3 Map** live aircraft + detail.
3. **D1–D3 Flights** logbook + photos.
4. **E1–E2 Stats** bento + backend stat fields.
5. **F** FR24 features (box endpoint, routes, photos, search, trails).

## Data / backend deltas needed
- `/live/box` bounding-box ADS-B (F1) · `/stats` new fields (E2) · route lookup service (F2) ·
  photo proxy/cache (F3) · search endpoints (F4) · trail endpoint (F5). All on free APIs.

## Pain points to fix (what FR24 / Plane Finder users complain about)
- **Paywalls & ads** → Atlas is fully free, no ads, no gated features.
- **Cluttered map** → rotate glyphs by heading, cap/cluster markers, hide labels when zoomed out,
  tap-to-focus dims the rest.
- **Battery drain** → significant-location + throttled refresh (~10–15s), pause polling when backgrounded.
- **Buried search** → search is a first-class action (flight #, callsign, reg, airport, type, squawk).
- **Raw codes** (A320, JBU) → always resolve to human names (airline + aircraft type). Already wired.
- **Slow with many aircraft** → cap visible markers, throttle, lightweight glyphs.
- **No sense of "what's interesting"** → Skywatch "special now" surfaces it; emergencies (7700) pinned.
- **Privacy** → location is last-known only, user-scoped, deletable.

## What people love (must include)
- **Aircraft photos** (planespotters, free) in the detail sheet — the single most-loved feature.
- **Rich tap detail**: route origin→dest, altitude/speed/heading, type, reg, photo, **Follow** + **Share**.
- **Flight trail / path** drawn on the map.
- **Filter to interesting** (military / rare / emergency).
- **Personal flight log + stats** (Flighty-style).
- **Emergency surfacing** — squawk 7700/7600/7500 pinned to the top, red.
- **Follow a specific flight** → alert when it's near / lands (ties into Skywatch push).
- A **smooth, beautiful, decluttered map**.

## Definition of done (per screen)
Matches the mockup's composition + density; all states (loading skeleton, empty, error); mono for
data; glass only where functional; reduced-motion paths; builds + runs on device; no serif.
