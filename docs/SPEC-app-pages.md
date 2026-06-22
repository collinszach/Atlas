# SPEC — Atlas app pages & feature parity (beat FR24 + Plane Finder)

_The definitive page-by-page spec. Goal: everything Flightradar24 and Plane Finder do, done
better — free, no ads, ambient AI alerts, aircraft-type-forward, plus AR. iOS SwiftUI._

## Product pillars (how we beat them)
1. **Free & ad-free** — no paywalled features, no ads (FR24's #1 complaint).
2. **Ambient intelligence** — Skywatch pushes when something *you* care about is overhead, even
   app-closed, via a local LLM. Nobody else does this.
3. **Aircraft-type-forward** — types are first-class: distinct silhouettes, prominent labels,
   "what type is that," browse-by-type. (User: "make aircraft types noticeable.")
4. **AR** — point your phone at the sky, see what's up there.
5. **Logbook + live tracking + stats in one** (Flighty + FR24 in one app).

---

## Tabs & pages

### 1. Map — live global tracking (the core)
**Does:** pan/zoom the world; every live aircraft as a **type silhouette** colored by altitude
(or status); tap → Aircraft Detail. Refreshes ~10s + on pan.
**Must have (parity + better):**
- Type-specific silhouettes (✅) + **callsign/type label** on tap-hover and at close zoom.
- **Filters** (✅): altitude, airline, type, military, emergency, on-ground.
- **Search** (✅): flight/callsign/reg/type/squawk.
- **Emergency feed** (✅, 7700/7600/7500).
- **Map layers** (toggle): standard / satellite / **dark**; **weather radar** (RainViewer);
  **day-night terminator**; **airports** (markers → airport page).
- **Marker clustering** when zoomed out (declutter).
- **Follow** an aircraft → camera tracks it + Live Activity.
- **Altitude color legend** + count ("N aircraft in view").
- **Long-press** → "what's here" / drop a watch point.
- Share current map view.

### 2. Sky — ambient radar + AR entry (Skywatch)
**Does:** what's overhead *right now* from your location.
- **Radar** (✅) with type-colored blips; tap → detail.
- **"Special now"** strip (✅) — rare/military/emergency.
- **AR button** → launches AR mode.
- **Alerts feed** — history of Skywatch pushes (GET /skywatch/alerts), tap → detail.
- **Preferences** (✅) — triggers, radius, quiet hours, natural-language box.

### 3. AR — point at the sky  ← BUILD THIS
**Does:** full-screen camera; overlay each live aircraft above you as a floating label
(callsign · type · altitude · distance), positioned by **compass bearing + elevation angle**
using CoreMotion device attitude + the aircraft's lat/lon/alt vs yours. Tap a label → detail.
- Reticle in center; nearest/locked aircraft highlighted.
- Heading/pitch HUD; "X aircraft overhead."
- Uses /overhead around the user; refresh ~5–8s.
- Graceful: needs camera + location permission; fallback message if denied.

### 4. Flights — logbook + tracked
**Does:** your flight history (logbook ✅) **and** flights you're tracking/following.
- Logbook cards (✅) — route, **airline + aircraft type prominent**, date, duration.
- **Followed flights** section — live status of aircraft you tapped Follow.
- **Track a flight** — search a flight number → live-track it (route progress, ETA from speed).
- Flight detail (restyled) — full leg + live position if airborne.
- Later: **auto-import** (email/Wallet boarding pass).

### 5. Stats — personal + global
- Bento (✅): km, countries, flights, hours, top airline, most-flown airport.
- **Add:** distance-to-the-Moon viz, **aircraft types flown** breakdown (you flew 6 A320s, 3 B789…),
  airlines flown, a flights-over-time chart, CO₂, longest flight, map of all your routes.
- **Global stats** tab: busiest aircraft type overhead today, most emergencies this week (fun).

---

## Detail pages (rich — fix "bare")

### Aircraft Detail (the money screen)
- **Header:** airline + flight number; **big aircraft type line** (manufacturer + model, e.g.
  "Airbus A320-232" — types must be noticeable) + a type silhouette.
- **Photo** (✅ planespotters), with credit + gallery later.
- **Route** (✅) origin→dest with map arc + progress + ETA.
- **Altitude & speed graph** — sparkline/chart from the polled positions (live, grows as you watch).
- **Telemetry** (✅): alt, speed, heading, squawk, vertical speed, distance.
- **Airframe** (✅): manufacturer, model, **registration, operator, country, age** (adsbdb).
- **Live trail** (✅) on mini-map.
- **Actions:** Follow (→ alert + Live Activity), Share, "see all <type> flying" (browse-by-type),
  open on map.

### Airport page (parity)
- Header: name, IATA/ICAO, city, local time, weather.
- **Live aircraft on the ground + nearby** (free, from /point around the airport).
- Departures/arrivals boards — _needs paid schedule API (AeroDataBox/FlightAware); Phase 2._
- Map inset.

### Aircraft Type page (our differentiator)
- Tap any type (A320, B748, F35…) → **all of that type currently flying** (search /type/{t}),
  silhouette, description, notable examples. Makes types first-class.

---

## Aircraft types: make them noticeable (immediate)
- **Map:** type silhouettes (✅) + type code label at close zoom.
- **Rows (FlightRow):** add a **type pill** (e.g. `A320`) next to the callsign everywhere.
- **Detail header:** the model line is large and prominent, with the silhouette.
- **Browse by type:** Aircraft Type page + "see all <type>" action.
- **Stats:** "aircraft types flown" breakdown.
- **Filter by type** (✅ in filters).

---

## Feature parity matrix (FR24 / Plane Finder → Atlas)
| Feature | FR24/PF | Atlas | Free? |
|---|---|---|---|
| Live global map | ✅ | ✅ shipped | ✅ |
| Tap → rich detail (photo/route/telemetry) | ✅ | ✅ shipped | ✅ |
| Aircraft photos | ✅ | ✅ | ✅ |
| Search | ✅ | ✅ | ✅ |
| Filters | ✅ | ✅ | ✅ |
| Type silhouettes | ✅ | ✅ | ✅ |
| Flight trail | ✅ | ✅ (live) | ✅ |
| Altitude/speed graph | ✅ | **build** | ✅ |
| **AR view** | ✅ | **build** | ✅ |
| Weather layer | ✅ | **build** (RainViewer) | ✅ |
| Day-night terminator | ✅ | **build** | ✅ |
| Airport markers + page | ✅ | **build** (live) | ✅ live / ⚠️ paid boards |
| Marker clustering | ✅ | **build** | ✅ |
| Follow + alerts | ✅ (paid) | **build** (better: ambient) | ✅ |
| Live Activities / widgets | Flighty | **build** | ✅ |
| Bookmarks/favorites | ✅ | **build** | ✅ |
| Most-tracked / interesting | ✅ | ✅ (Skywatch special) | ✅ |
| Statistics | Flighty | ✅ + expand | ✅ |
| Logbook / my flights | Flighty | ✅ | ✅ |
| Airport boards / schedules | ✅ | Phase 2 (paid) | ⚠️ |
| Historical playback | ✅ (paid) | Phase 2 (paid) | ⚠️ |
| ATC audio | PF | **build** (LiveATC) | ✅ |
| 3D cockpit | FR24 | skip (low ROI) | — |

## Build order
1. **Aircraft-type prominence** (rows/detail/map labels) — now.
2. **AR mode** — now (dedicated agent).
3. **Altitude/speed graph** in detail.
4. **Map layers**: weather + day-night + clustering (needs MKMapView-backed map — bigger).
5. **Airport markers + Aircraft Type page + browse-by-type.**
6. **Live Activities** (Follow → lock screen).
7. **Bookmarks**, **ATC audio**, **global stats**, **track-a-flight**.
8. Phase 2 (paid): airport boards, historical playback.
