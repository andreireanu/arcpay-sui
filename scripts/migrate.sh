#!/usr/bin/env bash
set -euo pipefail
source .env

sui client call \
  --package "$PACKAGE_ID" \
  --module config \
  --function migrate \
  --args "$CONFIG_ID" "$ADMIN_CAP_ID" \
  --gas-budget 100000000
