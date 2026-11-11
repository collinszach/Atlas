# Ticket #81: test execution evidence

Captured UTC: 2026-11-11T01:03:49.125303+00:00
Workspace: `/tmp/hq-code-rm5qi77z/repo`
OS: `Linux-6.14.0-36-generic-x86_64-with-glibc2.39`
Python executable requested: `/usr/bin/python3`

## Result

BLOCKED. No intended commit hash could be established and no clean Git worktree could be created. The supplied `.git` directory is empty. These attempts ran against the supplied source export, not a verified PR revision. No test outcome is claimed.

Passed: unknown; failed: unknown; skipped: unknown. No tests executed: both pytest invocations exited before collection. Exit code 1 below is a command startup failure, not a failed test count.

No production/customer data, database, or external application services were used by the test commands. No dependencies were installed. No merge or deployment was attempted. Only this evidence document was added; tests, CI, deployment, and application files were unchanged.

## Revision recovery attempt

GitHub connector calls: `get_pr_info(repository_full_name="collinszach/Atlas", pr_number=5)` and the same call with `pr_number=6`. Both returned the following verbatim blocker:

```text
This app connection requires reauthentication. Reconnect the app and try again.
```

## Referenced test presence

- `backend/tests/fixtures/adsb_contact_journey.json`: absent.
- `backend/tests/test_adsb_contact_journey.py`: absent.
- `backend/tests/test_logbook_distance.py`: absent.
- `backend/tests/test_stats.py`: present; #24 test function `test_logbook_distance_and_time_reconciliation` absent.

## Full command output

### Revision

Working directory: `/tmp/hq-code-rm5qi77z/repo`
Command: `git rev-parse HEAD`
Exit code: 128

```text
fatal: not a git repository (or any of the parent directories): .git
```

### Clean status

Working directory: `/tmp/hq-code-rm5qi77z/repo`
Command: `git status --porcelain=v1`
Exit code: 128

```text
fatal: not a git repository (or any of the parent directories): .git
```

### Worktrees

Working directory: `/tmp/hq-code-rm5qi77z/repo`
Command: `git worktree list --porcelain`
Exit code: 128

```text
fatal: not a git repository (or any of the parent directories): .git
```

### Environment

Working directory: `/tmp/hq-code-rm5qi77z/repo`
Command: `python3 --version`
Exit code: 0

```text
Python 3.12.3
```

### Pytest availability

Working directory: `/tmp/hq-code-rm5qi77z/repo`
Command: `python3 -m pytest --version`
Exit code: 1

```text
/usr/bin/python3: No module named pytest
```

### ADS-B requested tests

Working directory: `/tmp/hq-code-rm5qi77z/repo/backend`
Command: `python3 -m pytest tests/test_adsb_contact_journey.py tests/test_adsb.py tests/test_adsb_resolver_fallback.py`
Exit code: 1

```text
/usr/bin/python3: No module named pytest
```

### Logbook requested tests

Working directory: `/tmp/hq-code-rm5qi77z/repo/backend`
Command: `python3 -m pytest tests/test_logbook_distance.py tests/test_stats.py -m 'integration or not integration' -v`
Exit code: 1

```text
/usr/bin/python3: No module named pytest
```

## Next execution prerequisite

Provide a Git checkout containing the intended #23/#24 revisions and a test environment with the declared backend dependencies. Resolve the intended immutable revision before executing tests. Integration tests additionally require an isolated synthetic test database; no live database should be substituted.
