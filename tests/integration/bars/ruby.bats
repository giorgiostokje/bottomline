#!/usr/bin/env bats
# Integration tests for the ruby bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "ruby: exits silently when no Gemfile" {
  bar_run ruby "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "ruby: renders Ruby from .ruby-version" {
  printf '3.3.0\n' > "$FAKE_PROJ/.ruby-version"
  printf "source 'https://rubygems.org'\n" > "$FAKE_PROJ/Gemfile"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Ruby"* ]]
  [[ "$BAR_OUTPUT" == *"3.3.0"* ]]
}

@test "ruby: renders Rails when Gemfile lists gem rails" {
  printf "source 'https://rubygems.org'\ngem 'rails', '~> 7.1'\n" > "$FAKE_PROJ/Gemfile"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Rails"* ]]
}

@test "ruby: renders Rails version from Gemfile.lock" {
  printf "source 'https://rubygems.org'\ngem 'rails', '~> 7.1'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  specs:\n    rails (7.1.3)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"7.1.3"* ]]
}
