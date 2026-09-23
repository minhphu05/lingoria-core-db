#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if [[ ! -f .env ]]; then
  echo "Error: Missing .env file. Run 'make init-config' first." >&2
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

DB_URL="${DATABASE_URL:-postgresql://${PG_APP_USER:-lingoria}:${PG_APP_PASSWORD:-lingoria_local_change_me}@${PG_HOST:-localhost}:${PG_PORT:-55432}/${PG_APP_DB:-lingoria}}"
TARGET_DB="${PG_APP_DB:-lingoria}"

echo "=================================================================="
echo "Lingoria Core Database One-Time Initialization (make pg-init)"
echo "Target Database: $TARGET_DB"
echo "=================================================================="

# Check if target database is reachable
if ! psql "$DB_URL" -c "SELECT 1;" >/dev/null 2>&1; then
  echo "Error: Cannot connect to database '$TARGET_DB'." >&2
  echo "Please ensure the database and user exist first by running: make pg-provision" >&2
  exit 1
fi

# Check if database has already been initialized
already_initialized="$(psql "$DB_URL" -Atc "
  SELECT 1 FROM information_schema.tables 
  WHERE table_schema = 'platform' AND table_name = 'schema_migrations'
  LIMIT 1;
" 2>/dev/null || echo "")"

if [[ "$already_initialized" == "1" ]]; then
  table_count="$(psql "$DB_URL" -Atc "
    SELECT count(*) FROM information_schema.tables 
    WHERE table_schema NOT IN ('pg_catalog', 'information_schema');
  " 2>/dev/null || echo "0")"
  echo "Notice: Database '$TARGET_DB' is ALREADY INITIALIZED."
  echo "Found $table_count application tables across schemas."
  echo "Refusing to re-run initialization to safeguard existing data."
  echo "If you need a complete clean reset, run: make pg-reset CONFIRM=YES"
  echo "=================================================================="
  exit 0
fi

echo "-> Initializing schemas and core table DDL..."

# 1. Extensions & Platform schema
psql "$DB_URL" -v ON_ERROR_STOP=1 -f sql/migrations/0001_extensions.sql
psql "$DB_URL" -v ON_ERROR_STOP=1 -c "INSERT INTO platform.schema_migrations(version) VALUES ('0001') ON CONFLICT DO NOTHING;"

# 2. Sequential migrations
for file in sql/migrations/[0-9][0-9][0-9][0-9]_*.sql; do
  version="$(basename "$file" | cut -d_ -f1)"
  if [[ "$version" == "0001" ]]; then
    continue
  fi
  echo "   -> Applying $file..."
  psql "$DB_URL" -v ON_ERROR_STOP=1 -1 -f "$file"
  psql "$DB_URL" -v ON_ERROR_STOP=1 -c "INSERT INTO platform.schema_migrations(version) VALUES ('$version');"
done

# 3. Catalog Seed Data
echo "-> Loading initial catalog seed data..."
for file in sql/seeds/*.sql; do
  if [[ -f "$file" ]]; then
    echo "   -> Seeding from $file..."
    psql "$DB_URL" -v ON_ERROR_STOP=1 -1 -f "$file"
  fi
done

echo "=================================================================="
echo "Core database '$TARGET_DB' initialized successfully!"
echo "All 14 schemas, tables, and catalog seed data are ready."
echo "=================================================================="
