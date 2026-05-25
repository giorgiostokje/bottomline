#!/usr/bin/env bats
# Unit tests for bl_version_seg (lib/helpers.sh)

bats_require_minimum_version 1.5.0
load '../helpers'

setup() {
  BOTTOMLINE_ICON_TYPE=none
  BOTTOMLINE_RESET=$'\e[0m' BOTTOMLINE_BOLD=$'\e[1m' BOTTOMLINE_SEP='>'
  BOTTOMLINE_TEXT_HEX='#ffffff' BOTTOMLINE_ACCENT_HEX='#ffffff'
  BOTTOMLINE_WARN_HEX='#ffffff' BOTTOMLINE_DANGER_HEX='#ffffff'
  source "$BOTTOMLINE_ROOT/lib/helpers.sh"
  _sc=()
}

@test "bl_version_seg: icon + label + version" {
  IC_PYTHON=$'\xee\x98\x86'
  bl_version_seg "$IC_PYTHON" Python "3.11"
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Python"* ]]
  [[ "$plain" == *"v3.11"* ]]
}

@test "bl_version_seg: icon + label only (empty version)" {
  IC_PYTHON=$'\xee\x98\x86'
  bl_version_seg "$IC_PYTHON" Python ""
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Python"* ]]
  [[ "$plain" != *"v"* ]]
}

@test "bl_version_seg: no icon (icon-type=none)" {
  bl_version_seg "" Python "3.11"
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == "Python v3.11" ]]
}

@test "bl_version_seg: no icon, no version" {
  bl_version_seg "" Python ""
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == "Python" ]]
}

@test "bl_version_seg: multiple calls accumulate segments" {
  bl_version_seg "" Python "3.11"
  bl_version_seg "" RSpec ""
  [ ${#_sc[@]} -eq 2 ]
}
