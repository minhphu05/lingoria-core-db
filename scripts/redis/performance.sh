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
echo "Redis Performance & Throughput Diagnostics"
echo "Host: $REDIS_HOST:$REDIS_PORT"
echo "=================================================================="

if [[ "$(run_redis ping 2>/dev/null || echo "")" != "PONG" ]]; then
  echo "Status: [OFFLINE] Cannot reach Redis at $REDIS_HOST:$REDIS_PORT."
  echo "Tip: Run 'make deploy-redis' in lingoria-platform-deployment."
  exit 0
fi

echo "1. Activity & Throughput:"
run_redis INFO stats | grep -E "total_connections_received|total_commands_processed|instantaneous_ops_per_sec|rejected_connections" || true

echo ""
echo "2. Cache Hit Ratio:"
stats="$(run_redis INFO stats 2>/dev/null || echo "")"
hits="$(echo "$stats" | grep "keyspace_hits:" | cut -d: -f2 | tr -d '\r\n' || echo "0")"
misses="$(echo "$stats" | grep "keyspace_misses:" | cut -d: -f2 | tr -d '\r\n' || echo "0")"

python3 -c "
hits = int('$hits' or 0)
misses = int('$misses' or 0)
total = hits + misses
ratio = (hits / total * 100) if total > 0 else 0.0
print(f'   Keyspace Hits:   {hits}')
print(f'   Keyspace Misses: {misses}')
print(f'   Hit Ratio:       {ratio:.2f}% (Target: > 85%)')
" 2>/dev/null || echo "Unable to calculate hit ratio."

echo "=================================================================="
