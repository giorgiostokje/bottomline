#!/usr/bin/env bats
# Unit tests for make_fg (lib/helpers.sh) — r g b string to ANSI fg escape.
# Source: lib/helpers.sh (sourced with BOTTOMLINE_* env vars so FG_* init succeeds).

bats_require_minimum_version 1.5.0
load '../helpers'

BOTTOMLINE_RESET=$'\e[0m' BOTTOMLINE_BOLD=$'\e[1m' BOTTOMLINE_SEP='|'
BOTTOMLINE_TEXT_HEX='#ffffff' BOTTOMLINE_ACCENT_HEX='#ffffff'
BOTTOMLINE_WARN_HEX='#ffffff' BOTTOMLINE_DANGER_HEX='#ffffff'
source "$BOTTOMLINE_ROOT/lib/helpers.sh"

@test "make_fg: converts r g b string to ANSI fg escape" {
  run make_fg "255 128 0"
  expected=$(printf '\e[38;2;255;128;0m')
  [ "$output" = "$expected" ]
}

@test "make_fg: zero values produce valid escape" {
  run make_fg "0 0 0"
  expected=$(printf '\e[38;2;0;0;0m')
  [ "$output" = "$expected" ]
}

@test "make_fg: max values produce valid escape" {
  run make_fg "255 255 255"
  expected=$(printf '\e[38;2;255;255;255m')
  [ "$output" = "$expected" ]
}
