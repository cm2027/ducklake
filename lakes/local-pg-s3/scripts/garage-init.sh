#!/usr/bin/env bash
# Idempotent Garage bootstrap: layout + bucket + S3 key.
# Run after `docker compose up -d postgres garage` from lakes/local-pg-s3/.
# No .env needed: every value falls back to the hardcoded dev defaults
# (same as compose.yaml / seed.sql). A `.env` file (see .env.example) or
# exported variables only override those defaults.
set -euo pipefail
cd "$(dirname "$0")/.."

# Optional overrides first, then hardcoded dev defaults.
if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  set -a; source .env; set +a
fi
: "${S3_BUCKET:=ducklake-data}"
: "${S3_KEY_ID:=GK0123456789abcdef01234567}"
: "${S3_SECRET_KEY:=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef}"
: "${GARAGE_S3_PORT:=3900}"
: "${GARAGE_REGION:=garage}"

G="docker compose exec -T garage /garage"

echo "==> waiting for garage daemon..."
until $G status >/dev/null 2>&1; do sleep 1; done
$G status

NODE_ID="$($G node id 2>/dev/null | grep -oE '[0-9a-f]{32,}' | head -n 1 || true)"
if [[ -z "${NODE_ID}" ]]; then
  # fallback: first column of `status`
  NODE_ID="$($G status | awk '/^[0-9a-f]{4,}/ {print $1; exit}')"
fi
echo "==> node id: ${NODE_ID}"
SHORT="$(echo "${NODE_ID}" | cut -c1-16)"
echo "==> short id: ${SHORT}"

if $G layout show 2>/dev/null | grep -q "${SHORT}\|${NODE_ID}"; then
  echo "==> layout already assigned, skipping assign"
else
  echo "==> assigning layout (zone dc1, capacity 1G)..."
  # `layout assign` wants: -z ZONE -c CAPACITY <node>
  $G layout assign -z dc1 -c 1G "${SHORT}"
fi

if $G layout show 2>/dev/null | grep -qi "no staged\|nothing to commit\|current version.*1\|version: 1"; then
  echo "==> layout version already applied (or nothing staged)"
else
  echo "==> applying layout..."
  # `--version 1` first time, plain `apply` afterwards; try both.
  $G layout apply --version 1 2>/dev/null || $G layout apply || true
fi
$G layout show || true

echo "==> ensuring bucket '${S3_BUCKET}'..."
$G bucket create "${S3_BUCKET}" 2>/dev/null || echo "(bucket exists, continuing)"

echo "==> ensuring key '${S3_KEY_ID}'..."
if $G key info "${S3_KEY_ID}" >/dev/null 2>&1; then
  echo "(key exists, continuing)"
else
  # deterministic credentials so seed scripts can read them without parsing
  $G key import --yes -n ducklake-local "${S3_KEY_ID}" "${S3_SECRET_KEY}"
fi

echo "==> granting read+write on bucket to key..."
$G bucket allow --read --write "${S3_BUCKET}" --key "${S3_KEY_ID}"

echo "==> bucket info:"
$G bucket info "${S3_BUCKET}"
echo
echo "done. S3 endpoint: http://127.0.0.1:${GARAGE_S3_PORT}  region: ${GARAGE_REGION}"
