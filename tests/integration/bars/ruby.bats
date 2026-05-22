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

@test "ruby: renders RSpec when in Gemfile.lock" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    rspec (3.13.0)\n    rspec-rails (6.1.0)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"RSpec"* ]]
}

@test "ruby: renders Minitest when in Gemfile.lock" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    minitest (5.21.0)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Minitest"* ]]
}

@test "ruby: renders Sidekiq when in Gemfile.lock" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    sidekiq (7.2.0)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Sidekiq"* ]]
}

@test "ruby: renders Devise when in Gemfile.lock" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    devise (4.9.0)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Devise"* ]]
}

@test "ruby: renders RuboCop when in Gemfile.lock" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    rubocop (1.60.0)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"RuboCop"* ]]
}

@test "ruby: renders RuboCop when .rubocop.yml present" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'AllCops:\n  TargetRubyVersion: 3.2\n' > "$FAKE_PROJ/.rubocop.yml"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"RuboCop"* ]]
}
