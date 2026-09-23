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

MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost:9000}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin_change_me}"

echo "=================================================================="
echo "MinIO Users & Service Accounts"
echo "Endpoint: $MINIO_ENDPOINT"
echo "=================================================================="

if ! curl -s -f -m 2 "${MINIO_ENDPOINT}/minio/health/live" >/dev/null 2>&1; then
  echo "Status: [OFFLINE] Cannot reach MinIO server at $MINIO_ENDPOINT."
  echo "Tip: Run 'make deploy-minio' in lingoria-platform-deployment."
  exit 0
fi

if command -v mc >/dev/null 2>&1; then
  MC_CMD=(mc)
elif docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^lingoria-minio$"; then
  MC_CMD=(docker exec lingoria-minio mc)
  MINIO_ENDPOINT="http://localhost:9000"
else
  MC_CMD=(docker run --rm --network host minio/mc)
fi

"${MC_CMD[@]}" alias set lingoria_local "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null 2>&1 || true
echo "1. Users List (Status & Policies):"
"${MC_CMD[@]}" admin user list "lingoria_local" || echo "Unable to list users."

echo ""
echo "2. Configured Service Accounts:"
"${MC_CMD[@]}" admin user info "lingoria_local" "$MINIO_ROOT_USER" 2>/dev/null || true
echo "=================================================================="
