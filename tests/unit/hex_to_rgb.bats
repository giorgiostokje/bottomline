#!/usr/bin/env bats
# Unit tests for hex_to_rgb (lib/helpers.sh) — hex colour to r g b conversion.
# Source: lib/helpers.sh (sourced with BOTTOMLINE_* env vars so FG_* init succeeds).

bats_require_minimum_version 1.5.0
load '../helpers'

BOTTOMLINE_RESET=$'\e[0m' BOTTOMLINE_BOLD=$'\e[1m' BOTTOMLINE_SEP='|'
BOTTOMLINE_TEXT_HEX='#ffffff' BOTTOMLINE_ACCENT_HEX='#ffffff'
BOTTOMLINE_WARN_HEX='#ffffff' BOTTOMLINE_DANGER_HEX='#ffffff'
source "$BOTTOMLINE_ROOT/lib/helpers.sh"

@test "hex_to_rgb: valid 6-char with # prefix" {
  run hex_to_rgb "#AABBCC"
  [ "$output" = "170 187 204" ]
}

@test "hex_to_rgb: valid 6-char without # prefix" {
  run hex_to_rgb "AABBCC"
  [ "$output" = "170 187 204" ]
}

@test "hex_to_rgb: malformed short string returns fallback 128 128 128" {
  run hex_to_rgb "ABC"
  [ "$output" = "128 128 128" ]
}

@test "hex_to_rgb: empty string returns fallback 128 128 128" {
  run hex_to_rgb ""
  [ "$output" = "128 128 128" ]
}

@test "hex_to_rgb: uppercase hex" {
  run hex_to_rgb "FF0000"
  [ "$output" = "255 0 0" ]
}

@test "hex_to_rgb: lowercase hex" {
  run hex_to_rgb "ff0000"
  [ "$output" = "255 0 0" ]
}

@test "hex_to_rgb: mixed case hex" {
  run hex_to_rgb "Ff00Aa"
  [ "$output" = "255 0 170" ]
}
