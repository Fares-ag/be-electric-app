#!/usr/bin/env bash
# Create App Store Connect app (if needed), build technician IPA, upload to TestFlight.
#
# Prerequisites:
#   1. scripts/defines.production.json (./scripts/setup_production_defines.sh)
#   2. scripts/asc.env from scripts/asc.env.example (App Store Connect API key)
#
# Usage (from repo root):
#   bash scripts/push_technician_testflight.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ASC_ENV="$SCRIPT_DIR/asc.env"
BUNDLE_ID="com.beelectric.cmms.technicianCmms"
APP_NAME="Be Electric Tech"
SKU="beelectric-technician-cmms"

if [[ ! -f "$ASC_ENV" ]]; then
  echo "ERROR: Missing $ASC_ENV" >&2
  echo "Copy scripts/asc.env.example → scripts/asc.env and add your App Store Connect API key." >&2
  exit 1
fi

echo "==> Ensuring App Store Connect app exists for $BUNDLE_ID"
node "$SCRIPT_DIR/asc_create_app.mjs" \
  --bundle-id "$BUNDLE_ID" \
  --name "$APP_NAME" \
  --sku "$SKU"

echo "==> Building release IPA"
bash "$SCRIPT_DIR/build_production.sh" technician ipa

IPA="$(find /tmp/be-electric-technician_cmms-build/ios/ipa -name '*.ipa' -print -quit)"
if [[ -z "$IPA" || ! -f "$IPA" ]]; then
  echo "ERROR: IPA not found under /tmp/be-electric-technician_cmms-build/ios/ipa" >&2
  exit 1
fi

echo "==> Uploading $IPA to App Store Connect"
# shellcheck disable=SC1090
set -a
source "$ASC_ENV"
set +a

if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" ]]; then
  echo "ERROR: ASC_KEY_ID and ASC_ISSUER_ID required in asc.env" >&2
  exit 1
fi

xcrun altool --upload-app --type ios -f "$IPA" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID"

echo "Done. Check App Store Connect → TestFlight in a few minutes."
