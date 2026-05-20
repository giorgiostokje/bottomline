#!/usr/bin/env bats
# Integration tests for the rust bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "rust: exits silently when no Cargo.toml" {
  bar_run rust "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "rust: renders Rust and edition from Cargo.toml" {
  printf '[package]\nname = "myapp"\nversion = "0.1.0"\nedition = "2021"\n' \
    > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Rust"* ]]
  [[ "$BAR_OUTPUT" == *"2021"* ]]
}

@test "rust: renders workspace flag when [workspace] present in Cargo.toml" {
  printf '[workspace]\nmembers = ["crate-a", "crate-b"]\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"workspace"* ]]
}

@test "rust: no workspace flag for a regular crate" {
  printf '[package]\nname = "myapp"\nversion = "0.1.0"\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"workspace"* ]]
}
