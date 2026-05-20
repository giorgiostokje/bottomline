#!/usr/bin/env bats
# Integration tests for the php bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "php: exits silently when no composer.json" {
  bar_run php "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "php: renders PHP segment when composer.json exists" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"PHP"* ]]
}

@test "php: renders Laravel version from composer.lock" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[{"name":"laravel/framework","version":"v13.0.0"}],"packages-dev":[]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Laravel"* ]]
  [[ "$BAR_OUTPUT" == *"13.0.0"* ]]
}

@test "php: renders Livewire version from composer.lock" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[{"name":"livewire/livewire","version":"v4.0.0"}],"packages-dev":[]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Livewire"* ]]
  [[ "$BAR_OUTPUT" == *"4.0.0"* ]]
}

@test "php: renders Filament version from composer.lock" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[{"name":"filament/filament","version":"v5.0.0"}],"packages-dev":[]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Filament"* ]]
  [[ "$BAR_OUTPUT" == *"5.0.0"* ]]
}
