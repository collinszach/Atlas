# SPEC — Skywatch (Ambient Aircraft Awareness)

_Status: draft v1 · Owner: PM/Architect (Opus) · 2026-06-13_

## One-liner
Atlas knows what's in the sky around you and taps you on the shoulder only when something
you care about is overhead — rare airframes, military/government, or aircraft in distress.
The Flighty-beating feature: a **server-side watch** that fires even when the app is closed.

## Why this shape
The user chose: **Both** data sources, triggers = **rare/unusual types + military & government
+ emergencies & oddities**, **APNs push**, local LLM used **per-task**. The "around me" framing
means the system is keyed to the phone's location, but for true ambient alerting the heavy polling
runs **server-side** against the device's last-known location so it works while the app is suspended.

## Architecture (hybrid, server-driven watch)
```
 iOS (CoreLocation) ──significant-change/bg-refresh──▶ POST /skywatch/location
                                                          │
 NUC dump1090 (local, Tailscale) ─┐                       ▼
 airplanes.live API (network) ────┴─▶ ADS-B service ─▶ enrich ─▶ rule engine ─▶ dedupe
                                                                                   │
                                                              APNs push  ◀─────────┘
 iOS live radar (foreground) ◀── GET /skywatch/overhead
```
- **Server-side watcher** (APScheduler job per active device): every N seconds, for each device
  with a recent location + enabled triggers, query ADS-B around that point, evaluate rules,
  dedupe, and push. This is what makes it ambient.
- **Foreground live radar**: the iOS app also calls `/skywatch/overhead` directly for a live
  "what's around me right now" map view.

## Data sources (Both)
- **Network (primary, works anywhere):** `airplanes.live` REST — `GET /v2/point/{lat}/{lon}/{radius_nm}`
  (free, no key, ~1 req/s). Returns hex, flight/callsign, lat/lon, alt, gs, track, `t` (type),
  `r` (registration), `squawk`, `dbFlags` (bit 1 = military). Fallback: adsb.fi / OpenSky (account).
- **Local (rich, home only):** read dump1090/readsb `aircraft.json` over Tailscale
  (e.g. `http://nuc.<tailnet>.ts.net:8080/data/aircraft.json`). Same fields. Preferred when the
  device is within range of the home receiver; network API used otherwise. Receiver hardware
  (RTL-SDR) is a user-side dependency; the integration degrades gracefully if absent.
- A `DataSourceResolver` merges/dedupes by ICAO hex, preferring local when both have a target.

## "Special" rule engine
Each aircraft is enriched then scored against enabled triggers. Triggers (user-chosen):
1. **Rare / unusual types** — match ADS-B type code `t` against a curated `notable_types` table
   (A388, B748, A124/A225, AN-2, warbirds, Concorde-era, government VIP frames, etc.) + a
   `private-jet` heuristic (bizjet type codes). Tunable rarity tiers.
2. **Military & government** — `dbFlags` military bit, known mil callsign prefixes (e.g. RCH, RRR),
   mil squawk blocks, and a `gov_registrations` list (head-of-state airframes).
3. **Emergencies & oddities** — squawk `7700` (general), `7600` (radio fail), `7500` (hijack);
   plus heuristics: very low altitude away from a known airport, holding patterns, rapid descent.
- **Watchlist (extensible, default-off):** named airlines / type codes / exact registrations or
  flight numbers the user adds later. Engine supports it now even though the user didn't select it.
- **Per-trigger config:** radius (default 30 km), altitude ceiling, min rarity tier, quiet hours,
  cooldown so the same hex isn't re-alerted within a window (default 6 h).

## Local LLM (per-task, over Tailscale)
Used where it saves Claude tokens at runtime and adds intelligence — never required:
- **Natural-language preferences:** "alert me for anything old, military, or in trouble" → compiled
  to rule config. (One call on save, cached.)
- **Notification copy:** turn a structured match into a one-line, human alert
  ("A Soviet-era An-124 is passing 8 km north at 31,000 ft").
- **Ambiguous classification:** when type/rarity is unclear.
Endpoint/model TBD from user (Ollama or OpenAI-compatible). All runtime LLM work targets the
local model; Claude is reserved for the build, not the hot path.

## Backend (FastAPI) — new domain
- **Models:** `device` (id, user_id, apns_token, platform, last_lat/lng, last_seen, push_enabled),
  `skywatch_preference` (user_id, trigger flags, radius_km, alt_ceiling_ft, quiet_hours, cooldown,
  watchlist JSONB, nl_prompt), `aircraft_alert` (user_id, hex, callsign, type, reg, trigger, score,
  lat/lng/alt, distance_km, message, sent_at). Plus seed tables: `notable_types`, `mil_callsign_prefixes`.
- **Services:** `adsb/` (network client + local dump1090 client + resolver), `skywatch/rules.py`
  (enrich + score), `skywatch/apns.py` (token-based APNs, .p8/JWT), `skywatch/watcher.py`
  (APScheduler job).
- **Endpoints (`/api/v1/skywatch/...`):** `POST /devices` (register APNs token),
  `POST /location` (update last-known), `GET /overhead?lat&lon&radius` (live list),
  `GET|PUT /preferences`, `GET /alerts` (history), `POST /preferences/from-text` (NL → rules via local LLM).
- **Privacy:** location stored as last-known only, user-scoped, deletable; all queries `WHERE user_id`.

## iOS (SwiftUI)
- **Skywatch tab:** live radar map (aircraft around you, tap for detail), a "what's special now" strip,
  alert feed (history), preferences screen (trigger toggles, radius slider, quiet hours, NL prompt box).
- **CoreLocation:** significant-location-change + background app refresh → `POST /skywatch/location`.
- **Push:** register for APNs, send token to `/skywatch/devices`, deep-link notification → aircraft detail.
- **Live Activity (later):** "Interesting aircraft inbound" countdown when a high-score target approaches.

## Phasing
- **P1 — Backend foundation** (no credentials needed): models + migration, airplanes.live client,
  rules engine v1 + seed tables, `/overhead` + preferences + devices endpoints, APNs sender scaffold
  (no key yet), tests. ← **start here**
- **P2 — iOS live radar + preferences** (foreground, via `/overhead`).
- **P3 — Server-side watcher + APNs push** (needs Apple Developer key + background location).
- **P4 — Local receiver merge + local-LLM NL prefs + Live Activities.**

## Team & model assignment (token-efficient)
- **PM / Architect — Opus (me):** spec, integration, APNs/cert decisions, review. Only Opus seat.
- **Backend engineer — Sonnet:** services, models, endpoints, tests (P1, P3 backend).
- **iOS engineer — Sonnet:** SwiftUI, CoreLocation, push (P2, P3 client).
- **Data/rules curator — Haiku:** seed the notable-types / mil-prefix / squawk tables (mechanical).
- **Local-LLM bridge — Sonnet/Haiku:** wired when the endpoint is provided.
Runtime intelligence runs on the **local LLM**, so steady-state operation costs ~zero Claude tokens.

## What we need from the user
**Build-time (soon, to go past P1):**
- Network ADS-B: confirm default `airplanes.live` (free, no key) or provide a key for adsbexchange/OpenSky.
- Local LLM: Tailscale URL + model name + API flavor (Ollama / OpenAI-compatible), if we should wire it.
- dump1090: the NUC's `aircraft.json` URL over Tailscale, and whether a receiver exists yet.

**Live-time (before push actually sends, P3):**
- Apple Developer **Team ID**, APNs **Key ID** + **.p8 auth key**. Bundle id is `com.atlas.app`.
