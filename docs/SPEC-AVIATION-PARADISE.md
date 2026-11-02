# Atlas — the aviation geek's paradise

_Build-out spec. Written 2026-11-01 against the code, `docs/STATUS.md`, `docs/STRATEGY-competitive.md`
and the installed Hallmark skill — not from memory._

This spec does two things: it names the **one missing idea** that turns Atlas from "a tracker plus a
logbook" into a single product for aviation enthusiasts, and it gives the **web surface** a design
toolchain (Hallmark) and a job worth doing.

---

## 0. What Hallmark is, and the job it gets

Hallmark (`Nutlope/hallmark`, MIT, by Together AI) is **not** a library, an API or an
image-generation service. It is a **design skill for coding agents** — a `SKILL.md`, ~50 theme
"material" files, and Node scripts — now installed at `.agents/skills/hallmark/`
(symlinked into `.claude/skills/`). The tree is **gitignored** (8.6M, mostly theme
screenshots); `skills-lock.json` is tracked, so a checkout reinstalls it reproducibly with
`npx skills add nutlope/hallmark`. What it actually provides:

- **`scripts/sloplint.mjs`** — a linter with a static tier (CSS/markup/Tailwind utilities) and a
  **render tier** (`--render` headless Chrome at eight widths, or **`--url` against a running dev
  server**). Findings are graded `FAIL` (Floor — never ships) / `REFLEX` (a default, waivable on the
  record) / `WARN` / `NOTE`.
- **`--before` / `--kept`** — records a page's links, fields, handlers and headings, then **fails a
  redesign if any of them went missing**. This is the part that makes it safe to point at an app
  that already works.
- **~50 themes as *materials*** (paper, type, colour, surfaces, texture) rather than layouts, indexed
  by keyword in `references/themes/index.json`, each with a screenshot.
- A gate catalogue (`references/gates.md`) that is, read plainly, a list of the tells that make a
  page look machine-made: the eyebrow over every heading, tracked caps, one accent-coloured word in
  a headline, the bare number as a headline, the wireframe page of empty frames, the fake send.

### Therefore its scope in Atlas is bounded, and the boundary is the point

| Surface | Hallmark's role |
|---|---|
| Marketing / landing (`frontend/src/app/page.tsx`) | **Authors it.** Greenfield HTML/CSS is exactly its shape. |
| Public shared pages (new: `/f/[token]`, `/u/[handle]`) | **Authors them.** Static, self-contained, one idea per screen. |
| The authenticated app (`(app)/map`, `flights`, `stats`, `settings`) | **Audits it.** sloplint reads `.tsx` directly — it parses Tailwind class strings and `cn`/`clsx`/`cva` calls — so the static tier works on the React tree with no dev server. Add `--url` for the render tier, and `--before`/`--kept` on any redesign. It does not author React app shells. |
| iOS / SwiftUI | **Out of scope.** `DESIGN.md` § Platform conformance stays the contract there. |

Anyone who expects Hallmark to generate app screens or ship a component library will be
disappointed; what it is good for is making the public face of Atlas not look generated, and
keeping the app honest about contrast, focus, reduced motion and invented facts.

### Wiring (concrete, three tasks)

