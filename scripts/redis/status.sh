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
echo "Redis Health & Instance Status"
echo "Host: $REDIS_HOST:$REDIS_PORT"
echo "=================================================================="

printf "%-20s " "Ping Check:"
res="$(run_redis ping 2>/dev/null || echo "")"
if [[ "$res" == "PONG" ]]; then
  echo "[ONLINE] Responding with PONG"
else
  echo "[OFFLINE] Cannot reach Redis server ($REDIS_HOST:$REDIS_PORT)."
  echo "Tip: Run 'make deploy-redis' in lingoria-platform-deployment."
  exit 0
fi

echo ""
echo "Server & Client Details:"
run_redis INFO server | grep -E "redis_version|os|arch_bits|uptime_in_days|tcp_port" || true
run_redis INFO clients | grep -E "connected_clients|blocked_clients|maxclients" || true
echo "=================================================================="
