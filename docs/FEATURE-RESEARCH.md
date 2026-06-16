# Atlas — flight-tracker feature research

_What people want from FR24 / Plane Finder / Flightradar24 / Flighty / RadarBox / ADSB Exchange,
synthesized from their feature sets + community wishlists (r/flightradar24, plane-spotting forums,
App Store reviews). Mapped to feasibility on free data and to Atlas's edge._

## Atlas's unique angle (why we win)
Nobody combines all three of these in one app:
1. **Live tracking** (FR24-class) — global map, tap any plane, rich detail.
2. **Personal logbook + stats** (Flighty-class) — your flights, your numbers.
3. **Ambient intelligence** (ours) — Skywatch server-side watch pushes when something *you* care
   about is overhead, even with the app closed, powered by a **local LLM** (natural-language
   preferences, zero runtime cost). FR24 charges for limited alerts; ours is richer and free.
Plus: **no paywall, no ads, own-your-data** (self-hosted, optional home ADS-B receiver).

## Most-loved features (ranked by demand × feasibility on free data)
| Feature | Demand | Free? | Status / plan |
|---|---|---|---|
| Tap plane → rich detail (route, photo, telemetry) | ★★★★★ | ✅ | **Shipped** |
| Aircraft photos | ★★★★★ | ✅ planespotters | **Shipped** |
| Search (flight/callsign/reg/type/squawk) | ★★★★★ | ✅ | **Building now** |
| Clean, fast, dark map | ★★★★★ | ✅ | **Shipped** (live glyphs) |
| Type-specific aircraft icons | ★★★★☆ | ✅ | **Shipped** (silhouettes) |
| Filters (altitude/airline/type/military/emergency) | ★★★★☆ | ✅ | **Next** |
| Flight trail / breadcrumb path | ★★★★☆ | ⚠️ free trace via tar1090 globe.airplanes.live | **Next** (wire public trace) |
| **AR "point at the sky"** identify | ★★★★★ | ✅ (CoreMotion + camera) | High-value, native build |
| **Live ATC audio** (listen to nearby tower) | ★★★★☆ | ✅ LiveATC streams | Beloved niche; add per-airport |
| Squawk 7700 **emergency feed** (global, live) | ★★★★☆ | ✅ airplanes.live /squawk/7700 | Easy, loved by spotters |
| **Military mode** (track mil aircraft) | ★★★★☆ | ✅ | Filter + dedicated view |
| Follow a flight → alert near/landing | ★★★★☆ | ✅ (ties into Skywatch push) | Follow button exists; wire alerts |
| **Live Activities / widgets** (lock-screen flight) | ★★★★★ | ✅ (ActivityKit) | Flighty's signature; big win |
| Personal logbook + auto-import (email/wallet) | ★★★★★ | ✅ | Logbook shipped; auto-import next |
| Stats dashboards (personal + global) | ★★★★☆ | ✅ | **Shipped** (bento) |
| Bookmarks / favorites (aircraft, airports) | ★★★☆☆ | ✅ | Small add |
| Weather overlay (radar/clouds) | ★★★☆☆ | ✅ RainViewer tiles | Map layer |
| Airport boards (departures/arrivals, gates) | ★★★★☆ | ⚠️ **paid** (AeroDataBox/FlightAware) | Phase 2, paid |
| Flight playback / history | ★★★☆☆ | ⚠️ paid for deep history | Recent-trail free; full = paid |
| Apple Watch app | ★★★☆☆ | ✅ | Later |
| 3D cockpit view | ★★☆☆☆ | ✅ heavy | Low ROI |

## Pain points to keep avoiding (App Store / Reddit complaints)
- **Paywall creep & ads** — Atlas stays free, no ads. (Biggest single complaint about FR24.)
- **Battery drain** — significant-location, throttled refresh, pause when backgrounded. (Done.)
- **Cluttered map** — declutter at zoom, cap markers, tap-to-focus. (Glyphs + cap; add clustering.)
- **Subscription fatigue / nagging** — none.
- **Coverage gaps over oceans** — be honest in UI ("no ADS-B coverage here"); optional MLAT later.
- **Stale data / crashes with many planes** — cap results, throttle, lightweight rendering.
- **Buried features** — search + filters as first-class actions.

## Recommended next build order
1. **Filters** (altitude band, airline, type, military, emergency) — quick, high-demand, makes the
   map usable. Pair with **clustering** when zoomed out.
2. **Flight trails** — wire the free tar1090 public trace (`globe.airplanes.live/data/traces/...`)
   so the detail mini-map shows the real path.
3. **Emergency feed** + **Military mode** — a tab/filter surfacing 7700 squawks and military
   aircraft globally; cheap, spotter-beloved, plays to Skywatch.
4. **Live Activities + widgets** — Follow a flight → lock-screen live tracking. Flighty's killer
   feature; we already have Follow + push plumbing.
5. **AR identify** — "point your phone at a plane" overlay using CoreMotion + camera + our live
   data. The single most wow-factor feature; differentiates hard.
6. **Live ATC audio** — listen to the nearest tower/approach (LiveATC). Loved by enthusiasts.
7. **Auto-import** (email/Wallet boarding pass) → logbook. Flighty-class capture, kills manual entry.
8. **Weather overlay** (RainViewer) + **bookmarks**.
9. _(Paid, Phase 2)_ Airport boards + full historical playback via AeroDataBox/FlightAware.

## Notes
- Most of the top 8 are **free-data** and native-iOS work — no new paid dependency.
- Skywatch already differentiates on alerts; Live Activities + AR + ATC audio are the features
  that would make Atlas genuinely better than FR24 for enthusiasts, not just a clone.
