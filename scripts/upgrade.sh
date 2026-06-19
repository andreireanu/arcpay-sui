#!/usr/bin/env bash
set -euo pipefail

# Upgrade the package and capture the new package id, writing it back into .env so
# the other scripts use the upgraded package.
#
# Parses (from `sui client upgrade --json` -> objectChanges):
#   PACKAGE_ID      the newly published package version
#   UPGRADE_CAP_ID  the 0x2::package::UpgradeCap object (mutated by the upgrade)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
source "$ENV_FILE"

echo "Upgrading package..." >&2
OUT="$(sui client upgrade \
  --upgrade-capability "$UPGRADE_CAP_ID" \
  --gas-budget 200000000 \
  --json)"

# An upgrade emits a fresh `published` entry with the new package id; the
# UpgradeCap keeps its id but is mutated (version bumped).
PACKAGE_ID="$(jq -r '.objectChanges[] | select(.type == "published") | .packageId' <<<"$OUT")"
UPGRADE_CAP_ID="$(jq -r '.objectChanges[] | select(.objectType? == "0x2::package::UpgradeCap") | .objectId' <<<"$OUT")"

for pair in \
  "PACKAGE_ID:$PACKAGE_ID" \
  "UPGRADE_CAP_ID:$UPGRADE_CAP_ID"; do
  if [[ -z "${pair#*:}" || "${pair#*:}" == "null" ]]; then
    echo "Failed to parse ${pair%%:*} from upgrade output" >&2
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

echo "Wrote to $ENV_FILE:" >&2
echo "  PACKAGE_ID=$PACKAGE_ID"
echo "  UPGRADE_CAP_ID=$UPGRADE_CAP_ID"
