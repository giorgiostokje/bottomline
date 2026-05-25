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

@test "isolation: bar A accent_hex override does not leak to bar B" {
  cat > "$FAKE_PROJ/.claude/bottomline/bars/_iso_accent_a.sh" << 'BAR_A'
#!/usr/bin/env bash
source "$BOTTOMLINE_LIB/helpers.sh"
printf 'ACCENT_HEX=%s' "$BOTTOMLINE_ACCENT_HEX"
BAR_A
  chmod +x "$FAKE_PROJ/.claude/bottomline/bars/_iso_accent_a.sh"

  cat > "$FAKE_PROJ/.claude/bottomline/bars/_iso_accent_b.sh" << 'BAR_B'
#!/usr/bin/env bash
source "$BOTTOMLINE_LIB/helpers.sh"
printf 'ACCENT_HEX=%s' "$BOTTOMLINE_ACCENT_HEX"
BAR_B
  chmod +x "$FAKE_PROJ/.claude/bottomline/bars/_iso_accent_b.sh"

  local user_cfg
  user_cfg=$(jq -n '{
    appearance: { icons: { type: "none" } },
    bars: [
      { script: "_iso_accent_a", colors: { accent: "#ff0000" } },
      { script: "_iso_accent_b" }
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

@test "isolation: bar A gradient override does not leak to bar B" {
  cat > "$FAKE_PROJ/.claude/bottomline/bars/_iso_grad_a.sh" << 'BAR_A'
#!/usr/bin/env bash
source "$BOTTOMLINE_LIB/helpers.sh"
printf 'GRADIENT=%s' "$BOTTOMLINE_GRADIENT"
BAR_A
  chmod +x "$FAKE_PROJ/.claude/bottomline/bars/_iso_grad_a.sh"

  cat > "$FAKE_PROJ/.claude/bottomline/bars/_iso_grad_b.sh" << 'BAR_B'
#!/usr/bin/env bash
source "$BOTTOMLINE_LIB/helpers.sh"
printf 'GRADIENT=%s' "$BOTTOMLINE_GRADIENT"
BAR_B
  chmod +x "$FAKE_PROJ/.claude/bottomline/bars/_iso_grad_b.sh"

  local user_cfg
  user_cfg=$(jq -n '{
    appearance: { icons: { type: "none" } },
    bars: [
      { script: "_iso_grad_a", colors: { background: ["#ff0000","#00ff00"] } },
      { script: "_iso_grad_b" }
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

@test "isolation: bar A refresh_minutes override does not leak to bar B" {
  cat > "$FAKE_PROJ/.claude/bottomline/bars/_iso_rm_a.sh" << 'BAR_A'
#!/usr/bin/env bash
source "$BOTTOMLINE_LIB/helpers.sh"
printf 'REFRESH_MINUTES=%s' "${BOTTOMLINE_BAR_REFRESH_MINUTES:-unset}"
BAR_A
  chmod +x "$FAKE_PROJ/.claude/bottomline/bars/_iso_rm_a.sh"

  cat > "$FAKE_PROJ/.claude/bottomline/bars/_iso_rm_b.sh" << 'BAR_B'
#!/usr/bin/env bash
source "$BOTTOMLINE_LIB/helpers.sh"
printf 'REFRESH_MINUTES=%s' "${BOTTOMLINE_BAR_REFRESH_MINUTES:-unset}"
BAR_B
  chmod +x "$FAKE_PROJ/.claude/bottomline/bars/_iso_rm_b.sh"

  local user_cfg
  user_cfg=$(jq -n '{
    appearance: { icons: { type: "none" } },
    bars: [
      { script: "_iso_rm_a", refresh_minutes: 42 },
      { script: "_iso_rm_b" }
    ]
  }')

  local json
  json=$(jq -n --arg d "$FAKE_PROJ" '{ workspace: { current_dir: $d } }')

  bl_run "$json" "$user_cfg"

  local line_a line_b
  line_a=$(printf '%s' "$BL_OUTPUT" | sed -n '2p')
  line_b=$(printf '%s' "$BL_OUTPUT" | sed -n '3p')

  [[ "$line_a" == *"REFRESH_MINUTES=42"* ]]
  [[ "$line_b" != *"REFRESH_MINUTES=42"* ]]
}

@test "isolation: bar A params override does not leak to bar B" {
  cat > "$FAKE_PROJ/.claude/bottomline/bars/_iso_param_a.sh" << 'BAR_A'
#!/usr/bin/env bash
source "$BOTTOMLINE_LIB/helpers.sh"
printf 'PARAMS=%s' "${BOTTOMLINE_BAR_PARAMS:-unset}"
BAR_A
  chmod +x "$FAKE_PROJ/.claude/bottomline/bars/_iso_param_a.sh"

  cat > "$FAKE_PROJ/.claude/bottomline/bars/_iso_param_b.sh" << 'BAR_B'
#!/usr/bin/env bash
source "$BOTTOMLINE_LIB/helpers.sh"
printf 'PARAMS=%s' "${BOTTOMLINE_BAR_PARAMS:-unset}"
BAR_B
  chmod +x "$FAKE_PROJ/.claude/bottomline/bars/_iso_param_b.sh"

  local user_cfg
  user_cfg=$(jq -n '{
    appearance: { icons: { type: "none" } },
    bars: [
      { script: "_iso_param_a", params: { key: "secret_a" } },
      { script: "_iso_param_b" }
    ]
  }')

  local json
  json=$(jq -n --arg d "$FAKE_PROJ" '{ workspace: { current_dir: $d } }')

  bl_run "$json" "$user_cfg"

  local line_a line_b
  line_a=$(printf '%s' "$BL_OUTPUT" | sed -n '2p')
  line_b=$(printf '%s' "$BL_OUTPUT" | sed -n '3p')

  [[ "$line_a" == *"secret_a"* ]]
  [[ "$line_b" != *"secret_a"* ]]
}
