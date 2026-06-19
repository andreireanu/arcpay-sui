#!/usr/bin/env bash
set -euo pipefail

# Publish the package and capture the IDs created by the publish transaction,
# writing them back into .env so the other scripts can source them.
#
# Parses (from `sui client publish --json` -> objectChanges):
#   PACKAGE_ID      the published package
#   UPGRADE_CAP_ID  the 0x2::package::UpgradeCap object
#   ADMIN_CAP_ID    the arcpay::AdminCap object
#   PUBLISHER_ID    the 0x2::package::Publisher object

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

echo "Publishing package..." >&2
OUT="$(sui client publish --gas-budget 200000000 --json)"

# Pull each id out of objectChanges. AdminCap is matched by type suffix since its
# fully-qualified type is prefixed with the freshly published package id.
PACKAGE_ID="$(jq -r '.objectChanges[] | select(.type == "published") | .packageId' <<<"$OUT")"
UPGRADE_CAP_ID="$(jq -r '.objectChanges[] | select(.objectType? == "0x2::package::UpgradeCap") | .objectId' <<<"$OUT")"
PUBLISHER_ID="$(jq -r '.objectChanges[] | select(.objectType? == "0x2::package::Publisher") | .objectId' <<<"$OUT")"
ADMIN_CAP_ID="$(jq -r '.objectChanges[] | select(.objectType? // "" | endswith("::arcpay::AdminCap")) | .objectId' <<<"$OUT")"

for pair in \
  "PACKAGE_ID:$PACKAGE_ID" \
  "UPGRADE_CAP_ID:$UPGRADE_CAP_ID" \
  "ADMIN_CAP_ID:$ADMIN_CAP_ID" \
  "PUBLISHER_ID:$PUBLISHER_ID"; do
  if [[ -z "${pair#*:}" || "${pair#*:}" == "null" ]]; then
    echo "Failed to parse ${pair%%:*} from publish output" >&2
    echo "$OUT" >&2
    exit 1
  fi
done

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

set_env PACKAGE_ID "$PACKAGE_ID"
set_env UPGRADE_CAP_ID "$UPGRADE_CAP_ID"
set_env ADMIN_CAP_ID "$ADMIN_CAP_ID"
set_env PUBLISHER_ID "$PUBLISHER_ID"

echo "Wrote to $ENV_FILE:" >&2
echo "  PACKAGE_ID=$PACKAGE_ID"
echo "  UPGRADE_CAP_ID=$UPGRADE_CAP_ID"
echo "  ADMIN_CAP_ID=$ADMIN_CAP_ID"
echo "  PUBLISHER_ID=$PUBLISHER_ID"
