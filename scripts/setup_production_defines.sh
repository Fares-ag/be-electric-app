#!/usr/bin/env bash
# Creates scripts/defines.production.json for Option A release builds.
# The file is gitignored — safe for secrets on your machine.
#
# Usage:
#   ./scripts/setup_production_defines.sh
#
# Then edit scripts/defines.production.json if any values are still placeholders.
# Prefills Supabase URL/key from scripts/db.env when present.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFINES_FILE="$SCRIPT_DIR/defines.production.json"
EXAMPLE_FILE="$SCRIPT_DIR/defines.production.json.example"
ENV_FILE="$SCRIPT_DIR/db.env"

if [[ -f "$DEFINES_FILE" ]]; then
  echo "Already exists: $DEFINES_FILE"
  echo "Delete it first if you want a fresh copy from the example."
  exit 0
fi

cp "$EXAMPLE_FILE" "$DEFINES_FILE"
echo "Created $DEFINES_FILE from example."

if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a
  source "$ENV_FILE"
  set +a

  if [[ -n "${SUPABASE_URL:-}" && -n "${SUPABASE_ANON_KEY:-}" ]]; then
    node <<'NODE' "$DEFINES_FILE" "$SUPABASE_URL" "$SUPABASE_ANON_KEY"
const fs = require('fs');
const [file, url, key] = process.argv.slice(1);
const data = JSON.parse(fs.readFileSync(file, 'utf8'));
data.SUPABASE_URL = url;
data.SUPABASE_ANON_KEY = key;
fs.writeFileSync(file, JSON.stringify(data, null, 2) + '\n');
NODE
    echo "Prefilled SUPABASE_URL and SUPABASE_ANON_KEY from scripts/db.env"
  fi
fi

echo ""
echo "Next steps:"
echo "  1. Edit $DEFINES_FILE"
echo "     - SUPABASE_URL / SUPABASE_ANON_KEY (Supabase Dashboard → Settings → API)"
echo "     - PRIVACY_POLICY_URL, SUPPORT_URL, SUPPORT_EMAIL (App Store Connect)"
echo "     - ENABLE_PM_OCCURRENCES (\"true\" for Option A PM — default in example)"
echo "  2. Validate: node scripts/validate_production_defines.mjs"
echo "  3. Build:    ./scripts/build_production.sh requestor ipa"
