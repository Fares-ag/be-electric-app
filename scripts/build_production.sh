#!/usr/bin/env bash
# Release builds with production dart-defines (Option A).
# Usage (from repo root):
#   ./scripts/setup_production_defines.sh   # once, then edit secrets
#   ./scripts/build_production.sh requestor ipa
#
# Requires scripts/defines.production.json (see defines.production.json.example).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFINES_FILE="$SCRIPT_DIR/defines.production.json"

TARGET="${1:-both}"
ANDROID_FORMAT="${2:-apk}"

if [[ ! -f "$DEFINES_FILE" ]]; then
  echo "ERROR: Missing $DEFINES_FILE" >&2
  echo "Run: ./scripts/setup_production_defines.sh" >&2
  echo "Then edit the file with your Supabase and legal URLs." >&2
  exit 1
fi

node "$SCRIPT_DIR/validate_production_defines.mjs" "$DEFINES_FILE"

define_args=(--dart-define-from-file="$DEFINES_FILE")
echo "Using --dart-define-from-file: $DEFINES_FILE"

build_android() {
  local app_subdir="$1"
  local format="$2"
  (
    cd "$REPO_ROOT/apps/$app_subdir"
    flutter build "$format" --release "${define_args[@]}"
  )
}

build_ios() {
  local app_subdir="$1"
  local export_opts=()
  if [[ -f "$REPO_ROOT/apps/$app_subdir/ios/ExportOptions.plist" ]]; then
    export_opts+=(--export-options-plist=ios/ExportOptions.plist)
  fi
  bash "$SCRIPT_DIR/prepare_ios_build_dir.sh" "$app_subdir"
  (
    cd "$REPO_ROOT/apps/$app_subdir"
    flutter build ipa --release "${define_args[@]}" "${export_opts[@]}"
  )
}

case "$ANDROID_FORMAT" in
  apk|appbundle) ;;
  ipa) ;;
  *)
    echo "Second arg must be apk, appbundle, or ipa (got: $ANDROID_FORMAT)" >&2
    exit 1
    ;;
esac

case "$TARGET" in
  requestor)
    if [[ "$ANDROID_FORMAT" == "ipa" ]]; then build_ios requestor_cmms; else build_android requestor_cmms "$ANDROID_FORMAT"; fi
    ;;
  technician)
    if [[ "$ANDROID_FORMAT" == "ipa" ]]; then build_ios technician_cmms; else build_android technician_cmms "$ANDROID_FORMAT"; fi
    ;;
  both)
    if [[ "$ANDROID_FORMAT" == "ipa" ]]; then
      build_ios requestor_cmms
      build_ios technician_cmms
    else
      build_android requestor_cmms "$ANDROID_FORMAT"
      build_android technician_cmms "$ANDROID_FORMAT"
    fi
    ;;
  *)
    echo "Usage: $0 [requestor|technician|both] [apk|appbundle|ipa]" >&2
    exit 1
    ;;
esac

echo "Done."
