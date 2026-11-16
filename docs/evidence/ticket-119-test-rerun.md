# Ticket #119: one-shot test rerun

## Outcome

The suite executed and failed; #23 acceptance remains unknown because this export contains neither `backend/tests/test_adsb_contact_journey.py` nor `backend/tests/fixtures/adsb_contact_journey.json`. No harness or fixture was added, per the ticket's no-test-changes constraint.

Supplied base revision: `89e7b685ae10b1e3d54ff6178342b2c773fc706f`. Revision provenance comes from the task environment, not independent Git verification. This is a source export without Git history; no Git commands were run, and no clean Git worktree or PR-head identity is claimed. Execution on the physical gs65 host and installation of hq runner fix `83241c6` cannot be independently verified from this sandbox.

Prior evidence reviewed: [ticket #81](ticket-81-test-rerun.md). It records missing pytest and no tests executed, and therefore does not establish a passing baseline.

## Execution

Exact command from repository root:

```sh
cd backend && python -m pytest -q
```

One invocation only, with stdout and stderr captured in full to [raw output](ticket-119-pytest-output.txt). A supervising subprocess imposed a 120-second timeout; it was not reached. Exit code: **1**. Start UTC: **2026-11-16T15:49:02.803843+00:00**. Wall time: **4.874 seconds**. Python: **3.12.3**. See [execution metadata](ticket-119-run.json).

Raw final summary line:

```text
2 failed, 151 passed, 46 deselected, 3 errors in 4.15s
```

- Selected: **156**; **153** reached test bodies and **3** errored during setup.
- Passed: **151**.
- Failed: **2**.
- Errored: **3**.
- Skipped: **0**; no skip reasons apply.
- Deselected: **46**, excluded by the existing `backend/pytest.ini` setting `addopts = -m "not integration"`. These infrastructure-dependent tests did not execute and are not passes.

Both failures and all three setup errors end in `PermissionError: [Errno 1] Operation not permitted` while asyncpg attempts a PostgreSQL socket connection:

- FAILED `tests/test_photo_model.py::test_photos_table_exists`
- FAILED `tests/test_transport_model.py::test_transport_table_has_geo_columns`
- ERROR `tests/test_skywatch_llm.py::test_from_text_endpoint_persists_preferences`
- ERROR `tests/test_skywatch_llm.py::test_from_text_endpoint_maps_llm_error_to_503`
- ERROR `tests/test_skywatch_llm.py::test_from_text_endpoint_rejects_empty_text`

These selected tests require PostgreSQL despite not being excluded by the integration marker. No Redis or external-network failure is reported. Network access is disabled; no live probing or service provisioning was performed. No production/customer fixtures were introduced.

## Verification

- Read #81 evidence in full: no prior executable pass evidence.
- Checked #23 harness and fixture paths: both absent, so the requested harness could not execute.
- Ran the required command once: completed within the cap, failed with the counts above; no retry.
- Inspected final summary and all five exception endpoints: all five are PostgreSQL socket permission errors.
- Compared SHA-256 snapshots before and after execution for backend, frontend, iOS, scripts and `.github`, excluding caches: no source-file changes. Application, test, CI and deployment files were not edited; only evidence files were added.
- Clean Git worktree, PR-head CI, physical host identity and QA acceptance: not verified in this export. CI on the eventual PR head remains the merge evidence; no merge or deployment performed.
