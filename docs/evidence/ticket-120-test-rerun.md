# Ticket #120: reconciliation rerun evidence

## Scope and revision

Supplied base revision: `89e7b685ae10b1e3d54ff6178342b2c773fc706f`.
Executed against that source export plus the two #24 test-file changes in this
submission. The export lacked both the distance test file and reconciliation
function; restored them from the ticket's supplied diff. No #23 changes included.
No Git commands were run: history is unavailable by environment contract, so a
clean Git worktree and PR-head identity cannot be independently verified here.
Host identity (gs65) is supplied context, not independently verified.

Read the complete prior `ticket-81-test-rerun.md`: it recorded no executed tests
because pytest was absent and identified the same missing #24 cases. That is
historical startup evidence, not a passing result.

## Execution

Exact command: `cd backend && python -m pytest -q`

One suite run, 180-second cap; completed without timeout in approximately 4.7
seconds (pytest reports 3.95 seconds). Exit status: 1.
A temporary observer plugin outside the repository recorded pytest reports and
deselected node IDs; it did not alter test selection or outcomes. PYTHONPATH
included its /tmp location and the backend directory. No dependencies installed.
Full combined stdout/stderr is in [ticket-120-pytest.txt](ticket-120-pytest.txt).

Raw final summary line:

```text
2 failed, 156 passed, 53 deselected, 3 errors in 3.95s
```

Selected: 161 tests; 158 reached their test body (156 passed, 2 failed), and 3
errored during setup. Skipped: **0**. Deselected: **53**, not skipped or passed.

## Reconciliation result

All five offline spherical distance cases passed: coincident, equatorial-degree,
antimeridian, over-pole, antipodal. Each checks both directions at one metre
tolerance using mean radius 6371.0088 km.

All seven API reconciliation cases were deselected by the repository's existing
`backend/pytest.ini` default `addopts = -m "not integration"`: duration-precedence,
estimated-time, zero-duration, duration-only, unknown-time, round-after-sum,
mixed-flights. These would use synthetic users and PostgreSQL, including a second
user to test isolation. Duration precedence, time-in-air, aggregate distance and
user isolation therefore remain **unverified**. No integration rerun was made.

## Failures and errors

Two failures and three setup errors attempted PostgreSQL connections and raised
`PermissionError: [Errno 1] Operation not permitted` at socket creation. This
shows sandbox socket denial, not whether a PostgreSQL service is running.
No failure was attributed to Redis or an external network service.

- `tests/test_photo_model.py::test_photos_table_exists` (call).
- `tests/test_skywatch_llm.py::test_from_text_endpoint_persists_preferences` (setup).
- `tests/test_skywatch_llm.py::test_from_text_endpoint_maps_llm_error_to_503` (setup).
- `tests/test_skywatch_llm.py::test_from_text_endpoint_rejects_empty_text` (setup).
- `tests/test_transport_model.py::test_transport_table_has_geo_columns` (call).

## Deselected tests

Every node below was excluded by the default integration marker filter, rather
than attempted and skipped for unavailable services. No runtime skips occurred.

