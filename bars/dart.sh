#!/usr/bin/env bash
# Bottomline bar: Dart / Flutter ecosystem bar
# Only renders when the project contains a pubspec.yaml.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init dart "#c5e8ff" "#0175C2" '["#042B59","#011F3F"]' \
  "$PROJ/pubspec.yaml" "$PROJ/pubspec.lock"

[[ ! -f "$PROJ/pubspec.yaml" ]] && exit 0

# Returns the locked version of a dep from pubspec.lock, or constraint from pubspec.yaml.
pubspec_dep_version() {
  local pkg="$1"
  if [[ -f "$PROJ/pubspec.lock" ]]; then
    awk -v p="$pkg" '
      /^  [a-z_]/ { cur=substr($1,1,length($1)-1) }
      cur==p && /version:/ { match($0,/[0-9]+\.[0-9]+(\.[0-9]+)?/,a); print a[0]; exit }
    ' "$PROJ/pubspec.lock" 2>/dev/null
    return
  fi
  awk -v p="$pkg" '
    $0 ~ "^[[:space:]]+"p":" { match($0,/[0-9]+\.[0-9]+(\.[0-9]+)?/,a); print a[0]; exit }
  ' "$PROJ/pubspec.yaml" 2>/dev/null
}

bl_icon_set IC_DART   $'\xef\x88\x99' '🎯'  # U+F219  nf-fa-diamond
bl_icon_set IC_FLUTTER $'\xef\x84\x8b' '🐦' # U+F10B  nf-fa-mobile
bl_icon_set IC_TEST   $'\xef\x81\x80' '🧪'  # U+F040  nf-fa-pencil
bl_icon_set IC_STATE  $'\xef\x84\xa9' '🧭'  # U+F129  nf-fa-info (state mgmt)
bl_icon_set IC_NET    $'\xef\x82\xac' '🌐'  # U+F0AC  nf-fa-globe (HTTP)
bl_icon_set IC_LINT   $'\xef\x80\x8c' '✓'   # U+F00C  nf-fa-check

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
state_mgmt_display=''
state_mgmt_version=''
for sm in flutter_riverpod riverpod flutter_bloc bloc provider; do
  if grep -Eq "^[[:space:]]+${sm}:" "$pubspec" 2>/dev/null; then
    case "$sm" in
      flutter_riverpod|riverpod) state_mgmt='riverpod';  state_mgmt_display='Riverpod' ;;
      flutter_bloc|bloc)         state_mgmt='bloc';      state_mgmt_display='BLoC'     ;;
      provider)                  state_mgmt='provider';  state_mgmt_display='Provider' ;;
    esac
    break
  fi
done

if [[ -n "$state_mgmt" ]]; then
  case "$state_mgmt" in
    riverpod) state_mgmt_version=$(pubspec_dep_version "flutter_riverpod")
              [[ -z "$state_mgmt_version" ]] && state_mgmt_version=$(pubspec_dep_version "riverpod") ;;
    bloc)     state_mgmt_version=$(pubspec_dep_version "flutter_bloc")
              [[ -z "$state_mgmt_version" ]] && state_mgmt_version=$(pubspec_dep_version "bloc") ;;
    provider) state_mgmt_version=$(pubspec_dep_version "provider") ;;
  esac
fi

has_dio=false
dio_version=''
grep -Eq '^[[:space:]]+dio:' "$pubspec" 2>/dev/null && has_dio=true
$has_dio && dio_version=$(pubspec_dep_version "dio")

lint_pkg=''
lint_pkg_version=''
if grep -Eq '^[[:space:]]+very_good_analysis:' "$pubspec" 2>/dev/null; then
  lint_pkg='very_good_analysis'
elif grep -Eq '^[[:space:]]+flutter_lints:' "$pubspec" 2>/dev/null; then
  lint_pkg='flutter_lints'
elif grep -Eq '^[[:space:]]+lints:' "$pubspec" 2>/dev/null; then
  lint_pkg='lints'
fi
[[ -n "$lint_pkg" ]] && lint_pkg_version=$(pubspec_dep_version "$lint_pkg")

# ── Segments ──────────────────────────────────────────────────────────────────
dart_seg="${FG_ACCENT}${IC_DART} ${FG_TEXT}Dart"
[[ -n "$sdk_version" ]] && dart_seg+=" ${N}${FG_ACCENT}>=${sdk_version}"
[[ -n "$pkg_name" ]]    && dart_seg+=" ${FG_TEXT}${pkg_name}"
add_seg "$dart_seg"

$is_flutter && add_seg "${FG_ACCENT}${IC_FLUTTER} ${FG_TEXT}Flutter"

# Slot 5: Testing
$has_flutter_test \
  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}flutter_test"
$has_test \
  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}test"

# Slot 6: Tooling
# static analysis first
[[ -n "$lint_pkg" ]] && bl_version_seg "$IC_LINT" "$lint_pkg" "$lint_pkg_version"
# business logic / state management
[[ -n "$state_mgmt" ]] && bl_version_seg "$IC_STATE" "$state_mgmt_display" "$state_mgmt_version"
# HTTP client
$has_dio && bl_version_seg "$IC_NET" Dio "$dio_version"

bl_bar_finish "$_bar_gradient"
