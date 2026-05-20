#!/usr/bin/env bats
# Integration tests for the go bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "go: exits silently when no go.mod" {
  bar_run go "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "go: renders Go and version from go.mod" {
  printf 'module example.com/app\n\ngo 1.22\n' > "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Go"* ]]
  [[ "$BAR_OUTPUT" == *"1.22"* ]]
}

@test "go: renders workspace flag when go.work exists" {
  printf 'module example.com/app\n\ngo 1.22\n' > "$FAKE_PROJ/go.mod"
  touch "$FAKE_PROJ/go.work"
  bar_run go "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"workspace"* ]]
}

@test "go: no workspace flag when go.work absent" {
  printf 'module example.com/app\n\ngo 1.22\n' > "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"workspace"* ]]
}
