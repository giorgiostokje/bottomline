#!/usr/bin/env bats
# Integration tests for the swift bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "swift: exits silently when no Package.swift" {
  bar_run swift "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "swift: renders Swift with tools version from Package.swift" {
  printf '// swift-tools-version: 5.9\nimport PackageDescription\n' \
    > "$FAKE_PROJ/Package.swift"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Swift"* ]]
  [[ "$BAR_OUTPUT" == *"5.9"* ]]
}

@test "swift: renders Vapor from Package.resolved" {
  printf '// swift-tools-version: 5.9\n' > "$FAKE_PROJ/Package.swift"
  printf '%s\n' \
    '{"pins":[{"identity":"vapor","state":{"version":"4.89.0"}}],"version":2}' \
    > "$FAKE_PROJ/Package.resolved"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Vapor"* ]]
  [[ "$BAR_OUTPUT" == *"4.89.0"* ]]
}

@test "swift: no Vapor segment when Package.resolved absent" {
  printf '// swift-tools-version: 5.9\n' > "$FAKE_PROJ/Package.swift"
  bar_run swift "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"Vapor"* ]]
}
