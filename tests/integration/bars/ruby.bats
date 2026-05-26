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

@test "ruby: renders factory_bot when factory_bot_rails in Gemfile.lock" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    factory_bot_rails (6.4.3)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"factory_bot"* ]]
}

@test "ruby: renders factory_bot when factory_bot in Gemfile.lock" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    factory_bot (6.4.0)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"factory_bot"* ]]
}

@test "ruby: renders Sorbet when sorbet-runtime in Gemfile.lock" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    sorbet-runtime (0.5.11123)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Sorbet"* ]]
}

@test "ruby: renders Sorbet when sorbet in Gemfile.lock" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    sorbet (0.5.11123)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Sorbet"* ]]
}

@test "ruby: Sorbet appears before RuboCop" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    sorbet-runtime (0.5.11123)\n    rubocop (1.60.0)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  sorbet_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'Sorbet' | head -1 | cut -d: -f1)
  rubocop_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'RuboCop' | head -1 | cut -d: -f1)
  [[ -n "$sorbet_pos" && -n "$rubocop_pos" && "$sorbet_pos" -lt "$rubocop_pos" ]]
}

@test "ruby: renders Brakeman when in Gemfile.lock" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    brakeman (6.1.2)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Brakeman"* ]]
}

@test "ruby: renders Brakeman when gem brakeman in Gemfile" {
  printf "source 'https://rubygems.org'\ngem 'brakeman'\n" > "$FAKE_PROJ/Gemfile"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Brakeman"* ]]
}

@test "ruby: Brakeman appears after RuboCop" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    rubocop (1.60.0)\n    brakeman (6.1.2)\n' > "$FAKE_PROJ/Gemfile.lock"
  bar_run ruby "$FAKE_PROJ"
  rubocop_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'RuboCop' | head -1 | cut -d: -f1)
  brakeman_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'Brakeman' | head -1 | cut -d: -f1)
  [[ -n "$rubocop_pos" && -n "$brakeman_pos" && "$rubocop_pos" -lt "$brakeman_pos" ]]
}

@test "ruby: renders Rake when Rakefile present" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'task default: :test\n' > "$FAKE_PROJ/Rakefile"
  bar_run ruby "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Rake"* ]]
}

@test "ruby: Rake appears at end of tooling slot" {
  printf "source 'https://rubygems.org'\ngem 'rails'\n" > "$FAKE_PROJ/Gemfile"
  printf 'GEM\n  remote: https://rubygems.org/\n  specs:\n    rubocop (1.60.0)\n    sidekiq (7.2.0)\n    devise (4.9.0)\n' > "$FAKE_PROJ/Gemfile.lock"
  printf 'task default: :test\n' > "$FAKE_PROJ/Rakefile"
  bar_run ruby "$FAKE_PROJ"
  rake_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'Rake' | head -1 | cut -d: -f1)
  devise_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo 'Devise' | head -1 | cut -d: -f1)
  [[ -n "$rake_pos" && -n "$devise_pos" && "$rake_pos" -gt "$devise_pos" ]]
}
