#!/usr/bin/env bats
# Integration test: script-bar export isolation.
# Verifies that per-bar color overrides inside one script bar's ( ... )
# subshell do NOT leak to the next bar.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup() {
  setup_fake_home
  setup_fake_proj

  mkdir -p "$FAKE_PROJ/.claude/bottomline/bars"

  cat > "$FAKE_PROJ/.claude/bottomline/bars/_iso_a.sh" << 'BAR_A'
#!/usr/bin/env bash
source "$BOTTOMLINE_LIB/helpers.sh"
printf 'TEXT_HEX=%s' "$BOTTOMLINE_TEXT_HEX"
BAR_A
  chmod +x "$FAKE_PROJ/.claude/bottomline/bars/_iso_a.sh"

  cat > "$FAKE_PROJ/.claude/bottomline/bars/_iso_b.sh" << 'BAR_B'
#!/usr/bin/env bash
source "$BOTTOMLINE_LIB/helpers.sh"
printf 'TEXT_HEX=%s' "$BOTTOMLINE_TEXT_HEX"
BAR_B
  chmod +x "$FAKE_PROJ/.claude/bottomline/bars/_iso_b.sh"
}

teardown() {
  teardown_fake_proj
  teardown_fake_home
}

@test "isolation: bar A color override does not leak to bar B" {
  local user_cfg
  user_cfg=$(jq -n '{
    appearance: { icons: { type: "none" } },
    bars: [
      { script: "_iso_a", colors: { text: "#ff0000" } },
      { script: "_iso_b" }
    ]
  }')

  local json
  json=$(jq -n --arg d "$FAKE_PROJ" '{ workspace: { current_dir: $d } }')

  bl_run "$json" "$user_cfg"

  local line_a line_b
  line_a=$(printf '%s' "$BL_OUTPUT" | sed -n '2p')
  line_b=$(printf '%s' "$BL_OUTPUT" | sed -n '3p')

  [[ "$line_a" == *"ff0000"* ]]
  [[ "$line_b" != *"ff0000"* ]]
}

@test "isolation: bar B sees default text color when A overrides it" {
  local default_hex="#e2d5c3"
  local user_cfg
  user_cfg=$(jq -n --arg dh "$default_hex" '{
    appearance: { icons: { type: "none" }, colors: { text: $dh } },
    bars: [
      { script: "_iso_a", colors: { text: "#00ff00" } },
      { script: "_iso_b" }
    ]
  }')

  local json
  json=$(jq -n --arg d "$FAKE_PROJ" '{ workspace: { current_dir: $d } }')

  bl_run "$json" "$user_cfg"

  local line_b
  line_b=$(printf '%s' "$BL_OUTPUT" | sed -n '3p')

  [[ "$line_b" == *"$default_hex"* ]]
}
