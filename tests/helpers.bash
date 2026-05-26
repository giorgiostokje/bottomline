#!/usr/bin/env bash
# Shared test helpers — load with: load '../helpers'

BOTTOMLINE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."

# ---------------------------------------------------------------------------
# ANSI stripping
# ---------------------------------------------------------------------------

strip_ansi() {
  perl -pe '
    s/\e\[[0-9;]*[mKJHf]//g;       # SGR codes (colors, bold, reset)
    s/\e\]8;;[^\e]*\e\\//g;        # OSC 8 hyperlink open
    s/\e\]8;;\e\\//g;              # OSC 8 hyperlink close
  '
}

# ---------------------------------------------------------------------------
# Function extraction helper (for unit tests)
# ---------------------------------------------------------------------------

# Extract a function body from source files and eval it into the current shell.
# Usage: _bl_extract function_name file [file ...]
_bl_extract() {
  local name="$1"; shift
  local f body
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    body=$(sed -n "/^${name}() {\$/,/^\}$/p" "$f")
    [[ -n "$body" ]] && eval "$body" && return 0
  done
  return 1
}

# ---------------------------------------------------------------------------
# Config-isolated script runner
# ---------------------------------------------------------------------------

# Sets up a fake HOME for test isolation.
# settings.json, lib/, and themes/ are found via BASH_SOURCE (_BL_DIR) in
# bottomline.sh and do not need to be copied here.
setup_fake_home() {
  FAKE_HOME=$(mktemp -d)
  mkdir -p "$FAKE_HOME/.claude"
}

teardown_fake_home() {
  if [[ -n "${FAKE_HOME:-}" ]]; then
    rm -rf "$FAKE_HOME"
    FAKE_HOME=''
  fi
}

# Run bottomline.sh with an isolated HOME and controlled JSON input.
#
#   bl_run JSON [user_cfg_json] [proj_cfg_json]
#
# Sets $BL_OUTPUT_RAW (ANSI) and $BL_OUTPUT (stripped).
bl_run() {
  # NOTE: Do NOT use "${1:-{}}" — bash parses ${X:-{}} as "default={" plus a
  # trailing "}", appending an extra "}" to every argument. Use "$1" directly.
  local json="$1"
  if [[ -z "$json" ]]; then json='{}'; fi
  local user_cfg="${2:-}"
  local proj_cfg="${3:-}"

  if [[ -n "$user_cfg" ]]; then
    printf '%s' "$user_cfg" > "$FAKE_HOME/.claude/bottomline.json"
  fi

  if [[ -n "$proj_cfg" ]]; then
    _BL_PROJ_DIR=$(mktemp -d)
    mkdir -p "$_BL_PROJ_DIR/.claude"
    printf '%s' "$proj_cfg" > "$_BL_PROJ_DIR/.claude/bottomline.json"
    json=$(printf '%s' "$json" | jq --arg d "$_BL_PROJ_DIR" '.workspace.current_dir = $d')
  fi

  local tmpjson; tmpjson=$(mktemp)
  printf '%s' "$json" > "$tmpjson"

  BL_OUTPUT_RAW=$(HOME="$FAKE_HOME" bash "$BOTTOMLINE_ROOT/bottomline.sh" < "$tmpjson")
  BL_OUTPUT=$(printf '%s' "$BL_OUTPUT_RAW" | strip_ansi)

  rm -f "$tmpjson"
  if [[ -n "${_BL_PROJ_DIR:-}" ]]; then
    rm -rf "$_BL_PROJ_DIR"
    _BL_PROJ_DIR=''
  fi
}

