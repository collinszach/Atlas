#!/usr/bin/env bash
#
# Deploy Atlas on the NUC. Run ON the NUC, from the checkout:
#
#     ~/atlas/scripts/deploy.sh
#
# Pulls, applies migrations, brings the stack up, and verifies health. Refuses
# to run with uncommitted changes so the deployed tree always matches a commit —
# the hand-synced directory this replaced could never answer "what is running?".
#
# Rollback:
#     git -C ~/atlas checkout <sha> && ~/atlas/scripts/deploy.sh --no-pull
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$REPO_DIR/docker-compose.prod.yml"
HEALTH_URL="http://localhost:8000/health"
PULL=1

for arg in "$@"; do
  case "$arg" in
    --no-pull) PULL=0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

cd "$REPO_DIR"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
fail() { printf '\n\033[1;31mFAILED:\033[0m %s\n' "$*" >&2; exit 1; }

command -v docker >/dev/null || fail "docker not found"
[ -f "$COMPOSE_FILE" ] || fail "missing $COMPOSE_FILE"
[ -f "$REPO_DIR/.env" ] || fail "missing $REPO_DIR/.env (never committed; see .env.example)"

compose() { docker compose -f "$COMPOSE_FILE" --env-file "$REPO_DIR/.env" "$@"; }

# --- 1. sync -----------------------------------------------------------------
BEFORE="$(git rev-parse HEAD)"
if [ "$PULL" -eq 1 ]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    fail "working tree is dirty — commit or stash on the NUC before deploying"
  fi
  log "Pulling $(git rev-parse --abbrev-ref HEAD)"
  git pull --ff-only
fi
AFTER="$(git rev-parse HEAD)"

if [ "$BEFORE" = "$AFTER" ]; then
  log "Already at $(git log -1 --format='%h %s')"
else
  log "Updated $(git rev-parse --short "$BEFORE") -> $(git rev-parse --short "$AFTER")"
  git --no-pager log --oneline "$BEFORE..$AFTER" | sed 's/^/    /'
fi

# --- 2. images ---------------------------------------------------------------
# The backend bind-mounts its source, so this only matters when the Dockerfile
# or its dependencies changed. Cheap and cached when they didn't.
log "Building images"
compose build atlas-backend

# --- 3. bring the stack up ---------------------------------------------------
log "Starting stack"
compose up -d

log "Waiting for the database"
for _ in $(seq 1 30); do
  if compose exec -T atlas-db pg_isready -U "${POSTGRES_USER:-atlas}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# --- 4. migrations -----------------------------------------------------------
# Runs inside the backend container, which is the only thing that can reach
# atlas-db (it is not published to the host).
log "Applying migrations"
CURRENT_REV="$(compose exec -T atlas-backend alembic current 2>/dev/null | tail -1 || true)"
echo "    before: ${CURRENT_REV:-unknown}"
compose exec -T atlas-backend alembic upgrade head
echo "    after:  $(compose exec -T atlas-backend alembic current 2>/dev/null | tail -1 || echo unknown)"

# --- 5. verify ---------------------------------------------------------------
log "Checking health"
for attempt in $(seq 1 20); do
  if curl -fsS -m 5 "$HEALTH_URL" >/dev/null 2>&1; then
    printf '    healthy after %ss\n' "$((attempt * 2))"
    HEALTHY=1
    break
  fi
  sleep 2
done

if [ "${HEALTHY:-0}" -ne 1 ]; then
  echo
  compose logs --tail 40 atlas-backend
  fail "backend did not become healthy — logs above. Roll back with:
    git -C $REPO_DIR checkout $BEFORE && $REPO_DIR/scripts/deploy.sh --no-pull"
fi

# A healthy /health only proves the process is up; this proves it can still
# reach an ADS-B source, which is the thing that silently broke before.
log "Checking the ADS-B source"
if compose exec -T atlas-backend python -c "
import asyncio, sys
from app.services.adsb.resolver import DataSourceResolver
async def main():
    try:
        ac = await DataSourceResolver().get_aircraft(40.64, -73.78, 40)
    except Exception as exc:
        print(f'    ADS-B source FAILING: {exc}'); sys.exit(1)
    print(f'    ok — {len(ac)} aircraft')
asyncio.run(main())
"; then :; else
  echo "    (deploy succeeded; the ADS-B source needs attention)"
fi

log "Deployed $(git log -1 --format='%h %s')"
compose ps --format 'table {{.Name}}\t{{.Status}}'
