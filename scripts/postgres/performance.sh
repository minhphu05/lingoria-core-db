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
TARGET_DB="${PG_APP_DB:-lingoria}"

echo "=================================================================="
echo "PostgreSQL DBA Performance Diagnostics"
echo "Target Database: $TARGET_DB ($PG_HOST:$PG_PORT)"
echo "=================================================================="

if ! PGPASSWORD="$PG_SUPERUSER_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPERUSER" -d "postgres" -c "SELECT 1;" >/dev/null 2>&1; then
  echo "Status: [OFFLINE or AUTH FAILED] Cannot reach PostgreSQL at $PG_HOST:$PG_PORT."
  echo "Tip: Run 'make deploy-postgres' in lingoria-platform-deployment."
  exit 0
fi

echo "1. Buffer Cache Hit Ratio:"
PGPASSWORD="$PG_SUPERUSER_PASSWORD" psql \
  -h "$PG_HOST" \
  -p "$PG_PORT" \
  -U "$PG_SUPERUSER" \
  -d "$TARGET_DB" \
  -c "
SELECT
    datname,
    blks_hit,
    blks_read,
    ROUND(blks_hit::numeric / NULLIF(blks_hit + blks_read, 0) * 100, 2) AS \"Cache Hit % (Target: > 99%)\"
FROM pg_stat_database
WHERE datname = '$TARGET_DB';
" 2>/dev/null || echo "Database '$TARGET_DB' not yet initialized."

echo ""
echo "2. Active Contention & Blocking Locks:"
PGPASSWORD="$PG_SUPERUSER_PASSWORD" psql \
  -h "$PG_HOST" \
  -p "$PG_PORT" \
  -U "$PG_SUPERUSER" \
  -d "$TARGET_DB" \
  -f "sql/dba/check_active_locks.sql" 2>/dev/null || true

echo ""
echo "3. Active Slow Queries (> 2s):"
PGPASSWORD="$PG_SUPERUSER_PASSWORD" psql \
  -h "$PG_HOST" \
  -p "$PG_PORT" \
  -U "$PG_SUPERUSER" \
  -d "$TARGET_DB" \
  -f "sql/dba/check_slow_queries.sql" 2>/dev/null || true
echo "=================================================================="
