#!/usr/bin/env bats
# Unit tests for decode_icon (lib/functions.sh)

bats_require_minimum_version 1.5.0
load '../helpers'

source "$BOTTOMLINE_ROOT/lib/functions.sh"

# ---------------------------------------------------------------------------
# Hex codepoints are decoded to Unicode characters
# ---------------------------------------------------------------------------

@test "decode_icon: 26a0 decodes to warning sign ⚠" {
  run decode_icon "26a0"
  [ "$output" = "⚠" ]
}

@test "decode_icon: 1f6d1 decodes to stop sign 🛑" {
  run decode_icon "1f6d1"
  [ "$output" = "🛑" ]
}

@test "decode_icon: e0b4 decodes to right-rounded separator glyph" {
  expected=$(printf '\xee\x82\xb4')   # U+E0B4
  run decode_icon "e0b4"
  [ "$output" = "$expected" ]
}

@test "decode_icon: uppercase hex is accepted" {
  run decode_icon "26A0"
  [ "$output" = "⚠" ]
}

# ---------------------------------------------------------------------------
# Non-hex strings are passed through unchanged
# ---------------------------------------------------------------------------

@test "decode_icon: literal emoji is returned as-is" {
  run decode_icon "⚡"
  [ "$output" = "⚡" ]
}

@test "decode_icon: 3-char string that looks like partial hex is returned as-is" {
  run decode_icon "abc"
  [ "$output" = "abc" ]
}

@test "decode_icon: 7-char hex string is too long, returned as-is" {
  run decode_icon "1234567"
  [ "$output" = "1234567" ]
}

@test "decode_icon: empty string produces empty output" {
  run decode_icon ""
  [ "$output" = "" ]
}
