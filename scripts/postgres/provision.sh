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

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-55432}"
PG_SUPERUSER="${PG_SUPERUSER:-postgres}"
PG_SUPERUSER_PASSWORD="${PG_SUPERUSER_PASSWORD:-postgres_change_me_from_deployment}"

CONFIG_FILE="configs/postgres.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found at $CONFIG_FILE" >&2
  exit 1
fi

echo "=================================================================="
echo "PostgreSQL Declarative Provisioning"
echo "Config: $CONFIG_FILE"
echo "Host:   $PG_HOST:$PG_PORT (as superuser '$PG_SUPERUSER')"
echo "=================================================================="

run_superuser_sql() {
  local target_db="$1"
  local sql_cmd="$2"
  PGPASSWORD="$PG_SUPERUSER_PASSWORD" psql \
    -h "$PG_HOST" \
    -p "$PG_PORT" \
    -U "$PG_SUPERUSER" \
    -d "$target_db" \
    -v ON_ERROR_STOP=1 \
    -c "$sql_cmd"
}

run_superuser_query() {
  local target_db="$1"
  local sql_query="$2"
  PGPASSWORD="$PG_SUPERUSER_PASSWORD" psql \
    -h "$PG_HOST" \
    -p "$PG_PORT" \
    -U "$PG_SUPERUSER" \
    -d "$target_db" \
    -Atc "$sql_query" 2>/dev/null || echo ""
}

# 1. Parse and provision databases
echo "-> Checking and provisioning databases..."
python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
for db in cfg.get('databases', []):
    name = db if isinstance(db, str) else db.get('name')
    enc = 'UTF8' if isinstance(db, str) else db.get('encoding', 'UTF8')
    print(f'{name}:{enc}')
" | while IFS=":" read -r db_name db_enc; do
  exists="$(run_superuser_query "postgres" "SELECT 1 FROM pg_database WHERE datname = '$db_name';")"
  if [[ "$exists" == "1" ]]; then
    echo "   [EXISTS] Database '$db_name' already exists."
  else
    echo "   [CREATING] Database '$db_name' (Encoding: $db_enc)..."
    run_superuser_sql "postgres" "CREATE DATABASE \"$db_name\" ENCODING '$db_enc' TEMPLATE template1;"
    echo "   [OK] Database '$db_name' created."
  fi
done

# 2. Parse and provision users & privileges
echo "-> Checking and provisioning roles & privileges..."
python3 -c "
import json, os
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
for u in cfg.get('users', []):
    username = u['username']
    database = u['database']
    privileges = u.get('privileges', 'ALL')
    env_key = u.get('env_password_key', '')
    pwd = os.environ.get(env_key, 'lingoria_local_change_me') if env_key else 'lingoria_local_change_me'
    print(f'{username}:{database}:{privileges}:{pwd}')
" | while IFS=":" read -r username database privileges password; do
  echo "   [ROLE] Provisioning user '$username' for database '$database'..."
  run_superuser_sql "postgres" "
    DO \$\$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '$username') THEN
        CREATE ROLE \"$username\" WITH LOGIN PASSWORD '$password';
      ELSE
        ALTER ROLE \"$username\" WITH PASSWORD '$password';
      END IF;
    END
    \$\$;
  "
  run_superuser_sql "postgres" "GRANT $privileges PRIVILEGES ON DATABASE \"$database\" TO \"$username\";"
  run_superuser_sql "postgres" "ALTER DATABASE \"$database\" OWNER TO \"$username\";"
  run_superuser_sql "$database" "GRANT ALL ON SCHEMA public TO \"$username\";" 2>/dev/null || true
  echo "   [OK] Role '$username' granted $privileges on '$database'."
done

# 3. Parse and provision extensions
echo "-> Checking and provisioning extensions..."
python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
for db, exts in cfg.get('extensions', {}).items():
    for ext in exts:
        print(f'{db}:{ext}')
" | while IFS=":" read -r target_db ext_name; do
  echo "   [EXT] Enabling extension '$ext_name' on database '$target_db'..."
  run_superuser_sql "$target_db" "CREATE EXTENSION IF NOT EXISTS \"$ext_name\";"
done

echo "=================================================================="
echo "PostgreSQL declarative provisioning completed successfully!"
echo "=================================================================="
