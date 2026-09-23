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

CONFIG_FILE="configs/minio.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config file not found at $CONFIG_FILE" >&2
  exit 1
fi

MINIO_ENDPOINT="${MINIO_ENDPOINT:-http://localhost:9000}"
MINIO_ROOT_USER="${MINIO_ROOT_USER:-minioadmin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-minioadmin_change_me}"

# Determine how to run MinIO Client (mc)
if command -v mc >/dev/null 2>&1; then
  MC_CMD=(mc)
elif docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^lingoria-minio$"; then
  MC_CMD=(docker exec lingoria-minio mc)
  MINIO_ENDPOINT="http://localhost:9000"
else
  MC_CMD=(docker run --rm --network host minio/mc)
fi

echo "=================================================================="
echo "MinIO Declarative Provisioning"
echo "Config:   $CONFIG_FILE"
echo "Endpoint: $MINIO_ENDPOINT"
echo "=================================================================="

# Configure alias
"${MC_CMD[@]}" alias set lingoria_local "$MINIO_ENDPOINT" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null 2>&1 || {
  echo "Warning: Retrying connection via container direct network..."
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^lingoria-minio$"; then
    docker exec lingoria-minio mc alias set lingoria_local "http://localhost:9000" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
    MC_CMD=(docker exec lingoria-minio mc)
  else
    echo "Error: Cannot connect to MinIO at $MINIO_ENDPOINT. Ensure MinIO is running." >&2
    exit 1
  fi
}

# 1. Parse and provision buckets & policies
echo "-> Checking and provisioning buckets & policies..."
python3 -c "
import json
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
for b in cfg.get('buckets', []):
    name = b['name'] if isinstance(b, dict) else b
    policy = b.get('policy', 'private') if isinstance(b, dict) else 'private'
    print(f'{name}:{policy}')
" | while IFS=":" read -r bucket_name policy; do
  echo "   [BUCKET] Ensuring bucket exists: $bucket_name..."
  "${MC_CMD[@]}" mb --ignore-existing "lingoria_local/$bucket_name"
  if [[ "$policy" != "private" ]]; then
    echo "   [POLICY] Setting anonymous policy '$policy' for '$bucket_name'..."
    "${MC_CMD[@]}" anonymous set "$policy" "lingoria_local/$bucket_name" >/dev/null 2>&1 || true
  fi
done

# 2. Parse and provision users / service accounts
echo "-> Checking and provisioning users & access keys..."
python3 -c "
import json, os
with open('$CONFIG_FILE') as f:
    cfg = json.load(f)
for u in cfg.get('users', []):
    name = u['username']
    access_key = os.environ.get(u.get('env_access_key', ''), name)
    secret_key = os.environ.get(u.get('env_secret_key', ''), 'secret_key_change_me')
    policy = u.get('policy', 'readwrite')
    allowed = ','.join(u.get('allowed_buckets', []))
    print(f'{name}:{access_key}:{secret_key}:{policy}:{allowed}')
" | while IFS=":" read -r name access_key secret_key policy allowed_buckets; do
  echo "   [USER] Creating / updating user '$access_key' (policy: $policy)..."
  "${MC_CMD[@]}" admin user add lingoria_local "$access_key" "$secret_key" >/dev/null 2>&1 || true

  if [[ -n "$allowed_buckets" ]]; then
    # Generate custom policy for specified buckets
    tmp_pol="$(mktemp)"
    python3 -c "
import json
buckets = '$allowed_buckets'.split(',')
doc = {
    'Version': '2012-10-17',
    'Statement': [
        {
            'Effect': 'Allow',
            'Action': ['s3:*'],
            'Resource': [f'arn:aws:s3:::{b}' for b in buckets] + [f'arn:aws:s3:::{b}/*' for b in buckets]
        }
    ]
}
print(json.dumps(doc, indent=2))
" > "$tmp_pol"

    if [[ "${MC_CMD[0]:-}" == "docker" ]]; then
      docker cp "$tmp_pol" lingoria-minio:/tmp/custom_policy.json >/dev/null 2>&1
      "${MC_CMD[@]}" admin policy create lingoria_local "$policy" /tmp/custom_policy.json >/dev/null 2>&1 || \
      "${MC_CMD[@]}" admin policy update lingoria_local "$policy" /tmp/custom_policy.json >/dev/null 2>&1 || true
    else
      "${MC_CMD[@]}" admin policy create lingoria_local "$policy" "$tmp_pol" >/dev/null 2>&1 || \
      "${MC_CMD[@]}" admin policy update lingoria_local "$policy" "$tmp_pol" >/dev/null 2>&1 || true
    fi
    rm -f "$tmp_pol"
  fi

  if [[ -n "$policy" ]]; then
    "${MC_CMD[@]}" admin policy attach lingoria_local "$policy" --user "$access_key" >/dev/null 2>&1 || true
  fi
  echo "   [OK] User '$access_key' provisioned."
done

echo "=================================================================="
echo "MinIO declarative provisioning completed successfully!"
echo "=================================================================="
