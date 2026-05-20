#!/usr/bin/env bats
# Integration tests for the git bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup() {
  setup_fake_proj
  git -C "$FAKE_PROJ" init -b main 2>/dev/null \
    || { git -C "$FAKE_PROJ" init && git -C "$FAKE_PROJ" checkout -b main 2>/dev/null; }
  git -C "$FAKE_PROJ" config user.email "test@example.com"
  git -C "$FAKE_PROJ" config user.name "TestUser"
  printf 'hello\n' > "$FAKE_PROJ/README.md"
  git -C "$FAKE_PROJ" add .
  git -C "$FAKE_PROJ" commit -m "initial" 2>/dev/null
}

teardown() { teardown_fake_proj; }

@test "git: exits silently when PROJ has no .git directory" {
  local empty_dir
  empty_dir=$(mktemp -d)
  bar_run git "$empty_dir"
  rm -rf "$empty_dir"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "git: renders branch name" {
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"main"* ]]
}

@test "git: renders clean status on clean repo" {
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"clean"* ]]
}

@test "git: renders change stats when uncommitted modifications exist" {
  printf 'hello\nworld\n' > "$FAKE_PROJ/README.md"
  bar_run git "$FAKE_PROJ"
  # Dirty repo shows line-stat format: +N -N (plus separator chars)
  [[ "$BAR_OUTPUT" != *"clean"* ]]
  [[ "$BAR_OUTPUT" == *"+"* ]]
}

@test "git: renders last commit author and age" {
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"TestUser"* ]]
}
