# Product

## Register

product

## Users
Two overlapping people, often the same person. The **spotter**: someone who looks up, wonders
what that is, and wants to know the type, the operator and where it's going — who keeps a life
list and wants to be told when something rare, military or in trouble is overhead. The
**frequent flyer**: someone who has flown hundreds of segments and wants them recorded with
data fidelity, not a social feed. They use Atlas on the couch while something interesting
crosses the sky, at a desk to log and review what they've flown, and at the airport to see
what's departing. The job: know what's above you right now, and see the shape of everywhere
you've flown.

## Product Purpose
Atlas is a personal flight radar and logbook — part live instrument, part archive. It tracks
aircraft overhead in real time (type, operator, route, altitude, why it's notable) and records
the flights you've personally flown as great-circle arcs with photos, distance and time in the
air. Success is someone opening Atlas instead of Flightradar24 — because it's free, has no ads,
tells them what's *interesting* rather than just what's there, and because it also holds their
own flying, which no tracker does.

## Brand Personality
Mission control meets an explorer's logbook. Precise, earned, quietly authoritative. The voice
of a seasoned navigator, not an aviation influencer. Three words: cartographic, exacting,
atmospheric. The interface should feel like instrumentation you trust — every number real, every
line on the map a flight that actually happened.

## Anti-references
- Instagram / travel-blog pastel grids. No bright gradients, no rounded-everything, no emoji-as-UI.
- Ad-supported tracker clutter: banner strips, paywalled aircraft details, upsell interstitials,
  a map you can barely see under chrome. Atlas is free and shows the sky, not the store.
- Generic SaaS dashboards: one big number floating in an otherwise empty card, identical card
  grids at identical sizes, tiny uppercase tracked eyebrows over every section. (Atlas does use a
  hero stat — but earned, in a bento of varied tiles, never as the whole design.)
- Raw unresolved codes as the interface — `A320`, `JBU`, `7700` with no human reading.
- Cream/sand/parchment "warm editorial" near-whites. The charge here is electric blue → cyan on
  deep navy, carried by accent, glass and type, never by a beige body.

## Design Principles
1. **The map is the product.** The live sky and the arc map are the home surfaces and the
   emotional core; every other screen is in service of putting more truth on them.
2. **Data is earned, so show it like it matters.** Distances, hours in air, flight numbers,
   altitudes — present them with the gravity of an instrument readout, in mono, precise,
   never inflated.
3. **Surface what's interesting.** A sky full of identical airliners is noise; the military
   transport, the rare type and the 7700 squawk are the signal. Atlas ranks, it doesn't dump.
4. **Atmosphere over ornament.** Depth, texture and motion come from cartographic materials
   (graticules, contours, arcs, deep field) and glass used where it does work — never decoration
   on flat chrome.
5. **Restraint is the luxury.** Accent is rare and meaningful; most of the surface is deep navy
   and ink. Color marks signal (military / rare / emergency / your own flights), never decoration.
6. **Legible under any light.** Dark cartographic, but body text always clears 4.5:1 —
   instruments you can read at a glance, not a mood board you squint at.

## Accessibility & Inclusion
WCAG 2.1 AA. Body text ≥4.5:1 on the navy field (the muted slate `#64748b` fails on `#0a0e1a` and
must not carry body copy). Full reduced-motion alternatives for arc, globe and radar-sweep
animation. Map encodings — aircraft classification (military / rare / emergency / normal) and
your own flight arcs — must be distinguishable for color-blind users via shape, glyph or label,
not hue alone. Emergency state is never signalled by red alone. Full keyboard navigation for the
app shell and all forms; VoiceOver labels on every map glyph and route (`"BOS to FLL"`), since a
dashed line between two codes is meaningless to a screen reader.
