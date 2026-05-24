#!/usr/bin/env bats
# Integration tests for the lua bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "lua: exits silently when no signal files present" {
  bar_run lua "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "lua: renders when .luarc.json present" {
  printf '{"runtime":{"version":"Lua 5.4"}}\n' > "$FAKE_PROJ/.luarc.json"
  bar_run lua "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Lua"* ]]
}

@test "lua: renders when .lua-version present" {
  printf '5.4\n' > "$FAKE_PROJ/.lua-version"
  bar_run lua "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Lua"* ]]
}

@test "lua: renders when *.rockspec present" {
  printf 'package = "myapp"\nversion = "1.0-1"\n' > "$FAKE_PROJ/myapp-1.0-1.rockspec"
  bar_run lua "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Lua"* ]]
}

@test "lua: shows Lua version from .lua-version file" {
  printf '5.4\n' > "$FAKE_PROJ/.lua-version"
  bar_run lua "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"5.4"* ]]
}

@test "lua: shows Lua version from .luarc.json" {
  printf '{"runtime":{"version":"Lua 5.4"}}\n' > "$FAKE_PROJ/.luarc.json"
  bar_run lua "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"5.4"* ]]
}

@test "lua: shows LuaRocks when .rockspec present" {
  printf 'package = "myapp"\nversion = "1.0-1"\ndependencies = {"lua >= 5.4"}\n' \
    > "$FAKE_PROJ/myapp-1.0-1.rockspec"
  bar_run lua "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"LuaRocks"* ]]
}

@test "lua: shows LOVE framework when conf.lua present" {
  touch "$FAKE_PROJ/.luarc.json"
  touch "$FAKE_PROJ/conf.lua"
  bar_run lua "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"LÖVE"* ]]
}

@test "lua: shows Busted when detected in rockspec" {
  printf 'package = "myapp"\nversion = "1.0-1"\ndependencies = {\n  "lua >= 5.4",\n  "busted >= 2.0"\n}\n' \
    > "$FAKE_PROJ/myapp-1.0-1.rockspec"
  bar_run lua "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Busted"* ]]
}

@test "lua: Busted suppresses LuaUnit when both in rockspec" {
  printf 'package = "myapp"\nversion = "1.0-1"\ndependencies = {\n  "lua >= 5.4",\n  "busted >= 2.0",\n  "luaunit >= 3.0"\n}\n' \
    > "$FAKE_PROJ/myapp-1.0-1.rockspec"
  bar_run lua "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Busted"* ]]
  [[ "$BAR_OUTPUT" != *"LuaUnit"* ]]
}

@test "lua: shows Luacheck when .luacheckrc present" {
  touch "$FAKE_PROJ/.luarc.json"
  touch "$FAKE_PROJ/.luacheckrc"
  bar_run lua "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Luacheck"* ]]
}

@test "lua: shows StyLua when .stylua.toml present" {
  touch "$FAKE_PROJ/.luarc.json"
  touch "$FAKE_PROJ/.stylua.toml"
  bar_run lua "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"StyLua"* ]]
}
