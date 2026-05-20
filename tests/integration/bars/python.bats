#!/usr/bin/env bats
# Integration tests for the python bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "python: exits silently when no signal files present" {
  bar_run python "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "python: renders Python when requirements.txt exists" {
  printf 'requests>=2.0\n' > "$FAKE_PROJ/requirements.txt"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Python"* ]]
}

@test "python: renders Poetry label when pyproject.toml has [tool.poetry]" {
  printf '[tool.poetry]\nname = "myapp"\nversion = "0.1.0"\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Poetry"* ]]
}

@test "python: renders Django when requirements.txt contains django" {
  printf 'Django>=4.2\n' > "$FAKE_PROJ/requirements.txt"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Django"* ]]
}

@test "python: renders Flask when requirements.txt contains flask" {
  printf 'flask>=3.0\n' > "$FAKE_PROJ/requirements.txt"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Flask"* ]]
}
