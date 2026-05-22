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
    IC_TEST=$'\xef\x81\x80'      # U+F040  nf-fa-pencil
    IC_STATE=$'\xef\x84\xa9'     # U+F129  nf-fa-info (state mgmt)
    IC_NET=$'\xef\x82\xac'       # U+F0AC  nf-fa-globe (HTTP)
    IC_LINT=$'\xef\x80\x8c'      # U+F00C  nf-fa-check
    ;;
  emoji)
    IC_DART='🎯'
    IC_FLUTTER='🐦'
    IC_TEST='🧪'
    IC_STATE='🧭'
    IC_NET='🌐'
    IC_LINT='✓'
    ;;
  *)
    IC_DART='' IC_FLUTTER='' IC_TEST='' IC_STATE='' IC_NET='' IC_LINT=''
    ;;
esac

# ── Parse pubspec.yaml ────────────────────────────────────────────────────────
pkg_name=$(grep -m1 '^name:' "$PROJ/pubspec.yaml" 2>/dev/null | awk '{print $2}')

sdk_version=$(grep -A5 '^environment:' "$PROJ/pubspec.yaml" 2>/dev/null \
  | grep -m1 'sdk:' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

is_flutter=false
grep -q 'sdk:\s*flutter' "$PROJ/pubspec.yaml" 2>/dev/null && is_flutter=true

# ── Detect testing + add-ons + lints from pubspec.yaml ────────────────────────
pubspec="$PROJ/pubspec.yaml"

has_test=false
has_flutter_test=false
grep -Eq '^[[:space:]]+test:' "$pubspec" 2>/dev/null && has_test=true
grep -Eq '^[[:space:]]+flutter_test:' "$pubspec" 2>/dev/null && has_flutter_test=true
# Layering: flutter_test suppresses test
$has_flutter_test && has_test=false

state_mgmt=''
for sm in flutter_riverpod riverpod flutter_bloc bloc provider; do
  if grep -Eq "^[[:space:]]+${sm}:" "$pubspec" 2>/dev/null; then
    case "$sm" in
      flutter_riverpod|riverpod) state_mgmt='riverpod' ;;
      flutter_bloc|bloc)         state_mgmt='bloc'     ;;
      provider)                  state_mgmt='provider' ;;
    esac
    break
  fi
done

has_dio=false
grep -Eq '^[[:space:]]+dio:' "$pubspec" 2>/dev/null && has_dio=true

lint_pkg=''
if grep -Eq '^[[:space:]]+very_good_analysis:' "$pubspec" 2>/dev/null; then
  lint_pkg='very_good_analysis'
elif grep -Eq '^[[:space:]]+flutter_lints:' "$pubspec" 2>/dev/null; then
  lint_pkg='flutter_lints'
elif grep -Eq '^[[:space:]]+lints:' "$pubspec" 2>/dev/null; then
  lint_pkg='lints'
fi

# ── Segments ──────────────────────────────────────────────────────────────────
dart_seg="${FG_ACCENT}${IC_DART} ${FG_TEXT}Dart"
[[ -n "$sdk_version" ]] && dart_seg+=" ${FG_ACCENT}v${sdk_version}"
[[ -n "$pkg_name" ]]    && dart_seg+=" ${FG_TEXT}${pkg_name}"
add_seg "$dart_seg"

$is_flutter && add_seg "${FG_ACCENT}${IC_FLUTTER} ${FG_TEXT}Flutter"

# Slot 5: Testing
$has_flutter_test \
  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}flutter_test"
$has_test \
  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}test"

# Slot 6: Tooling
[[ -n "$state_mgmt" ]] \
  && add_seg "${FG_ACCENT}${IC_STATE} ${FG_TEXT}${state_mgmt}"
$has_dio \
  && add_seg "${FG_ACCENT}${IC_NET} ${FG_TEXT}dio"
[[ -n "$lint_pkg" ]] \
  && add_seg "${FG_ACCENT}${IC_LINT} ${FG_TEXT}${lint_pkg}"

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
