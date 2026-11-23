# Synthetic ADS-B contact replay

`adsb_contact_journey.json` is hand-authored, not a traffic capture. Coordinates
are decimal degrees near (0, 0); ages and elapsed times are seconds. Elapsed time
labels the sequence; tests do not sleep or consult a wall clock. `seen` models
message age independently of `seen_pos` (position age).

Run from `backend`:

```sh
python3 -m pytest tests/test_adsb_contact_journey.py tests/test_adsb.py tests/test_adsb_resolver_fallback.py
```

The harness replaces HTTP transport for both real source clients. It checks
fresh → old position with recent messages → missing coordinates → absent contact
→ reacquired contact, plus timeout/503 → empty success → recovery.

These are characterization tests, not acceptance of stale-position handling.
Currently normalization discards source ages and retains old coordinates; an
absent contact disappears on the next successful snapshot. No freshness cutoff,
UI lost-contact grace period, or alert suppression is asserted. The ticket's
referenced ADS-B journey specification was not present in this checkout; those
acceptance rules remain unverified. No production, database, or push services
are exercised.
