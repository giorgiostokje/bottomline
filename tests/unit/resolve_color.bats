#!/usr/bin/env bats
# Unit tests for resolve_color_hex and resolve_color — name-based extraction from
# candidate files. ANSI primitives defined locally; decode_icon from lib/functions.sh.

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

  _bl_extract resolve_color_hex "$BOTTOMLINE_ROOT/lib/colors.sh" "$BOTTOMLINE_ROOT/bottomline.sh"
  _bl_extract resolve_color "$BOTTOMLINE_ROOT/lib/colors.sh" "$BOTTOMLINE_ROOT/bottomline.sh"
}

# --- resolve_color_hex ---

@test "resolve_color_hex: text returns CFG_TEXT_HEX" {
  run resolve_color_hex text
  [ "$output" = "#cccccc" ]
}

@test "resolve_color_hex: accent returns CFG_ACCENT_HEX" {
  run resolve_color_hex accent
  [ "$output" = "#ff0000" ]
}

@test "resolve_color_hex: warn returns CFG_WARN_HEX" {
  run resolve_color_hex warn
  [ "$output" = "#ffff00" ]
}

@test "resolve_color_hex: warning alias returns CFG_WARN_HEX" {
  run resolve_color_hex warning
  [ "$output" = "#ffff00" ]
}

@test "resolve_color_hex: crit returns CFG_CRIT_HEX" {
  run resolve_color_hex crit
  [ "$output" = "#ff0000" ]
}

@test "resolve_color_hex: danger alias returns CFG_CRIT_HEX" {
  run resolve_color_hex danger
  [ "$output" = "#ff0000" ]
}

@test "resolve_color_hex: hex string passes through unchanged" {
  run resolve_color_hex "#ABCDEF"
  [ "$output" = "#ABCDEF" ]
}

@test "resolve_color_hex: unknown value passes through unchanged" {
  run resolve_color_hex "foobar"
  [ "$output" = "foobar" ]
}

# --- resolve_color ---

@test "resolve_color: text returns FG_TEXT" {
  run resolve_color text
  [ "$output" = "$FG_TEXT" ]
}

@test "resolve_color: accent returns FG_ACCENT" {
  run resolve_color accent
  [ "$output" = "$FG_ACCENT" ]
}

@test "resolve_color: warn returns FG_WARN" {
  run resolve_color warn
  [ "$output" = "$FG_WARN" ]
}

@test "resolve_color: warning alias returns FG_WARN" {
  run resolve_color warning
  [ "$output" = "$FG_WARN" ]
}

@test "resolve_color: crit returns FG_CRIT" {
  run resolve_color crit
  [ "$output" = "$FG_CRIT" ]
}

@test "resolve_color: danger returns FG_CRIT" {
  run resolve_color danger
  [ "$output" = "$FG_CRIT" ]
}

@test "resolve_color: hex string resolves via make_fg" {
  run resolve_color "#ABCDEF"
  expected=$(make_fg "$(hex_to_rgb "#ABCDEF")")
  [ "$output" = "$expected" ]
}

@test "resolve_color: unknown value defaults to FG_TEXT" {
  run resolve_color "foobar"
  [ "$output" = "$FG_TEXT" ]
}
