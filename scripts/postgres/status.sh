#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f .env ]]; then
  echo "Error: Missing .env file. Run 'make init-config' first." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-55432}"
PG_SUPERUSER="${PG_SUPERUSER:-postgres}"
PG_SUPERUSER_PASSWORD="${PG_SUPERUSER_PASSWORD:-postgres_change_me_from_deployment}"

echo "=================================================================="
echo "PostgreSQL Health & Connection Status"
echo "Host: $PG_HOST:$PG_PORT"
echo "=================================================================="

if command -v pg_isready >/dev/null 2>&1; then
  if ! pg_isready -h "$PG_HOST" -p "$PG_PORT" >/dev/null 2>&1; then
    echo "Status: [OFFLINE] (Cannot reach PostgreSQL at $PG_HOST:$PG_PORT)"
    echo "Tip: Run 'make deploy-postgres' in lingoria-platform-deployment."
    exit 0
  fi
  echo "Status: [ONLINE] PostgreSQL is accepting connections."
fi

if ! PGPASSWORD="$PG_SUPERUSER_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPERUSER" -d "postgres" -c "SELECT 1;" >/dev/null 2>&1; then
  echo "Status: [OFFLINE or AUTH FAILED] Cannot authenticate as '$PG_SUPERUSER' at $PG_HOST:$PG_PORT."
  echo "Tip: Verify PG_SUPERUSER_PASSWORD in .env."
  exit 0
fi

PGPASSWORD="$PG_SUPERUSER_PASSWORD" psql \
  -h "$PG_HOST" \
  -p "$PG_PORT" \
  -U "$PG_SUPERUSER" \
  -d "postgres" \
  -c "
SELECT
    version() AS \"PostgreSQL Version\",
    now() - pg_postmaster_start_time() AS \"Uptime\",
    (SELECT setting FROM pg_settings WHERE name = 'max_connections') AS \"Max Connections\",
    (SELECT count(*) FROM pg_stat_activity) AS \"Current Connections\",
    (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') AS \"Active Queries\";
"
