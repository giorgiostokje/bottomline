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

@test "javascript: renders Node version from .nvmrc" {
  printf '{"name":"x"}\n' > "$FAKE_PROJ/package.json"
  printf '20.11.0\n' > "$FAKE_PROJ/.nvmrc"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"20"* ]]
}

@test "javascript: renders pnpm when pnpm-lock.yaml present" {
  printf '{"name":"x"}\n' > "$FAKE_PROJ/package.json"
  printf 'lockfileVersion: 9\n' > "$FAKE_PROJ/pnpm-lock.yaml"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"pnpm"* ]]
}

@test "javascript: renders yarn when yarn.lock present" {
  printf '{"name":"x"}\n' > "$FAKE_PROJ/package.json"
  printf '# yarn lockfile v1\n' > "$FAKE_PROJ/yarn.lock"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"yarn"* ]]
}

@test "javascript: renders Vitest when in package.json" {
  printf '%s\n' '{"name":"x","devDependencies":{"vitest":"^1.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Vitest"* ]]
}

@test "javascript: renders Playwright alongside Vitest (different tiers)" {
  printf '%s\n' '{"name":"x","devDependencies":{"vitest":"^1.0.0","@playwright/test":"^1.40.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Vitest"* ]]
  [[ "$BAR_OUTPUT" == *"Playwright"* ]]
}

@test "javascript: renders Tailwind when in deps" {
  printf '%s\n' '{"name":"x","devDependencies":{"tailwindcss":"^3.4.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Tailwind"* ]]
}

@test "javascript: renders ESLint when in deps" {
  printf '%s\n' '{"name":"x","devDependencies":{"eslint":"^9.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"ESLint"* ]]
}

@test "javascript: renders Prettier when .prettierrc present" {
  printf '{"name":"x"}\n' > "$FAKE_PROJ/package.json"
  printf '{"singleQuote": true}\n' > "$FAKE_PROJ/.prettierrc"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Prettier"* ]]
}

@test "javascript: renders Biome when biome.json present" {
  printf '{"name":"x"}\n' > "$FAKE_PROJ/package.json"
  printf '{"$schema":"https://biomejs.dev/schemas/1.5.0/schema.json"}\n' > "$FAKE_PROJ/biome.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Biome"* ]]
}
