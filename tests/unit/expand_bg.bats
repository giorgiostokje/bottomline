#!/usr/bin/env bats
# Unit tests for expand_bg (lib/helpers.sh) — gradient background interpolation.
# Source: lib/helpers.sh (sourced with BOTTOMLINE_* env vars set so FG_* init succeeds).

bats_require_minimum_version 1.5.0
load '../helpers'

BOTTOMLINE_RESET=$'\e[0m' BOTTOMLINE_BOLD=$'\e[1m' BOTTOMLINE_SEP='|'
BOTTOMLINE_TEXT_HEX='#ffffff' BOTTOMLINE_ACCENT_HEX='#ffffff'
BOTTOMLINE_WARN_HEX='#ffffff' BOTTOMLINE_DANGER_HEX='#ffffff'
source "$BOTTOMLINE_ROOT/lib/helpers.sh"

# --- string input ---

@test "expand_bg: string input repeats the hex colour n_out times" {
  run expand_bg '"#AABBCC"' 4
  [ "$status" -eq 0 ]
  [ "$output" = '["#AABBCC","#AABBCC","#AABBCC","#AABBCC"]' ]
}

@test "expand_bg: string input default n_out is 8" {
  run expand_bg '"#112233"'
  [ "$status" -eq 0 ]
  count=$(printf '%s' "$output" | jq 'length')
  [ "$count" -eq 8 ]
}

# --- array with 2 keyframes ---

@test "expand_bg: 2 keyframes interpolates linearly" {
  run expand_bg '["#000000","#FFFFFF"]' 3
  [ "$status" -eq 0 ]
  [ "$output" = '["#000000","#808080","#FFFFFF"]' ]
}

@test "expand_bg: 2-keyframe endpoints exactly match keyframe values" {
  run expand_bg '["#112233","#DDEEFF"]' 8
  [ "$status" -eq 0 ]
  first=$(printf '%s' "$output" | jq -r '.[0]')
  last=$(printf '%s' "$output" | jq -r '.[7]')
  [ "$first" = "#112233" ]
  [ "$last" = "#DDEEFF" ]
}

# --- array with 3 keyframes ---

@test "expand_bg: 3 keyframes — middle keyframe lands exactly at the right index" {
  run expand_bg '["#FF0000","#00FF00","#0000FF"]' 5
  [ "$status" -eq 0 ]
  first=$(printf '%s' "$output" | jq -r '.[0]')
  mid=$(printf '%s' "$output" | jq -r '.[2]')
  last=$(printf '%s' "$output" | jq -r '.[4]')
  [ "$first" = "#FF0000" ]
  [ "$mid" = "#00FF00" ]
  [ "$last" = "#0000FF" ]
}

@test "expand_bg: 3 keyframes produces exactly n_out stops" {
  run expand_bg '["#FF0000","#00FF00","#0000FF"]' 7
  [ "$status" -eq 0 ]
  count=$(printf '%s' "$output" | jq 'length')
  [ "$count" -eq 7 ]
}

# --- many keyframes ---

@test "expand_bg: 4 keyframes produces correct output count" {
  run expand_bg '["#100000","#001000","#000100","#000001"]' 7
  [ "$status" -eq 0 ]
  count=$(printf '%s' "$output" | jq 'length')
  [ "$count" -eq 7 ]
}

@test "expand_bg: 4-keyframe endpoints match first and last keyframe" {
  run expand_bg '["#100000","#001000","#000100","#000001"]' 7
  [ "$status" -eq 0 ]
  first=$(printf '%s' "$output" | jq -r '.[0]')
  last=$(printf '%s' "$output" | jq -r '.[6]')
  [ "$first" = "#100000" ]
  [ "$last" = "#000001" ]
}

# --- n_out boundaries ---

@test "expand_bg: n_out=1 returns single stop (first keyframe)" {
  run expand_bg '["#AABBCC","#DDEEFF"]' 1
  [ "$status" -eq 0 ]
  [ "$output" = '["#AABBCC"]' ]
}

@test "expand_bg: n_out=2 returns exactly 2 stops matching both keyframes" {
  run expand_bg '["#000000","#FFFFFF"]' 2
  [ "$status" -eq 0 ]
  [ "$output" = '["#000000","#FFFFFF"]' ]
}

@test "expand_bg: n_out=8 returns exactly 8 stops" {
  run expand_bg '["#000000","#FFFFFF"]' 8
  [ "$status" -eq 0 ]
  count=$(printf '%s' "$output" | jq 'length')
  [ "$count" -eq 8 ]
}

@test "expand_bg: n_out=16 returns exactly 16 stops" {
  run expand_bg '["#000000","#FFFFFF"]' 16
  [ "$status" -eq 0 ]
  count=$(printf '%s' "$output" | jq 'length')
  [ "$count" -eq 16 ]
}

# --- empty array (awk k==0 branch) ---

@test "expand_bg: empty array emits n_out copies of #0F0F0F" {
  run expand_bg '[]' 5
  [ "$status" -eq 0 ]
  count=$(printf '%s' "$output" | jq 'length')
  [ "$count" -eq 5 ]
  first=$(printf '%s' "$output" | jq -r '.[0]')
  [ "$first" = "#0F0F0F" ]
}

# --- *) fallback (null input) — post-Phase-1 expected behaviour ---

@test "expand_bg: null input emits n_out copies of #0F0F0F after Phase 1 fix" {
  skip "fixed in Phase 1"
  run expand_bg 'null' 5
  [ "$status" -eq 0 ]
  count=$(printf '%s' "$output" | jq 'length')
  [ "$count" -eq 5 ]
  first=$(printf '%s' "$output" | jq -r '.[0]')
  [ "$first" = "#0F0F0F" ]
}
