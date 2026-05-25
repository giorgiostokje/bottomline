#!/usr/bin/env bats
# Unit tests for bl_seg, bl_data_seg, and the bl_version_seg alias (lib/helpers.sh)

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

# ── bl_seg ────────────────────────────────────────────────────────────────────

@test "bl_seg: icon + label" {
  bl_seg '>' Label
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Label"* ]]
  [[ "$plain" != *"v"* ]]
}

@test "bl_seg: icon + label + version" {
  bl_seg '>' Label "3.11"
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Label"* ]]
  [[ "$plain" == *"v3.11"* ]]
}

@test "bl_seg: no icon (icon-type=none)" {
  bl_seg '' Label "3.11"
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == "Label v3.11" ]]
}

@test "bl_seg: no icon, no version" {
  bl_seg '' Label ''
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == "Label" ]]
}

@test "bl_seg: warn state with version — trailing warning triangle" {
  bl_seg '>' Label "1.0" warn
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Label"* ]]
  [[ "$plain" == *"v1.0"* ]]
  [[ "$plain" == *"⚠"* ]]
}

@test "bl_seg: warn state without version — trailing warning triangle" {
  bl_seg '>' Label '' warn
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Label"* ]]
  [[ "$plain" == *"⚠"* ]]
}

@test "bl_seg: crit state with version — trailing stop sign" {
  bl_seg '>' Label "2.0" crit
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Label"* ]]
  [[ "$plain" == *"v2.0"* ]]
  [[ "$plain" == *"🛑"* ]]
}

@test "bl_seg: crit state without version — trailing stop sign" {
  bl_seg '>' Label '' crit
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Label"* ]]
  [[ "$plain" == *"🛑"* ]]
}

@test "bl_seg: unknown state — no trailing icon, no crash" {
  bl_seg '>' Label "1.0" unknown
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Label"* ]]
  [[ "$plain" != *"⚠"* ]]
  [[ "$plain" != *"🛑"* ]]
}

@test "bl_seg: multiple calls accumulate segments" {
  bl_seg '' Go "1.22"
  bl_seg '' Ginkgo "2.1"
  [ ${#_sc[@]} -eq 2 ]
}

# ── bl_data_seg ───────────────────────────────────────────────────────────────

@test "bl_data_seg: icon + primary only" {
  bl_data_seg '>' Primary
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Primary"* ]]
}

@test "bl_data_seg: icon + primary + qualifier (no bullet)" {
  bl_data_seg '>' Primary Qualifier
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Primary"* ]]
  [[ "$plain" == *"Qualifier"* ]]
  [[ "$plain" != *"·"* ]]
}

@test "bl_data_seg: icon + primary + qualifier (with bullet)" {
  bl_data_seg '>' Primary Qualifier '' 1
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Primary"* ]]
  [[ "$plain" == *"·"* ]]
  [[ "$plain" == *"Qualifier"* ]]
}

@test "bl_data_seg: warn state with qualifier — trailing warning triangle" {
  bl_data_seg '>' Primary Qualifier warn 1
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Primary"* ]]
  [[ "$plain" == *"Qualifier"* ]]
  [[ "$plain" == *"⚠"* ]]
}

@test "bl_data_seg: warn state without qualifier — trailing warning triangle" {
  bl_data_seg '>' Primary '' warn
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Primary"* ]]
  [[ "$plain" == *"⚠"* ]]
}

@test "bl_data_seg: crit state with qualifier — trailing stop sign" {
  bl_data_seg '>' Primary "API error" crit 1
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Primary"* ]]
  [[ "$plain" == *"API error"* ]]
  [[ "$plain" == *"🛑"* ]]
}

@test "bl_data_seg: no icon (icon-type=none)" {
  bl_data_seg '' Primary Qualifier '' 1
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Primary"* ]]
  [[ "$plain" == *"·"* ]]
  [[ "$plain" == *"Qualifier"* ]]
}

# ── bl_version_seg alias ──────────────────────────────────────────────────────

@test "bl_version_seg alias: delegates to bl_seg, output matches" {
  bl_version_seg '>' Python "3.11"
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"Python"* ]]
  [[ "$plain" == *"v3.11"* ]]
}

@test "bl_version_seg alias: no version" {
  bl_version_seg '>' RSpec ''
  [ ${#_sc[@]} -eq 1 ]
  plain=$(printf '%s' "${_sc[0]}" | strip_ansi)
  [[ "$plain" == *"RSpec"* ]]
  [[ "$plain" != *"v"* ]]
}
