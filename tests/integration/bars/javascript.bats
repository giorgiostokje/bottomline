#!/usr/bin/env bats
# Integration tests for the javascript bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "javascript: exits silently when no package.json" {
  bar_run javascript "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "javascript: renders Vue when package.json lists vue" {
  printf '{"dependencies":{"vue":"^3.4.0"}}\n' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Vue"* ]]
}

@test "javascript: renders Next.js and suppresses bare React" {
  printf '{"dependencies":{"next":"^14.0.0","react":"^18.0.0"}}\n' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Next.js"* ]]
  [[ "$BAR_OUTPUT" != *" React"* ]]
}

@test "javascript: renders TypeScript" {
  printf '{"devDependencies":{"typescript":"^5.0.0"}}\n' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"TypeScript"* ]]
}

@test "javascript: renders Nuxt and suppresses bare Vue" {
  printf '{"dependencies":{"nuxt":"^3.0.0","vue":"^3.4.0"}}\n' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Nuxt"* ]]
  [[ "$BAR_OUTPUT" != *" Vue"* ]]
}
