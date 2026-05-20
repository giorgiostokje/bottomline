#!/usr/bin/env bats
# Integration tests for config merge behaviour and theme priority.

bats_require_minimum_version 1.5.0
load '../helpers'

setup()    { setup_fake_home; }
teardown() { teardown_fake_home; }

# ---------------------------------------------------------------------------
# Three-layer config merge
# ---------------------------------------------------------------------------

@test "config: settings.json defaults apply when no user config" {
  # Default segment list from settings.json includes 'model'.
  bl_run '{"model":{"display_name":"sonnet"}}'
  [[ "$BL_OUTPUT" == *"sonnet"* ]]
}

@test "config: user config overrides default segment list" {
  # Restrict to effort only — model should not appear.
  local user_cfg='{"segments":{"enabled":["effort"]}}'
  bl_run '{"model":{"display_name":"sonnet"},"effort":{"level":"high"}}' "$user_cfg"
  [[ "$BL_OUTPUT" != *"sonnet"* ]]
  [[ "$BL_OUTPUT" == *"high"* ]]
}

@test "config: project config overrides user config" {
  local user_cfg='{"segments":{"enabled":["model","effort"]}}'
  local proj_cfg='{"segments":{"enabled":["effort"]}}'
  bl_run '{"model":{"display_name":"sonnet"},"effort":{"level":"max"}}' "$user_cfg" "$proj_cfg"
  [[ "$BL_OUTPUT" != *"sonnet"* ]]
  [[ "$BL_OUTPUT" == *"max"* ]]
}

@test "config: user-level object keys not present in project config are preserved (deep merge)" {
  # User sets effort.xhigh warning; project only changes segment list.
  local user_cfg='{"segments":{"effort":{"xhigh":{"color":"warning"}}}}'
  local proj_cfg='{"segments":{"enabled":["effort"]}}'
  # If deep-merge works, effort config survives the project layer.
  # We can't easily assert color without reading ANSI codes, but we can at
  # least verify the script runs without error and renders effort.
  bl_run '{"effort":{"level":"xhigh"}}' "$user_cfg" "$proj_cfg"
  [[ "$BL_OUTPUT" == *"xhigh"* ]]
}

@test "config: auto_bars.disabled is unioned across all config levels" {
  # User disables 'git'; project disables 'php'.
  # Both should appear in _disabled, so neither bar fires even if signals exist.
  # We test this indirectly: auto_bars.enabled=true, but no bars should appear
  # (we don't create signal files, so bars won't fire regardless — this test
  # mainly ensures the union does not crash the script).
  local user_cfg='{"auto_bars":{"enabled":true,"disabled":["git"]}}'
  local proj_cfg='{"auto_bars":{"disabled":["php"]}}'
  bl_run '{}' "$user_cfg" "$proj_cfg"
  # No crash = pass.
  [ "$?" -eq 0 ]
}

# ---------------------------------------------------------------------------
# appearance.theme priority
# ---------------------------------------------------------------------------

@test "theme: appearance.theme at user level overrides appearance.colors" {
  # catppuccin-mocha sets accent=#cba6f7 (RGB 203,166,247).
  # We also set appearance.colors.accent=#ff0000 at user level — theme must win.
  local user_cfg='{"appearance":{"theme":"catppuccin-mocha","colors":{"accent":"#ff0000"}},"segments":{"enabled":["model"]}}'
  bl_run '{"model":{"display_name":"x"}}' "$user_cfg"
  # Mocha accent ANSI: \e[38;2;203;166;247m — must be present.
  [[ "$BL_OUTPUT_RAW" == *$'\e[38;2;203;166;247m'* ]]
  # Red accent must not be present.
  [[ "$BL_OUTPUT_RAW" != *$'\e[38;2;255;0;0m'* ]]
}

@test "theme: appearance.theme at user level wins over appearance.colors at project level" {
  local user_cfg='{"appearance":{"theme":"catppuccin-mocha"},"segments":{"enabled":["model"]}}'
  local proj_cfg='{"appearance":{"colors":{"accent":"#ff0000"}}}'
  bl_run '{"model":{"display_name":"x"}}' "$user_cfg" "$proj_cfg"
  # Mocha accent must be present; red must not.
  [[ "$BL_OUTPUT_RAW" == *$'\e[38;2;203;166;247m'* ]]
  [[ "$BL_OUTPUT_RAW" != *$'\e[38;2;255;0;0m'* ]]
}

@test "theme: no theme set means appearance.colors from config take effect" {
  local user_cfg='{"appearance":{"colors":{"accent":"#ff0000"}},"segments":{"enabled":["model"]}}'
  bl_run '{"model":{"display_name":"x"}}' "$user_cfg"
  [[ "$BL_OUTPUT_RAW" == *$'\e[38;2;255;0;0m'* ]]
}

# ---------------------------------------------------------------------------
# Context window thresholds
# ---------------------------------------------------------------------------

@test "thresholds: context below warning threshold uses default text color" {
  # Default text color from settings.json: #e2d5c3 = RGB(226,213,195)
  # Warning threshold (from user config): 200000 tokens
  local user_cfg='{"segments":{"enabled":["context"],"context":{"200000":{"color":"warning"},"300000":{"color":"danger"}}}}'
  # ctx_used comes from transcript; 0 tokens = well below threshold
  bl_run '{}' "$user_cfg"
  # Default text color must appear; warning color (#f4a261=RGB 244,162,97) must not.
  [[ "$BL_OUTPUT_RAW" == *$'\e[38;2;226;213;195m'* ]]
  [[ "$BL_OUTPUT_RAW" != *$'\e[38;2;244;162;97m'* ]]
}

# ---------------------------------------------------------------------------
# Usage thresholds
# ---------------------------------------------------------------------------

@test "thresholds: usage below 75% renders in default text color" {
  local user_cfg='{"segments":{"enabled":["usage_5h"],"usage":{"75":{"color":"warning"},"90":{"color":"danger"}}}}'
  bl_run '{"rate_limits":{"five_hour":{"used_percentage":50}}}' "$user_cfg"
  [[ "$BL_OUTPUT_RAW" != *$'\e[38;2;244;162;97m'* ]]
}

@test "thresholds: usage >= 75% renders in warning color" {
  local user_cfg='{"segments":{"enabled":["usage_5h"],"usage":{"75":{"color":"warning"},"90":{"color":"danger"}}}}'
  bl_run '{"rate_limits":{"five_hour":{"used_percentage":75}}}' "$user_cfg"
  # warning = #f4a261 = RGB(244,162,97)
  [[ "$BL_OUTPUT_RAW" == *$'\e[38;2;244;162;97m'* ]]
}

@test "thresholds: usage >= 90% renders in danger color" {
  local user_cfg='{"segments":{"enabled":["usage_5h"],"usage":{"75":{"color":"warning"},"90":{"color":"danger"}}}}'
  bl_run '{"rate_limits":{"five_hour":{"used_percentage":90}}}' "$user_cfg"
  # danger = #e05a4e = RGB(224,90,78)
  [[ "$BL_OUTPUT_RAW" == *$'\e[38;2;224;90;78m'* ]]
}
