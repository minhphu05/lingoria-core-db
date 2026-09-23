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
    return 1
  fi
}

echo "=================================================================="
echo "Redis Keyspace & Namespace Key Counts"
echo "Host: $REDIS_HOST:$REDIS_PORT"
echo "=================================================================="

if [[ "$(run_redis ping 2>/dev/null || echo "")" != "PONG" ]]; then
  echo "Status: [OFFLINE] Cannot reach Redis at $REDIS_HOST:$REDIS_PORT."
  echo "Tip: Run 'make deploy-redis' in lingoria-platform-deployment."
  exit 0
fi

echo "1. Overall Keyspace Summary:"
run_redis INFO keyspace || echo "Keyspace info unavailable."

echo ""
echo "2. Keys Count by Configured Namespace:"
CONFIG_FILE="configs/redis.json"
if [[ -f "$CONFIG_FILE" ]]; then
  python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
for ns in cfg.get('namespaces', []):
    print(ns)
" | while read -r ns; do
    key_count="$(run_redis EVAL "return #redis.call('KEYS', ARGV[1])" 0 "${ns}:*" 2>/dev/null || echo "0")"
    printf "   %-32s : %s keys\n" "${ns}:*" "$key_count"
  done
fi

echo ""
echo "3. Sample Active Keys (Limit 15):"
run_redis --scan --pattern "lingoria:*" | head -n 15 || echo "No active lingoria keys."
echo "=================================================================="
