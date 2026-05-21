#!/usr/bin/env bash
# Bottomline bar: Dart / Flutter ecosystem bar
# Only renders when the project contains a pubspec.yaml.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" || ! -f "$PROJ/pubspec.yaml" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

# ── Palette (Dart brand blue) ─────────────────────────────────────────────────
if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg   "$(hex_to_rgb "#c5e8ff")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#0175C2")")
  _bar_gradient='["#042B59","#011F3F"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

# ── Icons ─────────────────────────────────────────────────────────────────────
case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_DART=$'\xef\x88\x99'    # U+F219  nf-fa-diamond
    IC_FLUTTER=$'\xef\x84\x8b' # U+F10B  nf-fa-mobile
    ;;
  emoji)
    IC_DART='🎯'
    IC_FLUTTER='🐦'
    ;;
  *)
    IC_DART='' IC_FLUTTER=''
    ;;
esac

# ── Parse pubspec.yaml ────────────────────────────────────────────────────────
pkg_name=$(grep -m1 '^name:' "$PROJ/pubspec.yaml" 2>/dev/null | awk '{print $2}')

sdk_version=$(grep -A5 '^environment:' "$PROJ/pubspec.yaml" 2>/dev/null \
  | grep -m1 'sdk:' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

is_flutter=false
grep -q 'sdk:\s*flutter' "$PROJ/pubspec.yaml" 2>/dev/null && is_flutter=true

# ── Segments ──────────────────────────────────────────────────────────────────
dart_seg="${FG_ACCENT}${IC_DART} ${FG_TEXT}Dart"
[[ -n "$sdk_version" ]] && dart_seg+=" ${FG_ACCENT}v${sdk_version}"
[[ -n "$pkg_name" ]]    && dart_seg+=" ${FG_TEXT}${pkg_name}"
add_seg "$dart_seg"

$is_flutter && add_seg "${FG_ACCENT}${IC_FLUTTER} ${FG_TEXT}Flutter"

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
