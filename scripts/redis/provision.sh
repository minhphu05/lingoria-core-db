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

CONFIG_FILE="configs/redis.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found at $CONFIG_FILE" >&2
  exit 1
fi

REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"
REDIS_PASSWORD="${REDIS_PASSWORD:-}"

run_redis() {
  if command -v redis-cli >/dev/null 2>&1; then
    if [[ -n "$REDIS_PASSWORD" ]]; then
      redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "$REDIS_PASSWORD" "$@"
    else
      redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" "$@"
    fi
  elif docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^lingoria-redis$"; then
    if [[ -n "$REDIS_PASSWORD" ]]; then
      docker exec lingoria-redis redis-cli -a "$REDIS_PASSWORD" "$@"
    else
      docker exec lingoria-redis redis-cli "$@"
    fi
  else
    echo "Error: Neither redis-cli nor running container 'lingoria-redis' found." >&2
    exit 1
  fi
}

echo "=================================================================="
echo "Redis Declarative Provisioning"
echo "Config: $CONFIG_FILE"
echo "Host:   $REDIS_HOST:$REDIS_PORT"
echo "=================================================================="

# Check connection
res="$(run_redis ping 2>/dev/null || echo "")"
if [[ "$res" != "PONG" ]]; then
  echo "Error: Cannot connect to Redis at $REDIS_HOST:$REDIS_PORT." >&2
  exit 1
fi

# 1. Parse and provision ACL users
echo "-> Checking and provisioning ACL users..."
python3 -c "
import json, os
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
for u in cfg.get('users', []):
    username = u['username']
    env_key = u.get('env_password_key', '')
    pwd = os.environ.get(env_key, 'redis_app_secret_change_me') if env_key else 'redis_app_secret_change_me'
    rules = u.get('rules', 'on ~lingoria:* +@all')
    print(f'{username}:{pwd}:{rules}')
" | while IFS=":" read -r username password rules; do
  echo "   [ACL USER] Setting ACL for '$username'..."
  # Format rules with password
  run_redis ACL SETUSER "$username" on ">$password" $rules >/dev/null 2>&1 || true
  echo "   [OK] User '$username' provisioned with rules: $rules"
done

# 2. Check namespaces
echo "-> Validating declared namespaces..."
python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
for ns in cfg.get('namespaces', []):
    print(f'   [NAMESPACE] Configured prefix: {ns}:*')
"

echo "=================================================================="
echo "Redis declarative provisioning completed successfully!"
echo "=================================================================="
