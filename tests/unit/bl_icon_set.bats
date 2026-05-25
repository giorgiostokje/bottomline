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

@test "bl_icon_set: accepts valid variable names" {
  BOTTOMLINE_ICON_TYPE=nerd
  bl_icon_set IC_PYTHON $'\xee\x98\x86' 'X'
  [ "$IC_PYTHON" = $'\xee\x98\x86' ]
  bl_icon_set _FOO $'\xee\x98\x86' 'Y'
  [ "$_FOO" = $'\xee\x98\x86' ]
  bl_icon_set bar_42 $'\xee\x98\x86' 'Z'
  [ "$bar_42" = $'\xee\x98\x86' ]
}

@test "bl_icon_set: rejects invalid variable name and returns non-zero" {
  BOTTOMLINE_ICON_TYPE=nerd
  run bl_icon_set "PATH=evil" $'\xee\x98\x86' 'X'
  [ "$status" -ne 0 ]
}

@test "bl_icon_set: rejects shell-metacharacter name" {
  BOTTOMLINE_ICON_TYPE=nerd
  run bl_icon_set "; rm -rf /" $'\xee\x98\x86' 'X'
  [ "$status" -ne 0 ]
}

@test "bl_icon_set: rejects empty name" {
  BOTTOMLINE_ICON_TYPE=nerd
  run bl_icon_set "" $'\xee\x98\x86' 'X'
  [ "$status" -ne 0 ]
}

@test "bl_icon_set: rejects name starting with digit" {
  BOTTOMLINE_ICON_TYPE=nerd
  run bl_icon_set "42bad" $'\xee\x98\x86' 'X'
  [ "$status" -ne 0 ]
}

@test "bl_icon_set: invalid name does not clobber PATH or IFS" {
  local saved_path="$PATH" saved_ifs="$IFS"
  BOTTOMLINE_ICON_TYPE=nerd
  bl_icon_set "PATH=evil" $'\xee\x98\x86' 'X' || true
  bl_icon_set "; rm -rf /" $'\xee\x98\x86' 'X' || true
  bl_icon_set "" $'\xee\x98\x86' 'X' || true
  bl_icon_set "42bad" $'\xee\x98\x86' 'X' || true
  [ "$PATH" = "$saved_path" ]
  [ "$IFS" = "$saved_ifs" ]
}
