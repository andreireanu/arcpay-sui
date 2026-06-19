#!/usr/bin/env bash
set -euo pipefail
source .env

sui client upgrade \
  --upgrade-capability "$UPGRADE_CAP_ID" \
  --gas-budget 200000000
