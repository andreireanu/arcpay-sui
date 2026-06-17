#!/usr/bin/env bash
set -euo pipefail
source ./.env

sui client call \
  --package "$PACKAGE_ID" \
  --module config \
  --function initialize_config \
  --args "$ADMIN_CAP_ID" "$BACKEND_PUBKEY" \
  --gas-budget 100000000
