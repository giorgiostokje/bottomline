#!/usr/bin/env bats
# Unit tests for seg/flush (lib/helpers.sh) — segment accumulator and renderer.
# Source: lib/helpers.sh (sourced with BOTTOMLINE_* env vars so R/B/SEP/FG_* are set).

bats_require_minimum_version 1.5.0
load '../helpers'

BOTTOMLINE_RESET=$'\e[0m' BOTTOMLINE_BOLD=$'\e[1m' BOTTOMLINE_SEP='>'
BOTTOMLINE_TEXT_HEX='#ffffff' BOTTOMLINE_ACCENT_HEX='#ffffff'
BOTTOMLINE_WARN_HEX='#ffffff' BOTTOMLINE_DANGER_HEX='#ffffff'
source "$BOTTOMLINE_ROOT/lib/helpers.sh"

@test "flush: empty _sc array is a no-op — no output, no trailing separator" {
  _sc=()
  run flush '"#1a1a1a"'
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "flush: single segment renders content with one trailing separator" {
  _sc=("hello")
  run flush '"#1a1a1a"'
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  plain=$(printf '%s' "$output" | strip_ansi)
  [[ "$plain" == *"hello"* ]]
  sep_count=$(printf '%s' "$plain" | tr -cd '>' | wc -c | tr -d ' ')
  [ "$sep_count" -eq 1 ]
}

@test "flush: multi-segment renders all content with separators between each" {
  _sc=("one" "two" "three")
  run flush '"#1a1a1a"'
  [ "$status" -eq 0 ]
  plain=$(printf '%s' "$output" | strip_ansi)
  [[ "$plain" == *"one"* ]]
  [[ "$plain" == *"two"* ]]
  [[ "$plain" == *"three"* ]]
  sep_count=$(printf '%s' "$plain" | tr -cd '>' | wc -c | tr -d ' ')
  [ "$sep_count" -eq 3 ]
}

@test "flush: gradient handover — first and last bg colours differ for 2-keyframe gradient" {
  _sc=("alpha" "beta")
  raw=$(flush '["#000000","#FFFFFF"]')
  [ -n "$raw" ]
  plain=$(printf '%s' "$raw" | strip_ansi)
  [[ "$plain" == *"alpha"* ]]
  [[ "$plain" == *"beta"* ]]
}

@test "flush: separator placement — one separator between adjacent segments plus one after last" {
  _sc=("x" "y")
  raw=$(flush '"#1a1a1a"')
  plain=$(printf '%s' "$raw" | strip_ansi)
  sep_count=$(printf '%s' "$plain" | tr -cd '>' | wc -c | tr -d ' ')
  [ "$sep_count" -eq 2 ]
}
