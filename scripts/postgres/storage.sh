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
echo "PostgreSQL Storage & Table Sizes Diagnostics"
echo "Target Database: $TARGET_DB ($PG_HOST:$PG_PORT)"
echo "=================================================================="

if ! PGPASSWORD="$PG_SUPERUSER_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPERUSER" -d "postgres" -c "SELECT 1;" >/dev/null 2>&1; then
  echo "Status: [OFFLINE or AUTH FAILED] Cannot reach PostgreSQL at $PG_HOST:$PG_PORT."
  echo "Tip: Run 'make deploy-postgres' in lingoria-platform-deployment."
  exit 0
fi

PGPASSWORD="$PG_SUPERUSER_PASSWORD" psql \
  -h "$PG_HOST" \
  -p "$PG_PORT" \
  -U "$PG_SUPERUSER" \
  -d "$TARGET_DB" \
  -f "sql/dba/check_table_sizes.sql" 2>/dev/null || {
    echo "Notice: Database '$TARGET_DB' is not yet initialized. Please run: make pg-init"
  }

echo "=================================================================="
