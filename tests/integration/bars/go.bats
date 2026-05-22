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

@test "go: renders gin when in go.mod require" {
  printf 'module x\n\ngo 1.22\n\nrequire github.com/gin-gonic/gin v1.10.0\n' > "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Gin"* ]]
}

@test "go: renders echo when in go.mod require" {
  printf 'module x\n\ngo 1.22\n\nrequire github.com/labstack/echo/v4 v4.11.0\n' > "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Echo"* ]]
}

@test "go: renders testify when in go.mod" {
  printf 'module x\n\ngo 1.22\n\nrequire github.com/stretchr/testify v1.9.0\n' > "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"testify"* ]]
}

@test "go: Ginkgo suppresses testify when both present" {
  printf 'module x\n\ngo 1.22\n\nrequire (\n  github.com/onsi/ginkgo/v2 v2.15.0\n  github.com/stretchr/testify v1.9.0\n)\n' > "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Ginkgo"* ]]
  [[ "$BAR_OUTPUT" != *"testify"* ]]
}

@test "go: renders gorm when in go.mod" {
  printf 'module x\n\ngo 1.22\n\nrequire gorm.io/gorm v1.25.0\n' > "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"GORM"* ]]
}

@test "go: renders golangci-lint when binary on PATH" {
  printf 'module x\n\ngo 1.22\n' > "$FAKE_PROJ/go.mod"
  printf '#!/bin/sh\necho ok\n' > "$FAKE_PROJ/golangci-lint"
  chmod +x "$FAKE_PROJ/golangci-lint"
  PATH="$FAKE_PROJ:$PATH" bar_run go "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"golangci-lint"* ]]
}

@test "go: renders golangci-lint when config present" {
  printf 'module x\n\ngo 1.22\n' > "$FAKE_PROJ/go.mod"
  printf 'run:\n  timeout: 5m\n' > "$FAKE_PROJ/.golangci.yml"
  bar_run go "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"golangci-lint"* ]]
}
