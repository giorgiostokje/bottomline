#!/usr/bin/env bats
# Unit tests for bl_bar_init (lib/helpers.sh)

bats_require_minimum_version 1.5.0
load '../helpers'

setup() {
  BOTTOMLINE_ICON_TYPE=none
  BOTTOMLINE_RESET=$'\e[0m' BOTTOMLINE_BOLD=$'\e[1m' BOTTOMLINE_SEP='>'
  BOTTOMLINE_TEXT_HEX='#ffffff' BOTTOMLINE_ACCENT_HEX='#ffffff'
  BOTTOMLINE_WARN_HEX='#ffffff' BOTTOMLINE_DANGER_HEX='#ffffff'
  BOTTOMLINE_BAR_COLORS=
  BOTTOMLINE_GRADIENT=
  BOTTOMLINE_BAR_REFRESH_MINUTES=0
  BOTTOMLINE_CACHE_DIR=$(mktemp -d)
  PROJ="/tmp/_bl_test_proj_${RANDOM}"
  mkdir -p "$PROJ"
  source "$BOTTOMLINE_ROOT/lib/helpers.sh"
}

teardown() {
  rm -rf "$PROJ" "$BOTTOMLINE_CACHE_DIR"
}

@test "bl_bar_init: cache miss sets FG_TEXT and FG_ACCENT from fallbacks" {
  bl_bar_init python "#c8dff0" "#ffd740" '["#0c1e30","#183352"]' \
    "$PROJ/pyproject.toml"
  plain_text=$(printf '%s' "$FG_TEXT" | strip_ansi)
  [[ -n "$FG_TEXT" ]]
  [[ -n "$FG_ACCENT" ]]
  [[ "$_bar_gradient" == '["#0c1e30","#183352"]' ]]
}

@test "bl_bar_init: respects BOTTOMLINE_BAR_COLORS=1 (uses BOTTOMLINE_GRADIENT)" {
  BOTTOMLINE_BAR_COLORS=1
  BOTTOMLINE_GRADIENT='"#1a1a1a"'
  bl_bar_init python "#c8dff0" "#ffd740" '["#0c1e30","#183352"]' \
    "$PROJ/pyproject.toml"
  [[ "$_bar_gradient" == '"#1a1a1a"' ]]
}

@test "bl_bar_init: _bl_ttl=0 disables caching (no _bl_cache set)" {
  BOTTOMLINE_BAR_REFRESH_MINUTES=0
  bl_bar_init python "#c8dff0" "#ffd740" '["#0c1e30","#183352"]' \
    "$PROJ/pyproject.toml"
  [[ "$_bl_ttl" -eq 0 ]]
}

@test "bl_bar_init: _bl_ttl from env var" {
  BOTTOMLINE_BAR_REFRESH_MINUTES=10
  bl_bar_init python "#c8dff0" "#ffd740" '["#0c1e30","#183352"]' \
    "$PROJ/pyproject.toml"
  [[ "$_bl_ttl" -eq 10 ]]
}

@test "bl_bar_init: cache hit prints cached output and exits" {
  BOTTOMLINE_BAR_REFRESH_MINUTES=5
  local cache_file
  cache_file=$(bl_cache_path "python" 5 "$PROJ" "$PROJ/pyproject.toml")
  printf 'cached_output' > "$cache_file"
  run bash -c '
    BOTTOMLINE_ICON_TYPE=none
    BOTTOMLINE_RESET="" BOTTOMLINE_BOLD="" BOTTOMLINE_SEP=">"
    BOTTOMLINE_TEXT_HEX="#ffffff" BOTTOMLINE_ACCENT_HEX="#ffffff"
    BOTTOMLINE_WARN_HEX="#ffffff" BOTTOMLINE_DANGER_HEX="#ffffff"
    BOTTOMLINE_BAR_COLORS=
    BOTTOMLINE_GRADIENT=
    BOTTOMLINE_BAR_REFRESH_MINUTES=5
    BOTTOMLINE_CACHE_DIR="'"$BOTTOMLINE_CACHE_DIR"'"
    PROJ="'"$PROJ"'"
    source "'"$(cd "$BOTTOMLINE_ROOT" && pwd)"'/lib/helpers.sh"
    bl_bar_init python "#c8dff0" "#ffd740" '"'"'["#0c1e30","#183352"]'"'"' \
      "$PROJ/pyproject.toml"
    echo "DID_NOT_EXIT"
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"cached_output"* ]]
  [[ "$output" != *"DID_NOT_EXIT"* ]]
}
