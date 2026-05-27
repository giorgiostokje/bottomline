#!/usr/bin/env bats
# Unit tests for resolve_bar_script — bar script path resolution with
# project → user → plugin lookup layers.

bats_require_minimum_version 1.5.0
load '../helpers'

setup() {
  _bl_extract resolve_bar_script "$BOTTOMLINE_ROOT/lib/bars.sh"

  FAKE_HOME=$(mktemp -d)
  FAKE_BL_DIR=$(mktemp -d)
  FAKE_PROJ=$(mktemp -d)

  mkdir -p "$FAKE_HOME/.claude/bottomline/bars"
  mkdir -p "$FAKE_BL_DIR/bars"
  mkdir -p "$FAKE_PROJ/.claude/bottomline/bars"

  export HOME="$FAKE_HOME"
  export _BL_DIR="$FAKE_BL_DIR"
  export cdir="$FAKE_PROJ"
}

teardown() {
  rm -rf "$FAKE_HOME" "$FAKE_BL_DIR" "$FAKE_PROJ"
}

@test "absolute path passthrough: /custom/path/foo.sh" {
  mkdir -p /tmp/_bl_test_abs
  touch /tmp/_bl_test_abs/mybar.sh
  run resolve_bar_script "/tmp/_bl_test_abs/mybar.sh"
  [ "$output" = "/tmp/_bl_test_abs/mybar.sh" ]
  rm -rf /tmp/_bl_test_abs
}

@test "tilde expansion: ~/my/bar.sh expands via HOME" {
  mkdir -p "$FAKE_HOME/my"
  touch "$FAKE_HOME/my/bar.sh"
  run resolve_bar_script "~/my/bar.sh"
  [ "$output" = "$FAKE_HOME/my/bar.sh" ]
}

@test "user-level lookup: ~/.claude/bottomline/bars/NAME.sh" {
  touch "$FAKE_HOME/.claude/bottomline/bars/custom.sh"
  run resolve_bar_script "custom"
  [ "$output" = "$FAKE_HOME/.claude/bottomline/bars/custom.sh" ]
}

@test "project shadows user: project bar wins over user bar" {
  touch "$FAKE_PROJ/.claude/bottomline/bars/mybar.sh"
  touch "$FAKE_HOME/.claude/bottomline/bars/mybar.sh"
  run resolve_bar_script "mybar"
  [ "$output" = "$FAKE_PROJ/.claude/bottomline/bars/mybar.sh" ]
}

@test "user shadows plugin: user bar wins over plugin bar" {
  touch "$FAKE_HOME/.claude/bottomline/bars/golang.sh"
  touch "$FAKE_BL_DIR/bars/golang.sh"
  cdir="" run resolve_bar_script "golang"
  [ "$output" = "$FAKE_HOME/.claude/bottomline/bars/golang.sh" ]
}

@test "plugin fallback: no project or user bar, plugin bar found" {
  touch "$FAKE_BL_DIR/bars/python.sh"
  cdir="" run resolve_bar_script "python"
  [ "$output" = "$FAKE_BL_DIR/bars/python.sh" ]
}

@test "unknown name returns empty" {
  cdir="" run resolve_bar_script "nonexistent_bar"
  [ "$output" = "" ]
}
