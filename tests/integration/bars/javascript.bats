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

@test "javascript: renders Node version from .node-version file" {
  printf '18.20.0\n' > "$FAKE_PROJ/.node-version"
  printf '{"name":"x"}\n' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"18"* ]]
}

@test "javascript: renders Node version from engines.node in package.json" {
  printf '{"engines":{"node":">=20.0.0"}}\n' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"20"* ]]
}

@test "javascript: npm detected from package-lock.json" {
  printf '{"name":"x"}\n' > "$FAKE_PROJ/package.json"
  printf '{"lockfileVersion":3}\n' > "$FAKE_PROJ/package-lock.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"npm"* ]]
}

@test "javascript: bun detected from bun.lockb" {
  printf '{"name":"x"}\n' > "$FAKE_PROJ/package.json"
  printf '' > "$FAKE_PROJ/bun.lockb"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"bun"* ]]
}

@test "javascript: Jest detected from package.json deps" {
  printf '%s\n' '{"devDependencies":{"jest":"^29.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Jest"* ]]
}

@test "javascript: Cypress detected from package.json deps" {
  printf '%s\n' '{"devDependencies":{"cypress":"^13.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Cypress"* ]]
}

@test "javascript: ESLint detected from config file (.eslintrc.json)" {
  printf '{"name":"x"}\n' > "$FAKE_PROJ/package.json"
  printf '{}' > "$FAKE_PROJ/.eslintrc.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"ESLint"* ]]
}

@test "javascript: Prettier detected from package.json dep" {
  printf '%s\n' '{"devDependencies":{"prettier":"^3.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Prettier"* ]]
}

@test "javascript: Biome detected from package.json dep" {
  printf '%s\n' '{"devDependencies":{"@biomejs/biome":"^1.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Biome"* ]]
}

@test "javascript: SolidJS detected from solid-js dep" {
  printf '%s\n' '{"dependencies":{"solid-js":"^1.8.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"SolidJS"* ]]
}

@test "javascript: Preact detected from preact dep" {
  printf '%s\n' '{"dependencies":{"preact":"^10.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Preact"* ]]
}

@test "javascript: Express detected from express dep" {
  printf '%s\n' '{"dependencies":{"express":"^4.18.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Express"* ]]
}

@test "javascript: Fastify detected from fastify dep" {
  printf '%s\n' '{"dependencies":{"fastify":"^4.25.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Fastify"* ]]
}

@test "javascript: NestJS detected from @nestjs/core dep" {
  printf '%s\n' '{"dependencies":{"@nestjs/core":"^10.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"NestJS"* ]]
}

@test "javascript: Hono detected from hono dep" {
  printf '%s\n' '{"dependencies":{"hono":"^3.11.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Hono"* ]]
}

@test "javascript: NestJS suppresses Express" {
  printf '%s\n' '{"dependencies":{"@nestjs/core":"^10.0.0","express":"^4.18.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"NestJS"* ]]
  [[ "$BAR_OUTPUT" != *"Express"* ]]
}

@test "javascript: shadcn/ui detected from components.json" {
  printf '{"name":"x"}\n' > "$FAKE_PROJ/package.json"
  printf '{"style":"default"}\n' > "$FAKE_PROJ/components.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"shadcn/ui"* ]]
}

@test "javascript: TanStack Query detected from @tanstack/react-query dep" {
  printf '%s\n' '{"dependencies":{"@tanstack/react-query":"^5.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"TanStack Query"* ]]
}

@test "javascript: tRPC detected from @trpc/server dep" {
  printf '%s\n' '{"dependencies":{"@trpc/server":"^10.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"tRPC"* ]]
}

@test "javascript: tRPC detected from @trpc/client dep" {
  printf '%s\n' '{"dependencies":{"@trpc/client":"^10.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"tRPC"* ]]
}

@test "javascript: Inertia detected from @inertiajs/react dep" {
  printf '%s\n' '{"dependencies":{"@inertiajs/react":"^1.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Inertia"* ]]
}

@test "javascript: Inertia detected from @inertiajs/vue3 dep" {
  printf '%s\n' '{"dependencies":{"@inertiajs/vue3":"^1.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Inertia"* ]]
}

@test "javascript: Testing Library detected from @testing-library/react dep" {
  printf '%s\n' '{"devDependencies":{"@testing-library/react":"^14.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Testing Library"* ]]
}

@test "javascript: Testing Library shown alongside Jest" {
  printf '%s\n' '{"devDependencies":{"jest":"^29.0.0","@testing-library/react":"^14.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Testing Library"* ]]
  [[ "$BAR_OUTPUT" == *"Jest"* ]]
}

@test "javascript: Storybook detected from storybook dep" {
  printf '%s\n' '{"devDependencies":{"storybook":"^7.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Storybook"* ]]
}

@test "javascript: Storybook detected from @storybook/react dep" {
  printf '%s\n' '{"devDependencies":{"@storybook/react":"^7.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Storybook"* ]]
}

@test "javascript: Oxlint detected from oxlint dep" {
  printf '%s\n' '{"devDependencies":{"oxlint":"^0.1.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Oxlint"* ]]
}

@test "javascript: Prisma detected from prisma dep" {
  printf '%s\n' '{"devDependencies":{"prisma":"^5.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Prisma"* ]]
}

@test "javascript: Prisma detected from @prisma/client dep" {
  printf '%s\n' '{"dependencies":{"@prisma/client":"^5.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Prisma"* ]]
}

@test "javascript: Drizzle detected from drizzle-orm dep" {
  printf '%s\n' '{"dependencies":{"drizzle-orm":"^0.29.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Drizzle"* ]]
}

@test "javascript: MUI detected from @mui/material dep" {
  printf '%s\n' '{"dependencies":{"@mui/material":"^5.15.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"MUI"* ]]
}

@test "javascript: DaisyUI shown when Tailwind also present" {
  printf '%s\n' '{"devDependencies":{"daisyui":"^4.0.0","tailwindcss":"^3.4.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"DaisyUI"* ]]
}

@test "javascript: DaisyUI suppressed when no Tailwind" {
  printf '%s\n' '{"devDependencies":{"daisyui":"^4.0.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"DaisyUI"* ]]
}

@test "javascript: UnoCSS detected from unocss dep" {
  printf '%s\n' '{"devDependencies":{"unocss":"^0.58.0"}}' > "$FAKE_PROJ/package.json"
  bar_run javascript "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"UnoCSS"* ]]
}
