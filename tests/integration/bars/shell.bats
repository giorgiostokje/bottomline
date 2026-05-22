#!/usr/bin/env bats
# Integration tests for the shell bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "shell: exits silently when no shell scripts at project root" {
  bar_run shell "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "shell: renders bash and version when a .sh file is present" {
  printf '#!/usr/bin/env bash\necho hello\n' > "$FAKE_PROJ/install.sh"
  bar_run shell "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"bash"* ]]
  [[ "$BAR_OUTPUT" == *"v"* ]]
}

@test "shell: reads target shell from .shellcheckrc" {
  printf '#!/usr/bin/env bash\necho hello\n' > "$FAKE_PROJ/run.sh"
  printf 'shell=sh\n' > "$FAKE_PROJ/.shellcheckrc"
  bar_run shell "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"sh"* ]]
}

@test "shell: defaults to bash when .shellcheckrc is absent" {
  printf '#!/usr/bin/env bash\necho hello\n' > "$FAKE_PROJ/install.sh"
  bar_run shell "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"bash"* ]]
}

@test "shell: shows shellcheck version when shellcheck is installed" {
  command -v shellcheck > /dev/null 2>&1 || skip "shellcheck not installed"
  printf '#!/usr/bin/env bash\n' > "$FAKE_PROJ/test.sh"
  bar_run shell "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"ShellCheck"* ]]
}

@test "shell: renders bats when binary on PATH" {
  printf '#!/bin/bash\necho hi\n' > "$FAKE_PROJ/foo.sh"
  printf '#!/bin/sh\necho "Bats 1.10.0"\n' > "$FAKE_PROJ/bats"
  chmod +x "$FAKE_PROJ/bats"
  PATH="$FAKE_PROJ:$PATH" bar_run shell "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"bats"* ]]
}

@test "shell: renders bats when .bats files exist in project" {
  printf '#!/bin/bash\necho hi\n' > "$FAKE_PROJ/foo.sh"
  mkdir -p "$FAKE_PROJ/tests"
  printf '#!/usr/bin/env bats\n@test "ok" { true; }\n' > "$FAKE_PROJ/tests/foo.bats"
  bar_run shell "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"bats"* ]]
}

@test "shell: renders make when Makefile exists" {
  printf '#!/bin/bash\necho hi\n' > "$FAKE_PROJ/foo.sh"
  printf 'all:\n\t@echo ok\n' > "$FAKE_PROJ/Makefile"
  bar_run shell "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"make"* ]]
}
