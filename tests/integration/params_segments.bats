#!/usr/bin/env bats
# Integration tests for bars[].params resolution and BOTTOMLINE_BAR_SEGMENTS export.

bats_require_minimum_version 1.5.0
load '../helpers'

setup() {
  setup_fake_home
  _FAKE_BAR=$(mktemp /tmp/bl_bar_XXXXX.sh)
  chmod +x "$_FAKE_BAR"
}

teardown() {
  teardown_fake_home
  rm -f "$_FAKE_BAR"
}

@test "params: literal string passes through unchanged" {
  printf '#!/usr/bin/env bash\nval="${BOTTOMLINE_BAR_PARAMS:-}"; [[ -z "$val" ]] && val='"'"'{}'"'"'; printf "%%s" "$val"\n' > "$_FAKE_BAR"
  local cfg
  cfg=$(jq -n --arg s "$_FAKE_BAR" '{"bars":[{"script":$s,"params":{"key":"plain_literal"}}]}')
  bl_run '{}' "$cfg"
  [[ "$BL_OUTPUT" == *'plain_literal'* ]]
}

@test "params: file:/abs/path reads file contents" {
  local token_file; token_file=$(mktemp)
  printf 'file_secret' > "$token_file"
  printf '#!/usr/bin/env bash\nval="${BOTTOMLINE_BAR_PARAMS:-}"; [[ -z "$val" ]] && val='"'"'{}'"'"'; printf "%%s" "$val"\n' > "$_FAKE_BAR"
  local cfg
  cfg=$(jq -n --arg s "$_FAKE_BAR" --arg p "$token_file" \
    '{"bars":[{"script":$s,"params":{"key":("file:" + $p)}}]}')
  bl_run '{}' "$cfg"
  rm -f "$token_file"
  [[ "$BL_OUTPUT" == *'file_secret'* ]]
}

@test "params: file:~/path expands tilde and reads file" {
  mkdir -p "$FAKE_HOME/.config"
  printf 'tilde_secret' > "$FAKE_HOME/.config/token"
  printf '#!/usr/bin/env bash\nval="${BOTTOMLINE_BAR_PARAMS:-}"; [[ -z "$val" ]] && val='"'"'{}'"'"'; printf "%%s" "$val"\n' > "$_FAKE_BAR"
  local cfg
  cfg=$(jq -n --arg s "$_FAKE_BAR" \
    '{"bars":[{"script":$s,"params":{"key":"file:~/.config/token"}}]}')
  HOME="$FAKE_HOME" bl_run '{}' "$cfg"
  [[ "$BL_OUTPUT" == *'tilde_secret'* ]]
}

@test "params: non-string values pass through unmodified" {
  printf '#!/usr/bin/env bash\nval="${BOTTOMLINE_BAR_PARAMS:-}"; [[ -z "$val" ]] && val='"'"'{}'"'"'; printf "%%s" "$val"\n' > "$_FAKE_BAR"
  local cfg
  cfg=$(jq -n --arg s "$_FAKE_BAR" \
    '{"bars":[{"script":$s,"params":{"count":3,"flag":true,"list":["a","b"]}}]}')
  bl_run '{}' "$cfg"
  [[ "$BL_OUTPUT" == *'"count":3'* ]]
  [[ "$BL_OUTPUT" == *'"flag":true'* ]]
}

@test "params: bar with no params does not set BOTTOMLINE_BAR_PARAMS" {
  # Bar prints the var or the literal "UNSET" if unset
  printf '#!/usr/bin/env bash\nprintf "%%s" "${BOTTOMLINE_BAR_PARAMS:-UNSET}"\n' > "$_FAKE_BAR"
  local cfg
  cfg=$(jq -n --arg s "$_FAKE_BAR" '{"bars":[{"script":$s}]}')
  bl_run '{}' "$cfg"
  [[ "$BL_OUTPUT" == *'UNSET'* ]]
}

# ── BOTTOMLINE_BAR_SEGMENTS ────────────────────────────────────────────────────

@test "BOTTOMLINE_BAR_SEGMENTS: string array from bars[].segments exported to script bar" {
  printf '#!/usr/bin/env bash\nprintf "%%s" "${BOTTOMLINE_BAR_SEGMENTS:-UNSET}"\n' > "$_FAKE_BAR"
  local cfg
  cfg=$(jq -n --arg s "$_FAKE_BAR" \
    '{"bars":[{"script":$s,"segments":["alpha","beta","gamma"]}]}')
  bl_run '{}' "$cfg"
  [[ "$BL_OUTPUT" == *'"alpha"'* ]]
  [[ "$BL_OUTPUT" == *'"beta"'* ]]
}

@test "BOTTOMLINE_BAR_SEGMENTS: absent segments key leaves var unset" {
  printf '#!/usr/bin/env bash\nprintf "%%s" "${BOTTOMLINE_BAR_SEGMENTS:-UNSET}"\n' > "$_FAKE_BAR"
  local cfg
  cfg=$(jq -n --arg s "$_FAKE_BAR" '{"bars":[{"script":$s}]}')
  bl_run '{}' "$cfg"
  [[ "$BL_OUTPUT" == *'UNSET'* ]]
}
