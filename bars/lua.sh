#!/usr/bin/env bash
# Bottomline bar: Lua ecosystem bar
# Renders for projects with .luarc.json, .luarc.jsonc, .lua-version, or a *.rockspec file.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

_bl_rockspec=''
for _f in "$PROJ"/*.rockspec; do [[ -f "$_f" ]] && { _bl_rockspec=$_f; break; }; done
bl_bar_init lua "#c8d8e8" "#5b9bd5" '["#000820","#001840"]' \
  "$PROJ/.luarc.json" "$PROJ/.luarc.jsonc" "$PROJ/.lua-version" ${_bl_rockspec:+"$_bl_rockspec"}

_lua_signal=false
[[ -f "$PROJ/.luarc.json" ]]  && _lua_signal=true
[[ -f "$PROJ/.luarc.jsonc" ]] && _lua_signal=true
[[ -f "$PROJ/.lua-version" ]] && _lua_signal=true
ls "$PROJ"/*.rockspec > /dev/null 2>&1 && _lua_signal=true
$_lua_signal || exit 0

bl_icon_set IC_LUA  $'\xee\x9c\xae' '🌙'  # U+E72E  nf-seti-lua
bl_icon_set IC_PKG  $'\xef\x80\xbc' '📦'  # U+F0BC  nf-fa-cube
bl_icon_set IC_GAME $'\xef\x84\xa2' '🎮'  # U+F122  nf-fa-gamepad  (LOVE2D)
bl_icon_set IC_TEST $'\xef\x81\x80' '🧪'  # U+F040  nf-fa-pencil
bl_icon_set IC_LINT $'\xef\x80\x8c' '✓'   # U+F00C  nf-fa-check

# ── Slot 1: Runtime — Lua version ─────────────────────────────────────────────
lua_version=''
# Priority 1: .lua-version file
if [[ -f "$PROJ/.lua-version" ]]; then
  lua_version=$(tr -d '[:space:]' < "$PROJ/.lua-version")
fi
# Priority 2: runtime.version in .luarc.json
if [[ -z "$lua_version" && -f "$PROJ/.luarc.json" ]]; then
  lua_version=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$PROJ/.luarc.json" 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+' | head -1)
fi
# Priority 3: lua binary on PATH
if [[ -z "$lua_version" ]]; then
  _lua_raw=$(lua -v 2>&1)
  _lua_exit=$?
  (( _lua_exit != 0 )) && bl_log debug lua "lua -v exit=${_lua_exit}"
  lua_version=$(printf '%s' "$_lua_raw" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
fi

# ── Slot 2: Package manager — LuaRocks ────────────────────────────────────────
has_luarocks=false
luarocks_version=''
_has_rockspec=false
ls "$PROJ"/*.rockspec > /dev/null 2>&1 && _has_rockspec=true
if command -v luarocks > /dev/null 2>&1; then
  has_luarocks=true
  _luarocks_raw=$(luarocks --version 2>/dev/null)
  _luarocks_exit=$?
  (( _luarocks_exit != 0 )) && bl_log debug lua "luarocks --version exit=${_luarocks_exit}"
  luarocks_version=$(printf '%s' "$_luarocks_raw" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
elif $_has_rockspec; then
  has_luarocks=true
fi

# ── Slot 3: Framework ─────────────────────────────────────────────────────────
framework=''
# LÖVE (Love2D): conf.lua is Love2D-specific
[[ -f "$PROJ/conf.lua" ]] && framework='LÖVE'
# OpenResty: nginx.conf with Lua directives
if [[ -z "$framework" && -f "$PROJ/nginx.conf" ]]; then
  grep -qE 'lua_package_path|content_by_lua' "$PROJ/nginx.conf" 2>/dev/null && framework='OpenResty'
fi
# Lapis: config.moon or config.lua containing "lapis"
if [[ -z "$framework" ]]; then
  for _lapis_cfg in "$PROJ/config.moon" "$PROJ/config.lua"; do
    if [[ -f "$_lapis_cfg" ]] && grep -qi 'lapis' "$_lapis_cfg" 2>/dev/null; then
      framework='Lapis'
      break
    fi
  done
fi

# ── Slot 5: Testing ───────────────────────────────────────────────────────────
has_busted=false
has_luaunit=false
if command -v busted > /dev/null 2>&1; then
  has_busted=true
fi
if ! $has_busted && ls "$PROJ"/*.rockspec > /dev/null 2>&1; then
  grep -qE 'busted' "$PROJ"/*.rockspec 2>/dev/null && has_busted=true
fi
# LuaUnit — only check if Busted not found (Busted suppresses LuaUnit)
if ! $has_busted && ls "$PROJ"/*.rockspec > /dev/null 2>&1; then
  grep -q 'luaunit' "$PROJ"/*.rockspec 2>/dev/null && has_luaunit=true
fi

# ── Slot 6: Tooling ───────────────────────────────────────────────────────────
has_luacheck=false
has_stylua=false
# Luacheck: binary, config file, or rockspec dep
if command -v luacheck > /dev/null 2>&1; then
  has_luacheck=true
elif [[ -f "$PROJ/.luacheckrc" ]]; then
  has_luacheck=true
elif ls "$PROJ"/*.rockspec > /dev/null 2>&1 && grep -q 'luacheck' "$PROJ"/*.rockspec 2>/dev/null; then
  has_luacheck=true
fi
# StyLua: binary or config file
if command -v stylua > /dev/null 2>&1; then
  has_stylua=true
elif [[ -f "$PROJ/.stylua.toml" ]]; then
  has_stylua=true
fi

  # ── Slot 1: Runtime ───────────────────────────────────────────────────────────
  lua_seg="${FG_ACCENT}${IC_LUA} ${FG_TEXT}Lua"
  [[ -n "$lua_version" ]] && lua_seg+=" ${N}${FG_ACCENT}${lua_version}"
  add_seg "$lua_seg"

  # ── Slot 2: Package manager ───────────────────────────────────────────────────
  $has_luarocks && bl_seg "$IC_PKG" LuaRocks "$luarocks_version"

  # ── Slot 3: Framework ─────────────────────────────────────────────────────────
  [[ -n "$framework" ]] && bl_seg "$IC_GAME" "$framework"

  # ── Slot 5: Testing ───────────────────────────────────────────────────────────
  $has_busted   && bl_seg "$IC_TEST" Busted
  $has_luaunit  && bl_seg "$IC_TEST" LuaUnit

  # ── Slot 6: Tooling ───────────────────────────────────────────────────────────
  $has_luacheck && bl_seg "$IC_LINT" Luacheck
  $has_stylua   && bl_seg "$IC_LINT" StyLua

bl_bar_finish "$_bar_gradient"
