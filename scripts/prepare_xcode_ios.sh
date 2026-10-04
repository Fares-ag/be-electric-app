#!/usr/bin/env bash
# Bake Flutter dart-defines into ios/Flutter/Generated.xcconfig for Xcode builds.
#
# Xcode Run/Archive does NOT pass --dart-define flags. Run this script first so
# ENABLE_PM_OCCURRENCES and Supabase URLs are embedded in the iOS build.
#
# Usage (from repo root):
#   ./scripts/prepare_xcode_ios.sh requestor_cmms
#   ./scripts/prepare_xcode_ios.sh technician_cmms
#   ./scripts/prepare_xcode_ios.sh requestor_cmms --release
#
# Then open apps/<app>/ios/Runner.xcworkspace in Xcode, Product → Clean Build
# Folder, then Run or Archive.

set -euo pipefail

APP_SUBDIR="${1:-}"
BUILD_MODE="${2:-debug}"

if [[ -z "$APP_SUBDIR" ]]; then
  echo "Usage: $0 <requestor_cmms|technician_cmms> [--debug|--release]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFINES_FILE="$SCRIPT_DIR/defines.production.json"
APP_DIR="$REPO_ROOT/apps/$APP_SUBDIR"

if [[ ! -d "$APP_DIR" ]]; then
  echo "ERROR: App directory not found: $APP_DIR" >&2
  exit 1
fi

if [[ ! -f "$DEFINES_FILE" ]]; then
  echo "ERROR: Missing $DEFINES_FILE" >&2
  echo "Run: ./scripts/setup_production_defines.sh" >&2
  exit 1
fi

node "$SCRIPT_DIR/validate_production_defines.mjs" "$DEFINES_FILE"

"$SCRIPT_DIR/prepare_ios_build_dir.sh" "$APP_SUBDIR"

mode_args=(--config-only --dart-define-from-file="$DEFINES_FILE")
case "$BUILD_MODE" in
  --debug|debug)
    mode_args=(--debug "${mode_args[@]}")
    ;;
  --release|release)
    mode_args=(--release "${mode_args[@]}")
    ;;
  *)
    echo "Second arg must be --debug or --release (got: $BUILD_MODE)" >&2
    exit 1
    ;;
esac

(
  cd "$APP_DIR"
  flutter pub get
  flutter build ios "${mode_args[@]}"
)

echo ""
echo "OK: Wrote dart-defines to $APP_DIR/ios/Flutter/Generated.xcconfig"
echo ""
echo "Next in Xcode:"
echo "  1. open $APP_DIR/ios/Runner.xcworkspace"
echo "  2. Product → Clean Build Folder (Shift+Cmd+K)"
echo "  3. Run (Cmd+R) or Archive"
echo ""
echo "Re-run this script whenever you change scripts/defines.production.json"
