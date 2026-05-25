#!/usr/bin/env bash
# Claude Code status line — Bottomline plugin
# Config precedence (highest → lowest):
#   <project>/.claude/bottomline.json  — project overrides
#   ~/.claude/bottomline.json          — user overrides
#   <plugin-dir>/settings.json         — shipped defaults

# ── ANSI helpers ──────────────────────────────────────────────────────────────
# shellcheck disable=SC2034  # read by flush() in lib/ansi.sh
R=$'\e[0m'
# shellcheck disable=SC2034
B=$'\e[1m'

# ── Pure utilities ────────────────────────────────────────────────────────────
_BL_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=lib/functions.sh
source "$_BL_DIR/lib/functions.sh"
# shellcheck source=lib/ansi.sh
source "$_BL_DIR/lib/ansi.sh"
# shellcheck source=lib/config.sh
source "$_BL_DIR/lib/config.sh"
# shellcheck source=lib/colors.sh
source "$_BL_DIR/lib/colors.sh"
# shellcheck source=lib/icons.sh
source "$_BL_DIR/lib/icons.sh"
# shellcheck source=lib/state.sh
source "$_BL_DIR/lib/state.sh"
# shellcheck source=lib/segments.sh
source "$_BL_DIR/lib/segments.sh"
# shellcheck source=lib/auto-bars.sh
source "$_BL_DIR/lib/auto-bars.sh"
# shellcheck source=lib/bars.sh
source "$_BL_DIR/lib/bars.sh"

bl_read_state
bl_load_config
bl_init_colors
bl_init_icons
bl_render_main_line
bl_apply_auto_bars
bl_render_bars
