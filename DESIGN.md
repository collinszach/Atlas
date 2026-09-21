# Design

Visual system for Atlas. Dark cartographic — deep navy field, electric blue → cyan as signal,
functional glass, instrument-grade typography. Register: product (with the map as one drenched,
committed surface).

## Theme

Dark, always. The physical scene: someone on a couch at night watching what's crossing the sky
overhead, or at a desk reviewing everywhere they've flown. The interface is instrumentation in a
dim cockpit — it glows, it never glares. Light mode is out of scope; it would betray the identity.

Color strategy: **Restrained** across product chrome (navy field + blue/cyan accent ≤10% of
surface), stepping to **Committed/Drenched** only on the map home, where the globe and deep field
own the screen.

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
- `--accent`        #4F8DFF  — electric blue: primary action, current selection, focus
- `--accent-hi`     #6FA6FF  — blue highlight (hover / pressed)
- `--cyan`          #26E0E0  — the accent's partner; hero stats, live state, the brand gradient
- `--violet`        #8B6CFF  — rare / notable aircraft
- `--arc`           #4F8DFF  — great-circle arcs for flights you've flown

The brand gradient is `--accent → --cyan` (topLeading → bottomTrailing), reserved for hero
numerals and live indicators. Gradient **fills** only; never gradient text on body copy.

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

## Materials

Glass is used **functionally** — over the live map, on floating sheets, and on modular cards —
never as decoration on flat chrome. Atmosphere otherwise comes from cartography:

- **Glass card** (the workhorse; `.atlasCard` on iOS): `ultraThinMaterial` over `--surface` at
  60% opacity, a 1px hairline stroke fading white 10% → 2% topLeading → bottomTrailing, and a
  `0 10px 18px rgba(0,0,0,.35)` ambient shadow. Optional accent glow (`--accent` at 28%, 24px)
  on hero cards only — one per screen, and it must clip to the card's rounded shape.
- **Graticule**: a faint lat/long grid (`--ink-faint` at 3–5% alpha) as a background texture on
  empty wells, the sidebar, auth, and behind hero numbers. The recurring brand texture.
- **Deep field**: a radial darkening from center→edge on full-bleed surfaces (`--bg`→`--bg-deep`).
- **Elevation**: on non-glass chrome, borders + a soft ambient shadow (`0 1px 0
  rgba(255,255,255,.02) inset, 0 8px 24px -12px rgba(0,0,0,.6)`).
- **Arc/contour accents**: thin accent/cyan great-circle strokes used sparingly as section
  dividers or hero ornament. A dashed great-circle with a plane glyph is the logbook's signature.

## Components

Standard product vocabulary, one shape language. Radius scale: `sm 6px / md 8px / lg 12px /
xl 20px / pill 999px`. Controls are 8px; glass cards and sheets are `xl`. All interactive elements ship every state: default, hover, focus
(2px accent ring, offset), active, disabled, loading, selected, error.

- **Button**: primary (accent on navy), secondary (surface + border), ghost, danger. Mono-cased
  labels never; sentence case, verb+object.
- **Badge/Status pill**: status uses tint+text+a 1px dot, distinguishable without hue (dot shape
  + label) for color-blind safety.
- **Card**: glass surface per Materials; no nested cards, no side-stripe borders.
- **Input/Select**: navy well, hairline border, accent focus ring; labels are sentence-case
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

This document is the target system for **both** surfaces. Neither fully conforms yet; the gaps
are tracked here rather than quietly tolerated:

| Area | This system | iOS (`Theme.swift`) | Web (`globals.css`) |
|---|---|---|---|
| Display type | Playfair Display | `.system(design: .rounded)` — **owes migration** | ✅ conforms |
| Body / mono | IBM Plex Sans / Mono | system sans / mono — **owes migration** | ✅ conforms |
| Accent | electric blue `#4F8DFF` + cyan | ✅ canonical | ✅ conforms (migrated 2026-09-20) |
| Materials | functional glass | ✅ canonical | ✅ conforms (migrated 2026-09-20) |

Both decisions were made 2026-09-20. Accent and materials follow iOS, which was already built to
`docs/SPEC-flight-ui.md`'s blue/cyan glass direction; typography follows the web.

The **web accent + material migration is done**: tokens repointed to the blue ramp with `--cyan`,
`--violet` and `--arc` added, `Card` moved to the `.glass` recipe, and the dead
`--visited`/`--planned`/`--bucket` fills removed.

Outstanding: the **iOS type migration** — bundle Playfair Display and IBM Plex (both SIL OFL) and
rewrite `AtlasFont`. `atlasGold` is already dead and can go with it.
