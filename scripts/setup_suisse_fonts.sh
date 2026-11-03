#!/usr/bin/env bash
# Copy licensed Suisse Intl desktop fonts into cmms_core for Flutter bundling.
#
# Obtain OTF/TTF files from Swiss Typefaces (trial or license):
#   https://www.swisstypefaces.com/fonts/suisse/
#
# Usage:
#   ./scripts/setup_suisse_fonts.sh /path/to/folder/with/suisse/files
#
# Accepts common Swiss Typefaces filenames (case-insensitive), e.g.:
#   SuisseIntl-Regular.otf, SuisseIntl-Book.otf, SuisseIntl-Medium.otf,
#   SuisseIntl-SemiBold.otf, SuisseIntl-Bold.otf, SuisseIntl-Light.otf

set -euo pipefail

SRC="${1:-}"
DEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/packages/cmms_core/assets/fonts"

if [[ -z "$SRC" || ! -d "$SRC" ]]; then
  echo "Usage: $0 /path/to/suisse/font/files" >&2
  exit 1
fi

mkdir -p "$DEST"

copy_if_found() {
  local pattern="$1"
  local dest_name="$2"
  local found=""
  found="$(find "$SRC" -maxdepth 2 -iname "$pattern" -print -quit 2>/dev/null || true)"
  if [[ -n "$found" ]]; then
    cp "$found" "$DEST/$dest_name"
    echo "  + $dest_name"
  fi
}

echo "Copying Suisse Intl fonts to $DEST"

copy_if_found 'SuisseIntl-Regular.otf' 'SuisseIntl-Regular.otf'
copy_if_found 'SuisseIntl-Regular.ttf' 'SuisseIntl-Regular.ttf'
copy_if_found 'SuisseIntl-Book.otf' 'SuisseIntl-Book.otf'
copy_if_found 'SuisseIntl-Medium.otf' 'SuisseIntl-Medium.otf'
copy_if_found 'SuisseIntl-SemiBold.otf' 'SuisseIntl-SemiBold.otf'
copy_if_found 'SuisseIntl-Bold.otf' 'SuisseIntl-Bold.otf'
copy_if_found 'SuisseIntl-Light.otf' 'SuisseIntl-Light.otf'

required=(
  SuisseIntl-Regular.otf
  SuisseIntl-Regular.ttf
  SuisseIntl-Book.otf
)

found_required=false
for candidate in "${required[@]}"; do
  if [[ -f "$DEST/$candidate" ]]; then
    found_required=true
    break
  fi
done

if [[ "$found_required" != true ]]; then
  echo "ERROR: No regular/book weight found. Copy at least SuisseIntl-Regular or SuisseIntl-Book." >&2
  exit 1
fi

if [[ ! -f "$DEST/SuisseIntl-Regular.otf" && -f "$DEST/SuisseIntl-Book.otf" ]]; then
  cp "$DEST/SuisseIntl-Book.otf" "$DEST/SuisseIntl-Regular.otf"
  echo "  + SuisseIntl-Regular.otf (from Book)"
fi

if [[ ! -f "$DEST/SuisseIntl-Bold.otf" ]]; then
  copy_if_found 'SuisseIntl-SemiBold.otf' 'SuisseIntl-Bold.otf'
fi

if [[ ! -f "$DEST/SuisseIntl-Medium.otf" ]]; then
  copy_if_found 'SuisseIntl-Book.otf' 'SuisseIntl-Medium.otf'
fi

echo "Done. Run: cd packages/cmms_core && flutter pub get"
