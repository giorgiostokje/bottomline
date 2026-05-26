#!/usr/bin/env bats
# Unit tests for get_icon — name-based extraction from candidate files.
# NF_*/EM_* constants and CFG_ICON_OVR set locally; decode_icon from lib/functions.sh.

bats_require_minimum_version 1.5.0
load '../helpers'

setup() {
  source "$BOTTOMLINE_ROOT/lib/functions.sh"

  NF_MODEL=$'\xef\x8b\x9b'   NF_BOLT=$'\xef\x83\xa7'   NF_CTX=$'\xef\x82\xae'
  NF_DIR=$'\xef\x81\xbc'     NF_GIT=$'\xee\x82\xa0'    NF_UP=$'\xef\x81\xa2'
  NF_DOWN=$'\xef\x81\xa3'    NF_CLOCK=$'\xef\x80\x97'  NF_CAL=$'\xef\x81\xb3'
  NF_COST=$'\xef\x83\x96'    NF_WARN=$'\xef\x81\xb1'   NF_DANGER=$'\xef\x81\x9e'

  EM_MODEL='🖥'  EM_BOLT='⚡'  EM_CTX='◈'   EM_DIR='📁'  EM_GIT='⎇'
  EM_UP='↑'      EM_DOWN='↓'  EM_CLOCK='⏱' EM_CAL='📅'  EM_COST='💰'
  EM_WARN='⚠'   EM_DANGER='🛑'

  CFG_ICON_OVR='{}'

  _bl_extract get_icon "$BOTTOMLINE_ROOT/lib/icons.sh" "$BOTTOMLINE_ROOT/bottomline.sh"
}

@test "get_icon: nerd type returns nerd font glyph for model" {
  CFG_ICON_TYPE=nerd
  run get_icon model
  [ "$output" = "$NF_MODEL" ]
}

@test "get_icon: nerd type returns nerd font glyph for effort" {
  CFG_ICON_TYPE=nerd
  run get_icon effort
  [ "$output" = "$NF_BOLT" ]
}

@test "get_icon: emoji type returns emoji glyph for model" {
  CFG_ICON_TYPE=emoji
  run get_icon model
  [ "$output" = "$EM_MODEL" ]
}

@test "get_icon: emoji type returns emoji glyph for cost" {
  CFG_ICON_TYPE=emoji
  run get_icon cost
  [ "$output" = "$EM_COST" ]
}

@test "get_icon: none type returns empty string" {
  CFG_ICON_TYPE=none
  run get_icon model
  [ "$output" = "" ]
}

@test "get_icon: none type with known name still returns empty" {
  CFG_ICON_TYPE=none
  run get_icon danger
  [ "$output" = "" ]
}

@test "get_icon: unknown name returns name verbatim in nerd mode" {
  CFG_ICON_TYPE=nerd
  run get_icon "custom_thing"
  [ "$output" = "custom_thing" ]
}

@test "get_icon: unknown name returns name verbatim in emoji mode" {
  CFG_ICON_TYPE=emoji
  run get_icon "custom_thing"
  [ "$output" = "custom_thing" ]
}

@test "get_icon: tokens_in falls back to shared tokens override" {
  CFG_ICON_TYPE=nerd
  CFG_ICON_OVR='{"tokens":"e0b4"}'
  run get_icon tokens_in
  expected=$(decode_icon "e0b4")
  [ "$output" = "$expected" ]
}

@test "get_icon: tokens_out falls back to shared tokens override" {
  CFG_ICON_TYPE=nerd
  CFG_ICON_OVR='{"tokens":"e0b4"}'
  run get_icon tokens_out
  expected=$(decode_icon "e0b4")
  [ "$output" = "$expected" ]
}

@test "get_icon: direct override takes precedence over tokens fallback" {
  CFG_ICON_TYPE=nerd
  CFG_ICON_OVR='{"tokens_in":"e0b4","tokens":"26a0"}'
  run get_icon tokens_in
  expected=$(decode_icon "e0b4")
  [ "$output" = "$expected" ]
}

@test "get_icon: override with literal glyph passes through" {
  CFG_ICON_TYPE=nerd
  CFG_ICON_OVR='{"model":"🖥"}'
  run get_icon model
  [ "$output" = "🖥" ]
}