1. **`DESIGN.md` becomes the locked system.** Hallmark's pre-flight reads a root `DESIGN.md` and
   defers to it (`references/design-md.md`: *"Never overwrite. If `design.md` or `DESIGN.md` exists
   at the root, refresh its `## Exports` and say so"*). Atlas's already exists and is current. Add a
   `## Exports` section mapping Atlas token names to Hallmark's role names, because every sloplint
   flag is expressed in role terms:

   | Hallmark role | Atlas token |
   |---|---|
   | `--color-paper` / `-2` / `-3` | `--atlas-bg` / `--atlas-surface` / `--atlas-surface-2` |
   | `--color-ink` / `-2` / `--color-muted` | `--atlas-ink` / `--atlas-ink-2` / `--atlas-ink-faint` |
   | `--color-rule` | `--atlas-border` |
   | `--color-accent` / `--color-focus` | `--atlas-accent` |
   | `--font-display` / `-body` / `-outlier` | Playfair Display / IBM Plex Sans / IBM Plex Mono |

2. **Convert the tokens to OKLCH.** `DESIGN.md` is headed *"Color (OKLCH)"* but
   `frontend/src/app/globals.css` ships hex throughout. Hallmark's colour gates are written in
   oklch, and the ramp claims in `DESIGN.md` (the contrast ratios, the "cool navy ramp") are
   currently unverifiable from the file. Fix the file, not the doc.
3. **Gate it in CI.** `node .agents/skills/hallmark/scripts/sloplint.mjs <path> --render --json`
   over the landing and public pages; `--url` over the app routes against a dev server. Fail the
   build on `FAIL` only. `REFLEX` is advisory — Atlas is an instrument, and several Hallmark
   reflexes (dense mono data, a hero that is a number) are things Atlas does on purpose and should
   waive on the record rather than obey.

### Measured baseline

Run today, not estimated:

```
node .agents/skills/hallmark/scripts/sloplint.mjs frontend/src --scope app --genre atmospheric
→ 29 FAIL, 4 REFLEX, 9 WARN across 34 files
```

The 29 `FAIL`s fall across seven gates. Four are real work, one is a one-line delete, and two are
not Atlas's bugs:

| Gate | n | Where | Verdict |
|---|---|---|---|
| 67 tracked caps | 11 | `settings` ×4, `stats` ×2, `LandingHero` ×2, `flights/[id]`, `Sidebar`, `PageHeader` | **Fix.** `DESIGN.md` reserves small caps for instrument readings; these are form labels and stat captions. |
| 48 colour literal outside tokens | 9 | all in `globals.css` | **Fix with D5.** The glass gradients, graticule washes, selection fill and glow shadow are exactly the `rgba()` values the OKLCH conversion has to lift into tokens, so this is one task, not two. |
| 10a `transition: all` | 4 | `ui/Button.tsx`, `ui/Card.tsx`, `layout/Sidebar.tsx`, `landing/LandingHero.tsx` | **Fix.** A real performance gate — list the properties, prefer `transform`/`opacity`. Four one-line edits. |
| 34 overflow on `html, body` | 1 | `globals.css:59` | **Fix, and it blocks D1** — see below. |
| 54 the eyebrow | 1 | `ui/PageHeader.tsx` | **Delete.** One uppercase tracked line above every `<h1>`, so it is on every page by construction. The gate's test is whether the line carries a fact the reader lacks; "FLIGHTS" above "Flights" does not. |
| 19 em/en dash in copy | 2 | `FlightListClient.tsx`, `PhotoUploader.tsx` | **Not Atlas's bug.** Gate 19 bans em dashes as an AI-copy tell. Atlas's house voice uses them throughout, including in this spec. Suppress the clause rather than rewrite the copy. |
| 20 missing Hallmark stamp | 1 | `globals.css:1` | **Not applicable.** The stamp is bookkeeping that Hallmark-authored CSS carries. `globals.css` is hand-written. It is an artefact of pointing the linter at code Hallmark did not build. |

**Status: fixed. 29 FAIL → 1.** Every gate above was repaired on 2026-11-01 except gate 20, which
is excluded in CI (`DESIGN.md` § The one standing exclusion) because stamping hand-written CSS as a
Hallmark build would be a false claim. `tsc --noEmit` passes. The gate-48 work was verified in the
browser as a pure rename: all nine new tokens resolve, and their computed values are byte-identical
to the literals they replaced, so nothing moved visually. Two findings turned out to be more than
style once opened: the "Coordinate decoration" in the hero was hardcoded New York coordinates
presented as live readout (deleted, against PRODUCT.md's *every number real*), and the country-code
input's CSS `uppercase` was redundant because its `onChange` already calls `.toUpperCase()`.

**Gate 34 is the one worth reading closely, because the linter is right for the wrong reason.**
sloplint reports "overflow-x: hidden"; the actual rule is `overflow: hidden` on both axes, with
`height: 100%`, on `html, body`. That is the correct, deliberate way to build a fixed app shell, and
`(app)/layout.tsx` depends on it (`flex h-screen w-screen overflow-hidden`). But `globals.css` is
global, and `components/landing/LandingHero.tsx` is a `min-h-screen` element on a page that shares
it — **so the landing page cannot scroll, at all.** Today nothing is lost, because `app/page.tsx`
renders only the hero and it has no sections. The moment D1 adds a second screen to the landing
page, everything below the fold becomes unreachable.

The fix landed as: drop the document lock entirely — `(app)/layout.tsx` already clips itself with
`h-screen overflow-hidden`, so the body rule was redundant — and replace it with `overflow-x: clip`
(blocks horizontal scroll without creating a scroll container, which is what gate 34 actually asks
for) plus `overscroll-behavior: none` for rubber-banding, which is the right tool for that job.
Scoping the lock to the route group was tried first and still failed the gate, correctly: the
problem is `overflow` on `body` in any form. **Verified in the browser**: with the shipped CSS the
document scrolls to y=1200; re-applying the old `overflow: hidden` pins it at 0.

**Naming trap found while verifying this:** `tailwind.config.ts` maps `atlas-muted` →
`--atlas-ink-2` (#aebbd0, ~7:1), so the 11 files using `text-atlas-muted` are **fine**. But
`DESIGN.md` § Ink warns that "`--atlas-muted` #64748b fails 4.5:1" — a different, retired value
under the same name. Rename the Tailwind alias to `ink-2` and delete the ambiguity before somebody
"fixes" a passing colour or trusts a failing one.

### Theme pick

Three catalogue materials fit Atlas's existing navy/electric-blue system almost exactly. Ranked:

- **`vantage`** — *"blue-black ground, a live point cloud of the real thing as the hero's light, a
  sweep that lights it, pale steel ink, Geologica at a light weight, hairline frames with corner
  ticks, one lime signal for what was found."* A radar sweep as the hero, written down as a
  material. **This is the pick for the landing page**, with the lime signal swapped to `--atlas-cyan`.
- **`console`** — graphite in three lightness steps, Atkinson Hyperlegible Mono "for what was
  measured", *"amber for a person and cool blue for an instrument"*. The closest match to the
  authenticated app's actual surfaces; use it as the reference material when auditing app routes.
- **`midnight`** — midnight-blue to every edge, photographs as moonlight, one azure signal. The
  fallback if `vantage`'s point cloud proves too heavy for a Vercel-hosted static page.

Record the pick in `DESIGN.md` so later runs stop re-dealing.

---

## 1. The missing idea: one life list

Atlas currently keeps two registries that never meet.

- **`transport_legs`** — flights *you flew*. Stores `flight_number`, `airline`, origin/dest,
  times, distance, seat class, cost.
- **Skywatch bookmarks / `notable_types`** — aircraft *you spotted*, by hex and type.

A logbook that knows you flew "B6 1227, BOS→FLL" but not **which airframe carried you** is a
travel record, not an aviation record. `docs/STATUS.md` already records the symptom: *"Flight cards
can't show aircraft type or registration (the mockup's `A320 · N834JB`) because `transport_legs`
stores neither."* That is not a UI gap. It is the schema missing the thing an enthusiast actually
collects.

**The spec: an airframe is a first-class entity, and every encounter with one — flown or spotted —
is an entry against it.**

That single change produces, for free, the things no competitor has:

- **Types flown** — "9 of Boeing's 11 widebody variants", with the gaps named.
- **Airframes flown** — the same tail twice is a *fact*, not a duplicate row. "You have flown
  N834JB four times."
- **Oldest airframe flown**, first-flight dates, the airframe you flew that has since been scrapped.
- **Spotted vs flown** on one map and one list: the tail you photographed overhead in 2024 and then
  boarded in 2026 is the single best moment this product can give someone, and today it cannot
  notice it.
- **Operators, liveries, engine variants** — the long tail of completionism that keeps enthusiasts
  in an app for years.

Flighty cannot do this (no spotting). FR24 cannot do this (no logbook). It is the wedge in
`STRATEGY-competitive.md` § "Our wedge", made concrete in the schema instead of in prose.

### Schema additions

```sql
-- One row per real airframe, globally shared (not user-scoped), seeded from the ADS-B
-- aircraft DB already in backend/app/services/aircraft_db.py
airframes
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid()
  icao_hex        CHAR(6) UNIQUE          -- mode-s address; NULL for pre-ADS-B airframes
  registration    VARCHAR UNIQUE NOT NULL -- N834JB
  type_icao       CHAR(4)                 -- A320, B789
  type_name       VARCHAR                 -- "Airbus A320-232"
  manufacturer    VARCHAR
  operator_icao   CHAR(3)
  serial_number   VARCHAR                 -- MSN
  first_flight    DATE
  engine_type     VARCHAR
  photo_url       VARCHAR                 -- planespotters, via aircraft_photos.py
  updated_at      TIMESTAMPTZ DEFAULT now()

-- One row per time a user met an airframe. Replaces Skywatch bookmarks as the life list.
airframe_encounters
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid()
  user_id           VARCHAR REFERENCES users(id) ON DELETE CASCADE
  airframe_id       UUID REFERENCES airframes(id) ON DELETE CASCADE
  kind              VARCHAR NOT NULL        -- 'flown' | 'spotted'
  transport_leg_id  UUID REFERENCES transport_legs(id) ON DELETE CASCADE  -- set when kind='flown'
  occurred_at       TIMESTAMPTZ NOT NULL
  latitude          NUMERIC                 -- where you were, when spotted
  longitude         NUMERIC
  altitude_ft       INTEGER                 -- spotted only
  note              TEXT
  created_at        TIMESTAMPTZ DEFAULT now()
  UNIQUE (user_id, airframe_id, kind, occurred_at)

-- transport_legs gains the airframe link + the two fields the mockup already draws
ALTER TABLE transport_legs
  ADD COLUMN airframe_id UUID REFERENCES airframes(id) ON DELETE SET NULL,
  ADD COLUMN registration VARCHAR,          -- denormalised for the card; airframe_id is the truth
  ADD COLUMN type_icao CHAR(4);
```

Indexes: `airframe_encounters (user_id, kind)`, `airframe_encounters (user_id, airframe_id)`,
`airframes (type_icao)`, `airframes (registration)`.

**`user_id` scoping note.** `airframes` is the one table in Atlas that is deliberately *not*
user-scoped — it is reference data about real objects in the world, like an airport. Every read
path that joins it must still filter `airframe_encounters.user_id`, and the CLAUDE.md rule
("`user_id` filter is mandatory on every query") applies to the encounter table, not the airframe
table. Write this down in `CLAUDE.md` or it will be read as a violation later.

### API additions

```
GET    /api/v1/lifelist                      Summary: counts by type, operator, manufacturer, decade
GET    /api/v1/lifelist/airframes            Paginated; ?kind=flown|spotted|both&type=&operator=
GET    /api/v1/lifelist/types                Types met, with the variants still missing per family
GET    /api/v1/airframes/{registration}      One airframe + this user's encounters with it
POST   /api/v1/lifelist/encounters           Log a spot by hex or registration
GET    /api/v1/lifelist/crossovers           Airframes both spotted AND flown — the payoff endpoint
```

`POST /flights` and `/transport/enrich-flight` gain an optional `registration`; when present, the
backend upserts the airframe (from `aircraft_db.py`, falling back to the ADS-B resolver) and writes
the `flown` encounter in the **same transaction** as the leg. When absent, the leg is logged
without an airframe and the UI offers "add the tail" later — never a guessed registration.

---

## 2. Epics

Ordered by leverage. Each names the files it touches.

### EPIC A — Unblock what is already built  *(prerequisite, small)*
`STATUS.md` has three blockers standing in front of finished code. Nothing below is worth building
on top of them.

- **A1. Bring up MinIO.** Remap host ports to 9002/9003 (`:9000` is taken on the NUC), create the
  `minio_data` volume, update `MINIO_PUBLIC_URL`. Every photo path in `backend/app/routers/photos.py`
  and `services/storage.py` currently fails. → `docker-compose.yml`, `docker-compose.prod.yml`, `.env`
- **A2. Replace the hand-synced bind mount.** `/home/zach/atlas/backend` → `/app` with
  `--reload` means merging a branch does not change what is deployed. Build an image, or at minimum
  document the sync step. → `docker-compose.prod.yml`, a deploy script in `scripts/`
- **A3. Deploy the web frontend.** `NEXT_PUBLIC_API_BASE` still points at `localhost:8000` and
  nothing is hosted. Decide Vercel (per `CLAUDE.md`) vs. a NUC container; the public pages in
  EPIC D need a real origin. → `frontend/.env.local`, Vercel project or `docker-compose.prod.yml`

### EPIC B — The life list  *(the spine; see § 1)*
- **B1.** Alembic migration: `airframes`, `airframe_encounters`, three columns on `transport_legs`.
  **New migration only** — never rewrite one. → `backend/migrations/versions/`
- **B2.** `backend/app/models/airframe.py`, `schemas/airframe.py`, `routers/lifelist.py`.
- **B3.** Airframe upsert service over the existing `services/aircraft_db.py` +
  `services/adsb/resolver.py`. Registration → type → operator, cached in Redis. Cheaper than it
  looks: `aircraft_db.get_aircraft_info(registration)` already takes a registration, and
  `services/adsb/models.py` shows the live feed already carries both `registration` (from `r`) and
  `type` (from `t`) on every aircraft — so a *spotted* encounter needs no extra lookup at all.
- **B4.** **Lift the iOS life list onto the server.** There is no bookmarks table in the backend —
  the Skywatch tables are `skywatch_devices`, `skywatch_preferences`, `aircraft_alerts`,
  `notable_types`, `mil_callsign_prefixes`, `aircraft_tracks`, and nothing else. The life list
  already exists, in `iOS/Atlas/Shared/SpottedStore.swift`, and
  `BookmarksView.swift:79` says what it is: *"Purely client-side (UserDefaults)."* So it is
  device-local, lost on reinstall, and invisible to the web. This is a **one-way import**, not a
  table migration. Two things to know going in: `SpottedAircraft` is keyed on **hex, not
  registration**, so historical spots need hex→registration resolution the stored records do not
  carry; and it stores an *aggregate* (`firstSpottedAt`, `lastSpottedAt`, `spotCount`), so an import
  can honestly reconstruct only two encounters per airframe, not `spotCount` of them. Import the
  two, keep the count in a `note`, and do not invent the rest.
- **B5.** Flight card and detail finally render `A320 · N834JB`.
  → `frontend/src/components/flights/FlightCard.tsx`, `iOS/` flight card
- **B6.** `/lifelist/crossovers` surfaced as a named moment in both clients ("you spotted this tail
  over Quincy in 2024; today you flew it"). This is the one feature worth a push notification.
- **B7.** Integration test at the API boundary **first**, per `CLAUDE.md` § Behavioral Contracts:
  log a leg with a registration → assert the airframe row, the encounter row, and that another
  user's `GET /lifelist` cannot see either.

### EPIC C — Capture  *(P0 in `STRATEGY-competitive.md`; unchanged, restated here for sequencing)*
Manual entry is the ceiling on the logbook, and therefore on the life list.
- **C1.** Wallet boarding-pass scan → `POST /flights` (iOS, `PKAddPassesViewController` + parse).
- **C2.** Flight-number + date entry → `/transport/enrich-flight` → auto-start live tracking and a
  Live Activity. The pieces exist; the wiring does not.
- **C3.** Email parse (Gmail/IMAP) as a backend job. Lowest priority of the three, highest cost.
- **C4.** ADS-B-derived status push: delay, diversion, ETA, in-air, landed — all free from data
  Atlas already has. → `backend/app/services/skywatch/watcher.py`, `rules.py`

### EPIC D — The web surface becomes the public face  *(where Hallmark earns its install)*
`STRATEGY-competitive.md` § CUT already decided the web app is not where live tracking goes. Give
it the job it is actually good at.
- **D1.** Landing page, authored with Hallmark, `vantage` material, real data in the hero (live
  overhead count from the NUC, not an invented number — gate 47c fails invented figures).
  → `frontend/src/app/page.tsx`, `components/landing/`
- **D2.** `GET /f/[token]` — a shareable page for one logged flight: the arc, the airframe, the
  photos, the numbers. Server-rendered, no auth, revocable token.
  → new `frontend/src/app/f/[token]/page.tsx`, `backend/app/routers/share.py`
- **D3.** `GET /u/[handle]` — a public spotter profile: the life list, types met, the map of arcs.
  Opt-in, off by default, per-field privacy in `users.preferences`.
- **D4.** Hallmark audit pass over the four app routes with `sloplint --url`, `--before`/`--kept`
  recorded so the redesign cannot silently drop a handler. Fix `FAIL`s; waive reflexes on the record.
- **D5.** The OKLCH token conversion from § 0, which absorbs the 9 gate-48 literals. **Do the
  gate-34 app-shell scoping in the same pass, and before D1** — the landing page cannot scroll
  until it lands.

### EPIC E — Depth for enthusiasts  *(the long tail; pick from, do not sequence)*
- **E1.** Browse-by-type pages on the web, fed by `/lifelist/types` and the airframe table.
- **E2.** Route statistics the logbook can already answer and does not: longest leg, most-flown
  route, equator and polar crossings, antipodal distance, total time at altitude.
  → `backend/app/routers/stats.py`
- **E3.** Filters and clustering on the live map (`FEATURE-RESEARCH.md` #1, still the top-ranked
  unbuilt item).
- **E4.** Flight trails via the free tar1090 public trace.
- **E5.** Weather overlay (RainViewer tiles).
- **E6.** Data export, JSON + CSV — `CLAUDE.md` Phase 5, and the credible form of "own your data".
  The life list makes the export worth having. → `scripts/export_backup.py`, a new route

---

## 3. Sequencing

| Phase | Contents | Gate to the next |
|---|---|---|
| **P0** | EPIC A (all three) | Photos upload end-to-end; the web app answers on a real origin |
| **P1** | EPIC B (B1–B5, B7) | `GET /lifelist` returns a real life list; cross-user isolation tested |
| **P2** | EPIC D (D1, D5) + B6 | Landing page ships, 0 `FAIL`; crossovers push works |
| **P3** | EPIC C (C1, C2, C4) | A flight logs itself from a boarding pass, with its tail |
| **P4** | EPIC D (D2–D4) | Shared flight and profile pages live |
| **P5** | EPIC E, chosen by appetite | — |

---

## 4. Decisions still open

1. **Where the web app lives.** Vercel (as `CLAUDE.md` says) means the public pages are fast and
   free but the backend must be reachable from the internet; a NUC container keeps everything
   private but makes "share this flight" useless outside Tailscale. **This blocks D2 and D3, and it
   is a product decision, not a technical one.**
2. **Airframe data provenance.** `aircraft_db.py` is good for ADS-B-equipped airframes. Pre-2010
   flights and anything without a mode-S address need a manual-entry path, and the life list will
   look thin until there is one. Accept the gap, or seed from an open registry.
3. **Whether `airframes` is shared or per-user.** Shared is correct and is what § 1 specifies, but
   it is the first non-user-scoped table in the project and `CLAUDE.md` currently reads as
   forbidding it. The rule needs an explicit carve-out for reference data.
4. **How much Hallmark reflex to accept.** Atlas is an instrument: dense mono figures, a hero that
   is a number, tracked labels on map chrome. Several of these are Hallmark reflexes. The default
   should be to waive them on the record in `DESIGN.md`, not to design around them — but somebody
   has to read the first sloplint report and decide, once, rather than per page.
