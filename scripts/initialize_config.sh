#!/usr/bin/env bash
set -euo pipefail

# Create the shared Config and capture its id, writing it back into .env so the
# other scripts (migrate, update_backend, ...) can source it.
#
# Parses (from `sui client call --json` -> objectChanges):
#   CONFIG_ID  the created arcpay::config::Config object

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
source "$ENV_FILE"

echo "Initializing config..." >&2
OUT="$(sui client call \
  --package "$PACKAGE_ID" \
  --module config \
  --function initialize_config \
  --args "$ADMIN_CAP_ID" "$BACKEND_PUBKEY" \
  --gas-budget 100000000 \
  --json)"

# Config is matched by type suffix since its fully-qualified type is prefixed
# with the published package id.
CONFIG_ID="$(jq -r '.objectChanges[] | select(.objectType? // "" | endswith("::config::Config")) | .objectId' <<<"$OUT")"

if [[ -z "$CONFIG_ID" || "$CONFIG_ID" == "null" ]]; then
  echo "Failed to parse CONFIG_ID from call output" >&2
  echo "$OUT" >&2
  exit 1
fi

# Replace KEY=... in .env if present, otherwise append it.
set_env() {
  local key="$1" val="$2"
  touch "$ENV_FILE"
  if grep -qE "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$val" >>"$ENV_FILE"
  fi
}

set_env CONFIG_ID "$CONFIG_ID"

echo "Wrote to $ENV_FILE:" >&2
echo "  CONFIG_ID=$CONFIG_ID"
