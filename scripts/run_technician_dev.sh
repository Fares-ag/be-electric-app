#!/usr/bin/env bash
# Run technician app locally with PM Option A enabled.
#
# Usage (from repo root):
#   ./scripts/run_technician_dev.sh
#   ./scripts/run_technician_dev.sh -d "iPhone 16"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFINES_FILE="$SCRIPT_DIR/defines.production.json"
APP_DIR="$REPO_ROOT/apps/technician_cmms"

define_args=()

if [[ -f "$DEFINES_FILE" ]]; then
  define_args=(--dart-define-from-file="$DEFINES_FILE")
  echo "Using $DEFINES_FILE"
else
  echo "No $DEFINES_FILE — using ENABLE_PM_OCCURRENCES=true only."
  define_args=(--dart-define=ENABLE_PM_OCCURRENCES=true)
  if [[ -f "$SCRIPT_DIR/db.env" ]]; then
    # shellcheck disable=SC1090
    set -a
    source "$SCRIPT_DIR/db.env"
    set +a
    if [[ -n "${SUPABASE_URL:-}" ]]; then
      define_args+=(--dart-define=SUPABASE_URL="$SUPABASE_URL")
    fi
    if [[ -n "${SUPABASE_ANON_KEY:-}" ]]; then
      define_args+=(--dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY")
    fi
  fi
fi

cd "$APP_DIR"
flutter run "${define_args[@]}" "$@"
