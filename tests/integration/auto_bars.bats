#!/usr/bin/env bats
# Integration tests for auto-bar detection — root-only and subdir.

bats_require_minimum_version 1.5.0
load '../helpers'

setup()    { setup_fake_home; }
teardown() { teardown_fake_home; }

# ── Root-level detection (must keep working after the change) ─────────────────

@test "auto_bars: root-level signal detected (search_depth=0 default)" {
  local proj_dir; proj_dir=$(mktemp -d)
  printf '// swift-tools-version: 5.9\n' > "$proj_dir/Package.swift"
  local user_cfg='{"auto_bars":{"enabled":true},"segments":{"enabled":[]}}'
  local json; json=$(printf '{}' | jq --arg d "$proj_dir" '.workspace.current_dir = $d')
  bl_run "$json" "$user_cfg"
  rm -rf "$proj_dir"
  [[ "$BL_OUTPUT" == *"Swift"* ]]
}

@test "auto_bars: no bar when signal absent from root (search_depth=0 default)" {
  local proj_dir; proj_dir=$(mktemp -d)
  local user_cfg='{"auto_bars":{"enabled":true},"segments":{"enabled":[]}}'
  local json; json=$(printf '{}' | jq --arg d "$proj_dir" '.workspace.current_dir = $d')
  bl_run "$json" "$user_cfg"
  rm -rf "$proj_dir"
  [[ "$BL_OUTPUT" != *"Swift"* ]]
}

# ── Subdir signal not detected when search_depth=0 ────────────────────────────

@test "auto_bars: nested signal NOT detected with search_depth=0 (default)" {
  local proj_dir; proj_dir=$(mktemp -d)
  mkdir -p "$proj_dir/Core"
  printf '// swift-tools-version: 5.9\n' > "$proj_dir/Core/Package.swift"
  local user_cfg='{"auto_bars":{"enabled":true},"segments":{"enabled":[]}}'
  local json; json=$(printf '{}' | jq --arg d "$proj_dir" '.workspace.current_dir = $d')
  bl_run "$json" "$user_cfg"
  rm -rf "$proj_dir"
  [[ "$BL_OUTPUT" != *"Swift"* ]]
}

# ── Subdir detection enabled ──────────────────────────────────────────────────

@test "auto_bars: nested signal detected at depth 1 with search_depth=1" {
  local proj_dir; proj_dir=$(mktemp -d)
  mkdir -p "$proj_dir/Core"
  printf '// swift-tools-version: 5.9\n' > "$proj_dir/Core/Package.swift"
  local user_cfg='{"auto_bars":{"enabled":true,"search_depth":1},"segments":{"enabled":[]}}'
  local json; json=$(printf '{}' | jq --arg d "$proj_dir" '.workspace.current_dir = $d')
  bl_run "$json" "$user_cfg"
  rm -rf "$proj_dir"
  [[ "$BL_OUTPUT" == *"Swift"* ]]
}

@test "auto_bars: nested signal detected at depth 2 with search_depth=2" {
  local proj_dir; proj_dir=$(mktemp -d)
  mkdir -p "$proj_dir/packages/Core"
  printf '// swift-tools-version: 5.9\n' > "$proj_dir/packages/Core/Package.swift"
  local user_cfg='{"auto_bars":{"enabled":true,"search_depth":2},"segments":{"enabled":[]}}'
  local json; json=$(printf '{}' | jq --arg d "$proj_dir" '.workspace.current_dir = $d')
  bl_run "$json" "$user_cfg"
  rm -rf "$proj_dir"
  [[ "$BL_OUTPUT" == *"Swift"* ]]
}

@test "auto_bars: signal at depth 2 NOT detected with search_depth=1" {
  local proj_dir; proj_dir=$(mktemp -d)
  mkdir -p "$proj_dir/packages/Core"
  printf '// swift-tools-version: 5.9\n' > "$proj_dir/packages/Core/Package.swift"
  local user_cfg='{"auto_bars":{"enabled":true,"search_depth":1},"segments":{"enabled":[]}}'
  local json; json=$(printf '{}' | jq --arg d "$proj_dir" '.workspace.current_dir = $d')
  bl_run "$json" "$user_cfg"
  rm -rf "$proj_dir"
  [[ "$BL_OUTPUT" != *"Swift"* ]]
}

# ── Pruning ───────────────────────────────────────────────────────────────────

@test "auto_bars: node_modules is pruned during subdir search" {
  local proj_dir; proj_dir=$(mktemp -d)
  mkdir -p "$proj_dir/node_modules/pkg"
  printf '// swift-tools-version: 5.9\n' > "$proj_dir/node_modules/pkg/Package.swift"
  local user_cfg='{"auto_bars":{"enabled":true,"search_depth":2},"segments":{"enabled":[]}}'
  local json; json=$(printf '{}' | jq --arg d "$proj_dir" '.workspace.current_dir = $d')
  bl_run "$json" "$user_cfg"
  rm -rf "$proj_dir"
  [[ "$BL_OUTPUT" != *"Swift"* ]]
}

@test "auto_bars: vendor dir is pruned during subdir search" {
  local proj_dir; proj_dir=$(mktemp -d)
  mkdir -p "$proj_dir/vendor/sub"
  printf '// swift-tools-version: 5.9\n' > "$proj_dir/vendor/sub/Package.swift"
  local user_cfg='{"auto_bars":{"enabled":true,"search_depth":2},"segments":{"enabled":[]}}'
  local json; json=$(printf '{}' | jq --arg d "$proj_dir" '.workspace.current_dir = $d')
  bl_run "$json" "$user_cfg"
  rm -rf "$proj_dir"
  [[ "$BL_OUTPUT" != *"Swift"* ]]
}

@test "auto_bars: .build dir is pruned during subdir search" {
  local proj_dir; proj_dir=$(mktemp -d)
  mkdir -p "$proj_dir/.build/sub"
  printf '// swift-tools-version: 5.9\n' > "$proj_dir/.build/sub/Package.swift"
  local user_cfg='{"auto_bars":{"enabled":true,"search_depth":2},"segments":{"enabled":[]}}'
  local json; json=$(printf '{}' | jq --arg d "$proj_dir" '.workspace.current_dir = $d')
  bl_run "$json" "$user_cfg"
  rm -rf "$proj_dir"
  [[ "$BL_OUTPUT" != *"Swift"* ]]
}

# ── Shallowest match wins ─────────────────────────────────────────────────────

@test "auto_bars: shallowest match wins when multiple signals exist at different depths" {
  local proj_dir; proj_dir=$(mktemp -d)
  mkdir -p "$proj_dir/Core" "$proj_dir/nested/deep"
  printf '// swift-tools-version: 5.9\n' > "$proj_dir/Core/Package.swift"
  printf '// swift-tools-version: 5.7\n' > "$proj_dir/nested/deep/Package.swift"
  local user_cfg='{"auto_bars":{"enabled":true,"search_depth":3},"segments":{"enabled":[]}}'
  local json; json=$(printf '{}' | jq --arg d "$proj_dir" '.workspace.current_dir = $d')
  bl_run "$json" "$user_cfg"
  rm -rf "$proj_dir"
  [[ "$BL_OUTPUT" == *"Swift"* ]]
  [[ "$BL_OUTPUT" == *"5.9"* ]]
  [[ "$BL_OUTPUT" != *"5.7"* ]]
}
