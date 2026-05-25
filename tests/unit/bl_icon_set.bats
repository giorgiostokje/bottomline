#!/usr/bin/env bats
# Unit tests for bl_icon_set (lib/helpers.sh)

bats_require_minimum_version 1.5.0
load '../helpers'

setup() {
  BOTTOMLINE_ICON_TYPE=none
  BOTTOMLINE_RESET=$'\e[0m' BOTTOMLINE_BOLD=$'\e[1m' BOTTOMLINE_SEP='>'
  BOTTOMLINE_TEXT_HEX='#ffffff' BOTTOMLINE_ACCENT_HEX='#ffffff'
  BOTTOMLINE_WARN_HEX='#ffffff' BOTTOMLINE_DANGER_HEX='#ffffff'
  source "$BOTTOMLINE_ROOT/lib/helpers.sh"
}

@test "bl_icon_set: nerd type sets nerd value" {
  BOTTOMLINE_ICON_TYPE=nerd
  bl_icon_set IC_FOO $'\xee\x98\x86' 'X'
  [ "$IC_FOO" = $'\xee\x98\x86' ]
}

@test "bl_icon_set: emoji type sets emoji value" {
  BOTTOMLINE_ICON_TYPE=emoji
  bl_icon_set IC_FOO $'\xee\x98\x86' '🐍'
  [ "$IC_FOO" = '🐍' ]
}

@test "bl_icon_set: none type sets empty default" {
  BOTTOMLINE_ICON_TYPE=none
  bl_icon_set IC_FOO $'\xee\x98\x86' '🐍'
  [ "$IC_FOO" = '' ]
}

@test "bl_icon_set: none type with fallback sets fallback" {
  BOTTOMLINE_ICON_TYPE=none
  bl_icon_set IC_WARN $'\xef\x81\xb1' '⚠' '!'
  [ "$IC_WARN" = '!' ]
}

@test "bl_icon_set: nerd type ignores fallback" {
  BOTTOMLINE_ICON_TYPE=nerd
  bl_icon_set IC_WARN $'\xef\x81\xb1' '⚠' '!'
  [ "$IC_WARN" = $'\xef\x81\xb1' ]
}

@test "bl_icon_set: emoji type ignores fallback" {
  BOTTOMLINE_ICON_TYPE=emoji
  bl_icon_set IC_WARN $'\xef\x81\xb1' '⚠' '!'
  [ "$IC_WARN" = '⚠' ]
}

@test "bl_icon_set: unset BOTTOMLINE_ICON_TYPE falls through to default" {
  unset BOTTOMLINE_ICON_TYPE
  bl_icon_set IC_FOO $'\xee\x98\x86' '🐍'
  [ "$IC_FOO" = '' ]
}

@test "bl_icon_set: multiple calls set independent variables" {
  BOTTOMLINE_ICON_TYPE=nerd
  bl_icon_set IC_A $'\xee\x98\x86' 'A'
  bl_icon_set IC_B $'\xef\x81\xac' 'B'
  [ "$IC_A" = $'\xee\x98\x86' ]
  [ "$IC_B" = $'\xef\x81\xac' ]
}
