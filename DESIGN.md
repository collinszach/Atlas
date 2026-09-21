# Design

Visual system for Atlas. Dark cartographic — deep navy field, antique gold as rare signal,
instrument-grade typography. Register: product (with the map as one drenched, committed surface).

## Theme

Dark, always. The physical scene: someone on a couch at night watching what's crossing the sky
overhead, or at a desk reviewing everywhere they've flown. The interface is instrumentation in a
dim cockpit — it glows, it never glares. Light mode is out of scope; it would betray the identity.

Color strategy: **Restrained** across product chrome (navy field + gold accent ≤10% of surface),
stepping to **Committed/Drenched** only on the map home, where the globe and deep field own the
screen.

## Color (OKLCH)

Existing brand hexes are preserved as the anchor; the ramp is built around them.

### Field & surfaces (cool navy ramp)
- `--bg`            #0a0e1a  — deepest field, app background
- `--bg-deep`       #070a13  — map void / behind-content wells
- `--surface`       #111827  — cards, panels
- `--surface-2`     #16203a  — raised panels, hover wells, sidebar
- `--border`        #1e2d45  — hairlines
- `--border-strong` #2a3c5c  — focused / active hairlines

### Ink (text ramp — contrast-checked on --bg)
- `--ink`           #e8eef7  — primary text (~13:1)
- `--ink-2`         #aebbd0  — secondary text (~7:1, replaces the failing #64748b for body)
- `--ink-faint`     #6b7a94  — non-text only: disabled, decorative, watermark graticule

> The legacy `--atlas-muted` #64748b fails 4.5:1 for body copy on the navy. It survives only as
> a decorative / disabled tone. All readable secondary copy uses `--ink-2`.

### Signal (semantic — never decoration)
- `--accent`        #c9a84c  — antique gold: primary action, current selection, focus
- `--accent-hi`     #e3c673  — gold highlight (hover on gold)
- `--cool`          #4a90d9  — ocean blue: the map, links
- `--arc`           #4a90d9  — great-circle arcs for flights you've flown

> The old `--visited` / `--planned` / `--bucket` country fills are gone with the choropleth;
> nothing fills countries any more.

### Aircraft classification (live map / Skywatch)
Semantic, and always paired with a glyph or label so hue is never the only carrier:
- military  amber · rare  violet · emergency  red · normal  cyan

### Status
- success #4ca87a · warning #c99a4c · danger #d36b6b · info #4a90d9
  (each paired with a 12–15% alpha tint for backgrounds)

## Typography

Three families, each with a strict job. Display is a *moment* font, never a label font.

- **Display — Playfair Display** (600/700): route headers (`BOS → FLL`), airport and city names,
  the stat hero numerals' companions. Letter-spacing ≥ -0.02em. Never on buttons, labels, or data.
- **Body/UI — IBM Plex Sans** (400/500/600): all interface text, headings in chrome, body copy.
- **Mono — IBM Plex Mono** (400/500): the instrument voice — coordinates, dates, flight numbers,
  distances, counts, altitudes, registrations, IATA/ICAO codes, any earned number. This is the
  brand's signature tell.

Scale: fixed rem, product ratio ~1.2. `text-xs .75 / sm .875 / base 1 / lg 1.125 / xl 1.375 /
2xl 1.75 / 3xl 2.25`. Display hero uses `clamp` only on the map/stats hero, max ≤ 4rem.
Body prose capped 70ch. `text-wrap: balance` on display headings.

## Materials (depth without glass/gradient)

Atmosphere comes from cartography, not decoration:
- **Graticule**: a faint lat/long grid (`--ink-faint` at 3–5% alpha) as a background texture on
  empty wells, the sidebar, auth, and behind hero numbers. The recurring brand texture.
- **Deep field**: a radial darkening from center→edge on full-bleed surfaces (`--bg`→`--bg-deep`).
- **Elevation**: borders + a soft ambient shadow (`0 1px 0 rgba(255,255,255,.02) inset, 0 8px
  24px -12px rgba(0,0,0,.6)`), never glassmorphism.
- **Arc/contour accents**: thin gold/cool great-circle strokes used sparingly as section dividers
  or hero ornament.

## Components

Standard product vocabulary, one shape language. Radius scale: `sm 6px / md 8px / lg 12px /
pill 999px`. Controls are 8px. All interactive elements ship every state: default, hover, focus
(2px accent ring, offset), active, disabled, loading, selected, error.

- **Button**: primary (gold on navy), secondary (surface + border), ghost, danger. Mono-cased
  labels never; sentence case, verb+object.
- **Badge/Status pill**: status uses tint+text+a 1px dot, distinguishable without hue (dot shape
  + label) for color-blind safety.
- **Card**: bordered surface with ambient elevation; no nested cards, no side-stripe borders.
- **Input/Select**: navy well, hairline border, gold focus ring; labels are sentence-case
  `text-xs` `--ink-2`, not uppercase-tracked eyebrows.
- **Skeletons** for loading (not center spinners). **Empty states** teach the next action.
- **Stat readout**: mono numeral, `--ink-2` label below, optional unit — instrument styling.

## Motion

150–250ms, ease-out (quart/expo). State and feedback only in chrome. The map earns more: arc
draw-on, globe settle, staggered marker reveal — all with a `prefers-reduced-motion` crossfade.
No page-load choreography on product screens. Library: CSS for chrome; `maplibre` handles map.

## Layout

**Web** app shell: a labeled left rail (icon + label, ~210px, collapsible to 56px icon-rail on narrow
viewports), content fills the rest. **iOS** uses a bottom tab bar (Map · Sky · Flights · Stats)
instead of the rail; everything else in this system applies unchanged. The map is full-bleed
under floating panels. Responsive is structural (rail collapse, grid breakpoints), never fluid
type.

## Platform conformance

This document is the target system for **both** surfaces. The web frontend already conforms.
iOS does not yet, and the gaps are tracked here rather than quietly tolerated:

| Area | This system | iOS today (`Theme.swift`) | Status |
|---|---|---|---|
| Display type | Playfair Display | `.system(design: .rounded)` | **Migration owed** — decided 2026-09-20 |
| Body / mono | IBM Plex Sans / Mono | system sans / system mono | **Migration owed** — same decision |
| Accent | antique gold `#c9a84c` | electric blue `#4F8DFF` + cyan | **Open** — not yet decided |
| Materials | borders + ambient shadow, *never* glassmorphism | `.atlasCard` glass, blur, accent glow | **Open** — not yet decided |

The type migration needs Playfair Display and IBM Plex bundled into the iOS app (both are SIL
OFL) and `AtlasFont` rewritten.

The accent and material rows are a genuine fork, not drift: `docs/SPEC-flight-ui.md` deliberately
specifies "dark, modular, glassy, flashy — electric blue → cyan" and "no serif anywhere" for the
flight UI, and iOS is fully built that way. Resolving it means either reversing this document's
gold/no-glass position or rebuilding the iOS surfaces. Until it's decided, treat the iOS
accent and glass as intentional and this table as the record of the disagreement.
