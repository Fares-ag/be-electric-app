#!/usr/bin/env bash
# Redirect Flutter iOS build output outside OneDrive/cloud-synced folders.
#
# OneDrive (and similar sync tools) add filesystem metadata that makes iOS
# codesign fail with:
#   "resource fork, Finder information, or similar detritus not allowed"
#
# Usage (from repo root):
#   ./scripts/prepare_ios_build_dir.sh requestor_cmms
#   ./scripts/prepare_ios_build_dir.sh technician_cmms
#
# Safe to run repeatedly. Creates /tmp/be-electric-<app>-build and symlinks
# apps/<app>/build -> that directory.

set -euo pipefail

APP_SUBDIR="${1:-}"
if [[ -z "$APP_SUBDIR" ]]; then
  echo "Usage: $0 <requestor_cmms|technician_cmms>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/apps/$APP_SUBDIR"
BUILD_LINK="/tmp/be-electric-${APP_SUBDIR}-build"

if [[ ! -d "$APP_DIR" ]]; then
  echo "ERROR: App directory not found: $APP_DIR" >&2
  exit 1
fi

mkdir -p "$BUILD_LINK"

if [[ -L "$APP_DIR/build" ]]; then
  current_target="$(readlink "$APP_DIR/build" || true)"
  if [[ "$current_target" == "$BUILD_LINK" ]]; then
    echo "build symlink already set: $APP_DIR/build -> $BUILD_LINK"
    exit 0
  fi
  rm "$APP_DIR/build"
elif [[ -d "$APP_DIR/build" ]]; then
  echo "Removing existing build directory (OneDrive-safe output will use $BUILD_LINK)"
  rm -rf "$APP_DIR/build"
fi

ln -s "$BUILD_LINK" "$APP_DIR/build"
echo "Linked $APP_DIR/build -> $BUILD_LINK"