# Write a minimal JSON-lines transcript file containing one assistant turn
# with the given token counts.  Sets $TRANSCRIPT_PATH.
#
#   make_transcript in out [cache_read] [cache_create]
make_transcript() {
  local in="${1:-0}" out="${2:-0}" cache_read="${3:-0}" cache_create="${4:-0}"
  TRANSCRIPT_PATH=$(mktemp)
  printf '{"type":"assistant","message":{"usage":{"input_tokens":%d,"output_tokens":%d,"cache_read_input_tokens":%d,"cache_creation_input_tokens":%d}}}\n' \
    "$in" "$out" "$cache_read" "$cache_create" > "$TRANSCRIPT_PATH"
}

cleanup_transcript() {
  if [[ -n "${TRANSCRIPT_PATH:-}" ]]; then
    rm -f "$TRANSCRIPT_PATH"
    TRANSCRIPT_PATH=''
  fi
}

# ---------------------------------------------------------------------------
# Bar test helpers
# ---------------------------------------------------------------------------

# Create a temporary project directory.  Sets $FAKE_PROJ.
setup_fake_proj() {
  FAKE_PROJ=$(mktemp -d)
}

teardown_fake_proj() {
  if [[ -n "${FAKE_PROJ:-}" ]]; then
    rm -rf "$FAKE_PROJ"
    FAKE_PROJ=''
  fi
}

# Run a bar script with an isolated project directory.
#
#   bar_run BAR_NAME PROJ_DIR [TTL_MINUTES] [BAR_PARAMS_JSON] [BAR_SEGMENTS_JSON]
#
# PROJ_DIR must already contain any signal files the bar needs.
# TTL_MINUTES defaults to 0 (caching disabled). Pass a positive integer to
# exercise cache hit/miss behaviour in cache.bats.
# BAR_PARAMS_JSON: JSON object passed as BOTTOMLINE_BAR_PARAMS (default: empty).
# BAR_SEGMENTS_JSON: JSON array passed as BOTTOMLINE_BAR_SEGMENTS (default: empty).
# Sets $BAR_OUTPUT_RAW (ANSI) and $BAR_OUTPUT (stripped).
bar_run() {
  local bar_name="$1"
  local proj_dir="${2:-}"
  local ttl="${3:-0}"
  local bar_params="${4:-}"
  local bar_segments="${5:-}"
  # Use a project-specific cache dir so cache files persist between bar_run calls
  # and are isolated between tests.  Default to /tmp when proj_dir is absent.
  local cache_dir="${proj_dir:+$proj_dir/.bl_cache}"
  if [[ -n "$cache_dir" ]]; then mkdir -p "$cache_dir"; fi

  BAR_OUTPUT_RAW=$(
    BOTTOMLINE_BAR_PARAMS="$bar_params" \
    BOTTOMLINE_BAR_SEGMENTS="$bar_segments" \
    BOTTOMLINE_BAR_REFRESH_MINUTES="$ttl" \
    BOTTOMLINE_PROJECT_DIR="$proj_dir" \
    BOTTOMLINE_CACHE_DIR="${cache_dir:-/tmp}" \
    BOTTOMLINE_LIB="$BOTTOMLINE_ROOT/lib" \
    BOTTOMLINE_ICON_TYPE=none \
    BOTTOMLINE_GRADIENT='"#1a1a1a"' \
    BOTTOMLINE_BAR_COLORS= \
    BOTTOMLINE_BG_R=26 BOTTOMLINE_BG_G=26 BOTTOMLINE_BG_B=26 \
    BOTTOMLINE_SEP='|' \
    BOTTOMLINE_BOLD='' BOTTOMLINE_RESET='' \
    BOTTOMLINE_TEXT_HEX='#e2d5c3' \
    BOTTOMLINE_ACCENT_HEX='#da7756' \
    BOTTOMLINE_WARN_HEX='#f4a261' \
    BOTTOMLINE_DANGER_HEX='#e05a4e' \
    bash "$BOTTOMLINE_ROOT/bars/${bar_name}.sh"
  )
  BAR_OUTPUT=$(printf '%s' "$BAR_OUTPUT_RAW" | strip_ansi)
}
