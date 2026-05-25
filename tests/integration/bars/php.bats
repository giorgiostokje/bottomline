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

@test "php: renders Pest from composer.lock" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[],"packages-dev":[{"name":"pestphp/pest","version":"v2.0.0"}]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Pest"* ]]
  [[ "$BAR_OUTPUT" == *"2.0.0"* ]]
}

@test "php: renders PHPUnit from composer.lock when no Pest" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[],"packages-dev":[{"name":"phpunit/phpunit","version":"v10.0.0"}]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"PHPUnit"* ]]
  [[ "$BAR_OUTPUT" == *"10.0.0"* ]]
}

@test "php: Pest suppresses PHPUnit" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[],"packages-dev":[{"name":"pestphp/pest","version":"v2.0.0"},{"name":"phpunit/phpunit","version":"v10.0.0"}]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Pest"* ]]
  [[ "$BAR_OUTPUT" != *"PHPUnit"* ]]
}

@test "php: renders PHPStan from composer.lock with version" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[],"packages-dev":[{"name":"phpstan/phpstan","version":"v1.10.0"}]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"PHPStan"* ]]
  [[ "$BAR_OUTPUT" == *"1.10.0"* ]]
}

@test "php: renders PHPStan from phpstan.neon config file" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[],"packages-dev":[]}' \
    > "$FAKE_PROJ/composer.lock"
  printf 'level: 5\n' > "$FAKE_PROJ/phpstan.neon"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"PHPStan"* ]]
}

@test "php: renders Larastan instead of PHPStan when both are present" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[],"packages-dev":[{"name":"nunomaduro/larastan","version":"v2.9.0"},{"name":"phpstan/phpstan","version":"v1.10.0"}]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Larastan"* ]]
  [[ "$BAR_OUTPUT" != *"PHPStan"* ]]
}

@test "php: renders Larastan with version" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[],"packages-dev":[{"name":"nunomaduro/larastan","version":"v2.9.0"}]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Larastan"* ]]
  [[ "$BAR_OUTPUT" == *"2.9.0"* ]]
}

@test "php: renders Larastan (larastan/larastan) instead of PHPStan when both are present" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[],"packages-dev":[{"name":"larastan/larastan","version":"v3.0.0"},{"name":"phpstan/phpstan","version":"v2.0.0"}]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Larastan"* ]]
  [[ "$BAR_OUTPUT" != *"PHPStan"* ]]
}

@test "php: renders Larastan (larastan/larastan) with version" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[],"packages-dev":[{"name":"larastan/larastan","version":"v3.0.0"}]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Larastan"* ]]
  [[ "$BAR_OUTPUT" == *"3.0.0"* ]]
}

@test "php: renders Pint instead of PHP-CS-Fixer when both are present" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[],"packages-dev":[{"name":"laravel/pint","version":"v1.18.0"},{"name":"friendsofphp/php-cs-fixer","version":"v3.0.0"}]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Pint"* ]]
  [[ "$BAR_OUTPUT" != *"CS Fixer"* ]]
}

@test "php: renders Pint with version" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[],"packages-dev":[{"name":"laravel/pint","version":"v1.18.0"}]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Pint"* ]]
  [[ "$BAR_OUTPUT" == *"1.18.0"* ]]
}

@test "php: renders PHP-CS-Fixer from composer.lock" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[],"packages-dev":[{"name":"friendsofphp/php-cs-fixer","version":"v3.0.0"}]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"CS Fixer"* ]]
  [[ "$BAR_OUTPUT" == *"3.0.0"* ]]
}

@test "php: PHP version segment includes v prefix" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  local _bin; _bin=$(mktemp -d)
  printf '#!/bin/sh\nprintf "8.2"\n' > "$_bin/php"
  chmod +x "$_bin/php"
  PATH="$_bin:$PATH" bar_run php "$FAKE_PROJ"
  rm -rf "$_bin"
  [[ "$BAR_OUTPUT" == *"PHP"* ]]
  [[ "$BAR_OUTPUT" == *"v8.2"* ]]
}

@test "php: Boost renders normally (no boost.json)" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[{"name":"laravel/boost","version":"v1.0.0"}],"packages-dev":[]}' \
    > "$FAKE_PROJ/composer.lock"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Boost"* ]]
  [[ "$BAR_OUTPUT" == *"v1.0.0"* ]]
  [[ "$BAR_OUTPUT" != *"⚠"* ]]
}

@test "php: Boost renders with warning when boost.json missing claude_code agent" {
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  printf '%s\n' '{"packages":[{"name":"laravel/boost","version":"v1.0.0"}],"packages-dev":[]}' \
    > "$FAKE_PROJ/composer.lock"
  printf '{"agents":[]}\n' > "$FAKE_PROJ/boost.json"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Boost"* ]]
  [[ "$BAR_OUTPUT" == *"v1.0.0"* ]]
  [[ "$BAR_OUTPUT" == *"⚠"* ]]
}