- `tests/test_flight_enrich.py::test_overhead_resilient_to_enrichment_failures`
- `tests/test_flight_enrich.py::test_stats_new_fields_with_flight_legs`
- `tests/test_flight_enrich.py::test_stats_hours_fallback_from_distance`
- `tests/test_map_arcs.py::test_map_arcs_returns_flight_with_geo`
- `tests/test_map_arcs.py::test_map_arcs_excludes_flights_without_geo`
- `tests/test_map_arcs.py::test_map_arcs_user_isolation`
- `tests/test_photos.py::test_upload_photo`
- `tests/test_photos.py::test_upload_rejects_unsupported_type`
- `tests/test_photos.py::test_list_photos_empty`
- `tests/test_photos.py::test_list_photos_after_upload`
- `tests/test_photos.py::test_delete_photo`
- `tests/test_photos.py::test_set_cover_photo`
- `tests/test_photos.py::test_cannot_upload_to_another_users_flight`
- `tests/test_skywatch_router.py::test_register_device`
- `tests/test_skywatch_router.py::test_update_location_without_device_requires_registration`
- `tests/test_skywatch_router.py::test_update_location_after_device_registration`
- `tests/test_skywatch_router.py::test_invalid_location_rejected`
- `tests/test_skywatch_router.py::test_get_preferences_creates_defaults`
- `tests/test_skywatch_router.py::test_update_preferences`
- `tests/test_skywatch_router.py::test_invalid_preference_radius_rejected`
- `tests/test_skywatch_router.py::test_overhead_returns_aircraft_with_matches`
- `tests/test_skywatch_router.py::test_overhead_adsb_failure_returns_502`
- `tests/test_skywatch_router.py::test_overhead_invalid_coordinates_rejected`
- `tests/test_skywatch_router.py::test_alerts_empty_by_default`
- `tests/test_skywatch_router.py::test_preferences_user_isolation`
- `tests/test_skywatch_tracks.py::test_records_one_row_per_aircraft`
- `tests/test_skywatch_tracks.py::test_second_observer_in_same_cycle_is_deduped`
- `tests/test_skywatch_tracks.py::test_same_aircraft_in_a_later_cycle_is_a_new_point`
- `tests/test_skywatch_tracks.py::test_positionless_contacts_are_skipped`
- `tests/test_skywatch_tracks.py::test_duplicate_hex_within_one_batch_collapses`
- `tests/test_skywatch_tracks.py::test_prune_removes_only_expired_rows`
- `tests/test_skywatch_tracks.py::test_alert_interaction_records_opened`
- `tests/test_skywatch_tracks.py::test_alert_interaction_is_idempotent`
- `tests/test_skywatch_tracks.py::test_cannot_record_interaction_on_another_users_alert`
- `tests/test_skywatch_tracks.py::test_rejects_unknown_action`
- `tests/test_skywatch_tracks.py::test_tisb_contact_is_recorded`
- `tests/test_skywatch_tracks.py::test_one_overlong_identifier_does_not_discard_the_batch`
- `tests/test_stats.py::test_stats_empty_user`
- `tests/test_stats.py::test_stats_with_data`
- `tests/test_stats.py::test_logbook_distance_and_time_reconciliation[duration-precedence]`
- `tests/test_stats.py::test_logbook_distance_and_time_reconciliation[estimated-time]`
- `tests/test_stats.py::test_logbook_distance_and_time_reconciliation[zero-duration]`
- `tests/test_stats.py::test_logbook_distance_and_time_reconciliation[duration-only]`
- `tests/test_stats.py::test_logbook_distance_and_time_reconciliation[unknown-time]`
- `tests/test_stats.py::test_logbook_distance_and_time_reconciliation[round-after-sum]`
- `tests/test_stats.py::test_logbook_distance_and_time_reconciliation[mixed-flights]`
- `tests/test_transport.py::test_create_flight_leg`
- `tests/test_transport.py::test_list_transport_legs`
- `tests/test_transport.py::test_update_transport_leg`
- `tests/test_transport.py::test_delete_transport_leg`
- `tests/test_transport.py::test_transport_user_isolation`
- `tests/test_transport.py::test_enrich_flight_no_key_returns_503`
- `tests/test_transport.py::test_enrich_flight_requires_auth`

## Verification

- Full backend suite: completed once; failed with the exact counts above.
- Observer reports: five new geometry cases passed; seven new API cases deselected;
  zero skipped reports. Full deselection list recorded above.
- Test review: expectations match supplied #24 cases and current stats calculation;
  fixture seeds both synthetic users and deletes them with cascade cleanup.
- CI/deployment/application/configuration files: untouched by this task.
- Clean worktree / commit creation: unavailable in the source-export environment;
  supplied base revision cited instead. PR publication not performed here.
- CI on the resulting PR head: pending; remains the required merge evidence.
