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
echo "PostgreSQL Databases Summary"
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
  -d "postgres" \
  -c "
SELECT
    d.datname AS \"Database Name\",
    pg_catalog.pg_get_userbyid(d.datdba) AS \"Owner\",
    pg_catalog.pg_encoding_to_char(d.encoding) AS \"Encoding\",
    pg_size_pretty(pg_catalog.pg_database_size(d.datname)) AS \"Size\",
    (SELECT count(*) FROM pg_stat_activity WHERE datname = d.datname) AS \"Active Connections\"
FROM pg_catalog.pg_database d
WHERE d.datistemplate = false
ORDER BY pg_catalog.pg_database_size(d.datname) DESC;
"
