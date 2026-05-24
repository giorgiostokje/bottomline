#!/usr/bin/env bash
# Bottomline bar: Lua ecosystem bar
# Renders for projects with .luarc.json, .luarc.jsonc, .lua-version, or a *.rockspec file.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
if [[ "$_bl_ttl" -gt 0 ]]; then
  _bl_cache=$(bl_cache_path "lua" "$_bl_ttl" "$PROJ" \
    "$PROJ/.luarc.json" "$PROJ/.luarc.jsonc" "$PROJ/.lua-version")
  [[ -f "$_bl_cache" ]] && cat "$_bl_cache" && exit 0
fi

# Hard guard: AFTER cache block
# Check for .luarc.json, .luarc.jsonc, .lua-version, or any *.rockspec at project root
_lua_signal=false
[[ -f "$PROJ/.luarc.json" ]]  && _lua_signal=true
[[ -f "$PROJ/.luarc.jsonc" ]] && _lua_signal=true
[[ -f "$PROJ/.lua-version" ]] && _lua_signal=true
ls "$PROJ"/*.rockspec > /dev/null 2>&1 && _lua_signal=true
$_lua_signal || exit 0

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#c8d8e8")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#5b9bd5")")
  _bar_gradient='["#000820","#001840"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_LUA=$'\xee\x9c\xae'    # U+E72E  nf-seti-lua
    IC_PKG=$'\xef\x80\xbc'    # U+F0BC  nf-fa-cube
    IC_GAME=$'\xef\x84\xa2'   # U+F122  nf-fa-gamepad  (LOVE2D)
    IC_TEST=$'\xef\x81\x80'   # U+F040  nf-fa-pencil
    IC_LINT=$'\xef\x80\x8c'   # U+F00C  nf-fa-check
    ;;
  emoji)
    IC_LUA='🌙'
    IC_PKG='📦'
    IC_GAME='🎮'
    IC_TEST='🧪'
    IC_LINT='✓'
    ;;
  *)
    IC_LUA='' IC_PKG='' IC_GAME='' IC_TEST='' IC_LINT=''
    ;;
esac

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
  lua_version=$(lua -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
fi

# ── Slot 2: Package manager — LuaRocks ────────────────────────────────────────
has_luarocks=false
luarocks_version=''
_has_rockspec=false
ls "$PROJ"/*.rockspec > /dev/null 2>&1 && _has_rockspec=true
if command -v luarocks > /dev/null 2>&1; then
  has_luarocks=true
  luarocks_version=$(luarocks --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
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

_bl_out=$(
  # ── Slot 1: Runtime ───────────────────────────────────────────────────────────
  lua_seg="${FG_ACCENT}${IC_LUA} ${FG_TEXT}Lua"
  [[ -n "$lua_version" ]] && lua_seg+=" ${FG_ACCENT}${lua_version}"
  add_seg "$lua_seg"

  # ── Slot 2: Package manager ───────────────────────────────────────────────────
  if $has_luarocks; then
    rocks_seg="${FG_ACCENT}${IC_PKG} ${FG_TEXT}LuaRocks"
    [[ -n "$luarocks_version" ]] && rocks_seg+=" ${FG_ACCENT}${luarocks_version}"
    add_seg "$rocks_seg"
  fi

  # ── Slot 3: Framework ─────────────────────────────────────────────────────────
  if [[ -n "$framework" ]]; then
    add_seg "${FG_ACCENT}${IC_GAME} ${FG_TEXT}${framework}"
  fi

  # ── Slot 5: Testing ───────────────────────────────────────────────────────────
  $has_busted   && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}Busted"
  $has_luaunit  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}LuaUnit"

  # ── Slot 6: Tooling ───────────────────────────────────────────────────────────
  $has_luacheck && add_seg "${FG_ACCENT}${IC_LINT} ${FG_TEXT}Luacheck"
  $has_stylua   && add_seg "${FG_ACCENT}${IC_LINT} ${FG_TEXT}StyLua"

  (( ${#_sc[@]} == 0 )) && exit 0
  flush "$_bar_gradient"
)
if [[ "$_bl_ttl" -gt 0 ]]; then
  bl_cache_write "$_bl_cache" "$_bl_out"
fi
printf '%s' "$_bl_out"
