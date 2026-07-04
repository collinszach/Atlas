# Atlas — competitive strategy (vs Flightradar24, Plane Finder, Flighty)

_Goal: a better app than FR24/Plane Finder (live tracking) and Flighty (personal flight
companion), by being the one product that does all three — free, no ads, own-your-data._

## Who we're actually fighting
- **Flightradar24** — the leader. Wins on **coverage** (huge receiver network + Aireon
  satellite ADS-B for oceans), data depth, historical playback, brand. Loses on paywall creep,
  ads, clutter. We will **not** out-coverage them.
- **Plane Finder** — polished niche tracker: AR, 3D, playback, airport boards, cheap sub.
  Smaller network. We already match most of its surface.
- **Flighty** — _not_ a radar app. A **personal flight companion**: auto-imports your flights
  (Wallet/email), best-in-class Live Activities + status push (delay/gate/diversion/baggage),
  beautiful stats. Leans on paid schedule data. We out-feature it on live tracking + spotting;
  it out-features us on **capture and notifications**.

## Our wedge (the only app that combines all three)
1. Spotter-grade **live tracking** (FR24-class map, AR, type-forward).
2. Personal **logbook + stats** (Flighty-class).
3. **Skywatch ambient intelligence** — server-side LLM pushes when something *you* care about is
   overhead, app-closed. Nobody else has this.
Plus the moat: **free, no ads, self-hosted, own-your-data**, optional home ADS-B receiver.

---

## CUT (focus is the strategy)
- **Global/oceanic coverage ambition.** We can't match FR24's receiver network or satellite ADS-B.
  Be honest in-UI about coverage gaps; don't build a receiver network. (Optional personal receiver
  is a *feature*, not a coverage play.)
- **Deep historical playback (to 2011).** Storage-heavy FR24/PF paywall feature. Keep recent live
  trail only; drop the rest.
- **3D globe / cockpit.** Low ROI. Stays cut.
- **Apple Watch app.** Defer until the core is excellent.
- **Full airport departure/arrival boards.** Needs a paid schedule API. Keep the free "live on the
  ground + nearby" view; cut full boards unless we commit to exactly one status provider (see Build #2).
- **The web travel-tracker app.** The Next.js frontend is a separate travel/photos/trips product
  with **zero flight features** — it competes with nothing we care about and splits focus. Cut its
  app scope; repurpose web as **landing + shareable public flight pages** (Build #6).
- **Heavy trip-journal / photo-album scope.** Overlaps no competitor and dilutes the flight focus.
  Keep the logbook + stats (the Flighty-class differentiator); shed the rest.

## BUILD (what makes us win)
Identity to ship toward: **"Flighty's polish + FR24's live map + a spotter's brain, free and yours."**

1. **Auto-import your flights (P0 — beats Flighty's moat).** Wallet boarding-pass scan, email
   parse (Gmail/IMAP), or flight-number entry → auto-populate the logbook **and** auto-start live
   tracking + a Live Activity. We already have live data, track-a-flight, and Live Activities; the
   missing piece is *capture*. Highest leverage single build.
2. **Status notifications that match Flighty (P0).** Delay / diversion / gate / baggage for flights
   you're tracking or flying. Derive what we can from **ADS-B for free** (delay, diversion, ETA,
   in-air/landed); add **one** paid status API only for gate/baggage if it proves worth it.
3. **Make the live map decisively better (P1).** Declutter shipped; add filter presets, "most
   interesting overhead right now," shareable live map state. Keep it the calm instrument FR24 isn't.
4. **Double down on the spotter wedge (P1).** Type-forward (shipped) + AR "what is that" + browse-
   by-type + rarity/notable. This is where we beat Flighty (no spotting) and out-character FR24/PF.
5. **Make "free / no ads / yours" a loud pillar (P1).** Optional **home ADS-B receiver** = "your own
   radar." None of them can credibly claim own-your-data.
6. **Web = landing + shareable public pages (P1).** "Share this flight" live links and a public
   spotter profile of your logbook/stats. The right job for the web surface (replaces the cut
   travel-tracker app).
7. **Polish to Flighty's bar (P2).** Impeccable passes on map/detail/stats; home-screen widgets.

## Suggested next milestone (sequenced)
- **P0:** Auto-import (Wallet + flight number) → logbook + auto-track · ADS-B-derived status push.
- **P1:** Home-screen widgets · shareable live links + public profile (web refocus) · map presets ·
  AR/type expansion · "your own radar" receiver onboarding.
- **P2:** Design polish pass · optional paid status provider for gate/baggage.
- **Cut/park:** oceanic coverage, deep playback, 3D, Watch, full paid boards, web travel-tracker,
  trip-journal/photos.
