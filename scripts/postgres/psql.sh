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

if [[ "${1:-}" == "--admin" ]]; then
  shift
  PG_HOST="${PG_HOST:-localhost}"
  PG_PORT="${PG_PORT:-55432}"
  PG_SUPERUSER="${PG_SUPERUSER:-postgres}"
  PG_SUPERUSER_PASSWORD="${PG_SUPERUSER_PASSWORD:-postgres_change_me_from_deployment}"
  exec env PGPASSWORD="$PG_SUPERUSER_PASSWORD" psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_SUPERUSER" -d "${1:-postgres}" "${@:2}"
fi

DB_URL="${DATABASE_URL:-postgresql://${PG_APP_USER:-lingoria}:${PG_APP_PASSWORD:-lingoria_local_change_me}@${PG_HOST:-localhost}:${PG_PORT:-55432}/${PG_APP_DB:-lingoria}}"
exec psql "$DB_URL" "$@"
