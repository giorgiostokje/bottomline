#!/usr/bin/env bats
# Unit tests for threshold_resolve — name-based extraction from candidate files.
# Also sources resolve_color since threshold_resolve calls it.
# ANSI primitives defined locally; decode_icon from lib/functions.sh.

bats_require_minimum_version 1.5.0
load '../helpers'

_bl_extract() {
  local name="$1"; shift
  local f body
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    body=$(sed -n "/^${name}() {\$/,/^\}$/p" "$f")
    [[ -n "$body" ]] && eval "$body" && return 0
  done
  return 1
}

setup() {
  source "$BOTTOMLINE_ROOT/lib/functions.sh"

  bg3() { printf '\e[48;2;%d;%d;%dm' "$1" "$2" "$3"; }
  fg3() { printf '\e[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
  hex_to_rgb() {
    local h="${1#'#'}"
    [[ ${#h} -ne 6 ]] && printf '128 128 128' && return
    printf '%d %d %d' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
  }
  make_fg() { local r g b; read -r r g b <<< "$1"; fg3 "$r" "$g" "$b"; }

  CFG_TEXT_HEX='#cccccc'
  CFG_ACCENT_HEX='#ff0000'
  CFG_WARN_HEX='#ffff00'
  CFG_CRIT_HEX='#ff0000'
  FG_TEXT=$(make_fg "$(hex_to_rgb "$CFG_TEXT_HEX")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "$CFG_ACCENT_HEX")")
  FG_WARN=$(make_fg "$(hex_to_rgb "$CFG_WARN_HEX")")
  FG_CRIT=$(make_fg "$(hex_to_rgb "$CFG_CRIT_HEX")")

  _bl_extract resolve_color "$BOTTOMLINE_ROOT/lib/colors.sh" "$BOTTOMLINE_ROOT/bottomline.sh"
  _bl_extract threshold_resolve "$BOTTOMLINE_ROOT/lib/segments.sh" "$BOTTOMLINE_ROOT/bottomline.sh"
}

@test "threshold_resolve: single matching threshold sets color and icon" {
  CFG_ICON_TYPE=nerd
  local thresholds='{"80":{"color":"danger","icon":{"nerd":"e0b4"}}}'
  threshold_resolve "$thresholds" 85
  [ "$THR_COLOR_ANSI" = "$FG_CRIT" ]
  expected_icon=$(decode_icon "e0b4")
  [ "$THR_ICON" = "$expected_icon" ]
}

@test "threshold_resolve: multiple thresholds — highest matching wins" {
  CFG_ICON_TYPE=nerd
  local thresholds='{"50":{"color":"warn","icon":{"nerd":"26a0"}},"80":{"color":"danger","icon":{"nerd":"e0b4"}}}'
  threshold_resolve "$thresholds" 90
  [ "$THR_COLOR_ANSI" = "$FG_CRIT" ]
}

@test "threshold_resolve: lower threshold matches when value is between two" {
  CFG_ICON_TYPE=nerd
  local thresholds='{"50":{"color":"warn","icon":{"nerd":"26a0"}},"80":{"color":"danger","icon":{"nerd":"e0b4"}}}'
  threshold_resolve "$thresholds" 60
  [ "$THR_COLOR_ANSI" = "$FG_WARN" ]
}

@test "threshold_resolve: value below all thresholds defaults to FG_TEXT and empty icon" {
  CFG_ICON_TYPE=nerd
  local thresholds='{"50":{"color":"warn","icon":{"nerd":"26a0"}}}'
  threshold_resolve "$thresholds" 10
  [ "$THR_COLOR_ANSI" = "$FG_TEXT" ]
  [ "$THR_ICON" = "" ]
}

@test "threshold_resolve: emoji icon type selects emoji variant" {
  CFG_ICON_TYPE=emoji
  local thresholds='{"80":{"color":"danger","icon":{"emoji":"1f6d1"}}}'
  threshold_resolve "$thresholds" 85
  expected_icon=$(decode_icon "1f6d1")
  [ "$THR_ICON" = "$expected_icon" ]
}

@test "threshold_resolve: none icon type produces empty icon" {
  CFG_ICON_TYPE=none
  local thresholds='{"80":{"color":"danger","icon":{"nerd":"e0b4","emoji":"1f6d1"}}}'
  threshold_resolve "$thresholds" 85
  [ "$THR_ICON" = "" ]
}
