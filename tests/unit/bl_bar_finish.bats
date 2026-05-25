#!/usr/bin/env bats
# Unit tests for bl_bar_finish (lib/helpers.sh)

bats_require_minimum_version 1.5.0
load '../helpers'

setup() {
  BOTTOMLINE_ICON_TYPE=none
  BOTTOMLINE_RESET=$'\e[0m' BOTTOMLINE_BOLD=$'\e[1m' BOTTOMLINE_SEP='>'
  BOTTOMLINE_TEXT_HEX='#ffffff' BOTTOMLINE_ACCENT_HEX='#ffffff'
  BOTTOMLINE_WARN_HEX='#ffffff' BOTTOMLINE_DANGER_HEX='#ffffff'
  BOTTOMLINE_CACHE_DIR=$(mktemp -d)
  _bl_ttl=0
  _bl_cache=""
  source "$BOTTOMLINE_ROOT/lib/helpers.sh"
  _sc=()
}

teardown() {
  rm -rf "$BOTTOMLINE_CACHE_DIR"
}

@test "bl_bar_finish: empty _sc returns silently with no output" {
  _sc=()
  run bl_bar_finish '"#1a1a1a"'
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "bl_bar_finish: non-empty _sc emits flush output" {
  add_seg "hello"
  run bl_bar_finish '"#1a1a1a"'
  [ "$status" -eq 0 ]
  plain=$(printf '%s' "$output" | strip_ansi)
  [[ "$plain" == *"hello"* ]]
}

@test "bl_bar_finish: writes cache when _bl_ttl > 0 and output is non-empty" {
  _bl_ttl=5
  _bl_cache="$BOTTOMLINE_CACHE_DIR/bl_test_cache.txt"
  add_seg "hello"
  bl_bar_finish '"#1a1a1a"'
  [ -f "$_bl_cache" ]
  cached=$(cat "$_bl_cache" | strip_ansi)
  [[ "$cached" == *"hello"* ]]
}

@test "bl_bar_finish: no cache write when _bl_ttl=0" {
  _bl_ttl=0
  _bl_cache="$BOTTOMLINE_CACHE_DIR/bl_test_cache.txt"
  add_seg "hello"
  bl_bar_finish '"#1a1a1a"'
  [ ! -f "$_bl_cache" ]
}
