# SPEC — Plane Finder feature-gap (verified against code, 2026-06-29)

Companion to `SPEC-app-pages.md`/`FEATURE-RESEARCH.md`, which are **stale**: they mark AR,
flight trail, and altitude/speed graph as "build", but those are **already shipped**
(`Features/AR/*`, `AircraftDetailSheet.swift`). This doc is the corrected, code-verified gap and
the implementation contract for the build agents. Everything here is **free-data, iOS-native**.

## Architecture facts (verified)
- **Live geographic map** = `Features/Map/MapView.swift` — SwiftUI MapKit `Map`, dark, plots
  `vm.liveAircraft` as `PlaneGlyph` annotations; has filters/search/emergency/follow. Refresh 12s +
  on camera change via `MapViewModel.loadLive`.
- **Sky tab** = `Features/Skywatch/SkyView.swift` — a **polar radar** (custom ZStack, not a geo map).
- **Detail** = `AircraftDetailSheet.swift` (uses MapKit for trail mini-map).
- Follow state = `UserDefaults` key `skywatch_followed_hexes` (shared Map↔Sky).
- API client = `iOS/Atlas/API/APIClient*.swift`; backend Skywatch router = `backend/app/routers/skywatch.py`.
- Conventions: SwiftUI + `@Observable` view models; theme tokens in `Shared/Theme.swift`
  (`Color.atlas*`, `AtlasFont`, `AtlasGradient`); type silhouettes in `Shared/AircraftIcon.swift`
  (`AircraftMarker`/`AircraftCategory`); filters in `Shared/AircraftFilter.swift`.
- iOS project is **xcodegen-managed** — after adding Swift files run `cd iOS && xcodegen generate`
  (do not commit the .pbxproj). Don't break the build; keep edits surgical.

## Batch 1 — Map layers
Target `MapView.swift`. SwiftUI `Map` cannot host raster tile overlays or native clustering, so:
- **Migrate the live map to an MKMapView-backed `UIViewRepresentable`** (keep the existing header,
  sheets, filter/search/emergency/follow wiring, 12s refresh, tap→detail). This unlocks the rest.
- **Satellite / hybrid / standard-dark** style switcher (segmented control in a layers menu).
- **Weather radar layer** — RainViewer public tiles (`https://tilecache.rainviewer.com/...`) as an
  `MKTileOverlay` with adjustable opacity; toggle in layers menu. No key required.
- **Day-night terminator** — compute the night-side polygon (solar subsolar point → great-circle)
  and draw as a dim `MKPolygon` overlay; toggle.
- **Marker clustering** — native `MKMarkerAnnotationView` clustering (or annotation grouping) to
  declutter when zoomed out; cluster bubble shows count; keep type silhouettes for single planes.

## Batch 2 — Live Activities + Bookmarks
- **Live Activity (ActivityKit)** for a Followed flight: lock-screen / Dynamic Island showing
  callsign, type, route, altitude/speed, progress. New widget extension target (xcodegen + Info
  plist `NSSupportsLiveActivities`). Start when user taps Follow on an airborne aircraft; update
  from polled positions; end on landing/untrack. Reuse the `followed` UserDefaults set.
- **Bookmarks/favorites** — persist favorite aircraft (hex) and airports; a Bookmarks list
  (reachable from Sky or Map); star toggle in `AircraftDetailSheet`. Local store (UserDefaults/JSON
  or a small @Observable store); keep it simple and shared across tabs.

## Batch 3 — Type-forward + Airports
- **Aircraft Type page** — tap a type code → all of that type currently flying
  (backend search already routes `/skywatch/search` by type; add a type-filtered fetch). Show
  silhouette + short description + live list → detail. Add "see all <type>" action in detail.
- **Type pills** — small type-code pill (e.g. `A320`) next to callsign in all flight rows
  (Search results, Emergency, Alerts, Sky lists). Reuse `AircraftCategory`.
- **Airport markers + Airport page** — show nearby airports as map markers; tap → Airport page
  with name/IATA/ICAO/city/local-time, and **live aircraft on ground + nearby** via the existing
  `/skywatch/overhead` (or a point query) around the airport. Departure/arrival boards are paid →
  out of scope (note as Phase 2). Need a static airport coordinate dataset (bundle a small JSON of
  major airports; cite source).

## Batch 4 — ATC audio + Track-a-flight
- **Live ATC audio** — stream the nearest tower/approach from LiveATC (`https://www.liveatc.net/`
  ICAO `.pls`/`.m3u` feeds) via `AVPlayer`; surface on the Airport page and as a "Listen" action.
  Bundle a small ICAO→feed mapping for major fields; background audio mode.
- **Track-a-flight by flight number** — search a flight/callsign → resolve to the live aircraft
  (backend `/skywatch/search`), show live route progress + ETA-from-speed; tie into Follow so it
  becomes a Live Activity. Distinct from the personal logbook (`APIClient+Flights.swift`).

## Out of scope (paid / low-ROI)
Airport departure/arrival boards & full historical playback (paid schedule APIs — Phase 2);
3D globe/cockpit (low ROI); Apple Watch app (later); web-frontend flight parity (separate effort).
