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

DB_URL="${DATABASE_URL:-postgresql://${PG_APP_USER:-lingoria}:${PG_APP_PASSWORD:-lingoria_local_change_me}@${PG_HOST:-localhost}:${PG_PORT:-55432}/${PG_APP_DB:-lingoria}}"

mkdir -p backups
timestamp="$(date +%Y%m%d_%H%M%S)"
backup_file="backups/lingoria_${timestamp}.sql"

echo "=================================================================="
echo "Creating backup for database 'lingoria'..."
echo "Target file: $backup_file"
echo "=================================================================="

pg_dump "$DB_URL" "$@" > "$backup_file"

echo "Backup completed: $backup_file ($(du -h "$backup_file" | cut -f1))"
echo "=================================================================="
