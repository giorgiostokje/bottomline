#!/usr/bin/env bash
# Bar-side helpers — sources lib/ansi.sh, then layers cache helpers and
# BOTTOMLINE_* convenience vars on top.
# Source at the top of your bar (after the shebang and guard):
#   source "$BOTTOMLINE_LIB/helpers.sh"

source "$(dirname "${BASH_SOURCE[0]}")/ansi.sh"

# ── Cache helpers ─────────────────────────────────────────────────────────────

bl_cache_path() {
  local name="$1" ttl="${2:-5}" proj="$3"
  shift 3
  local bucket projhash fingerprint cache_dir
  cache_dir="${BOTTOMLINE_CACHE_DIR:-/tmp}"
  bucket=$(( $(date +%s) / (ttl * 60) ))
  projhash=$(printf '%s' "$proj" | (md5sum 2>/dev/null || md5) | cut -c1-8)
  fingerprint=$(bl_mtime_fingerprint "$@")
  printf '%s/bl_%s_%s_%s_%s.txt' "$cache_dir" "$name" "$projhash" "$fingerprint" "$bucket"
}

bl_cache_write() {
  local cache_file="$1" output="$2"
  if [[ -z "$output" ]]; then return; fi
  local stem; stem="${cache_file%_*_*.txt}"
  local cache_dir; cache_dir=$(dirname "$cache_file")
  if (set -C; printf '%s' "$output" > "$cache_file") 2>/dev/null; then
    find -L "$cache_dir" -maxdepth 1 -name "${stem##*/}_*_*.txt" \
      ! -name "$(basename "$cache_file")" -print0 2>/dev/null | xargs -0 rm -f 2>/dev/null
  fi
}

bl_mtime_fingerprint() {
  local mtimes=''
  for f in "$@"; do
    if [[ -f "$f" ]]; then
      mtimes+=$(stat -c '%Y' "$f" 2>/dev/null || stat -f '%m' "$f" 2>/dev/null || printf '0')
      mtimes+=$'\n'
    else
      mtimes+=$'0\n'
    fi
  done
  printf '%s' "$mtimes" | (md5sum 2>/dev/null || md5) | cut -c1-8
}

# ── Convenience variables from BOTTOMLINE_* env vars ─────────────────────────
# shellcheck disable=SC2034  # used by scripts that source this file
R="$BOTTOMLINE_RESET"
# shellcheck disable=SC2034
B="$BOTTOMLINE_BOLD"
# shellcheck disable=SC2034
SEP="$BOTTOMLINE_SEP"
# shellcheck disable=SC2034  # used by scripts that source this file
FG_TEXT=$(make_fg   "$(hex_to_rgb "$BOTTOMLINE_TEXT_HEX")")
# shellcheck disable=SC2034
FG_ACCENT=$(make_fg "$(hex_to_rgb "$BOTTOMLINE_ACCENT_HEX")")
# shellcheck disable=SC2034
FG_WARN=$(make_fg   "$(hex_to_rgb "${BOTTOMLINE_WARN_HEX:-#f4a261}")")
# shellcheck disable=SC2034
FG_CRIT=$(make_fg   "$(hex_to_rgb "${BOTTOMLINE_DANGER_HEX:-#e05a4e}")")

# ── Bar boilerplate helpers ───────────────────────────────────────────────────

# bl_bar_init <name> <fallback_text_hex> <fallback_accent_hex> <fallback_gradient_json> [cache_input_file…]
# Collapses the cache-check + color-init prelude. Sets FG_TEXT, FG_ACCENT,
# _bar_gradient, _bl_ttl, _bl_cache. On cache hit: prints cached output and
# exit 0s the calling script. Reads $PROJ (must be set before calling).
bl_bar_init() {
  local name="$1" fb_text="$2" fb_accent="$3" fb_gradient="$4"
  shift 4
  _bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
  [[ "$_bl_ttl" =~ ^[0-9]+$ ]] || _bl_ttl=5
  if [[ "$_bl_ttl" -gt 0 ]]; then
    _bl_cache=$(bl_cache_path "$name" "$_bl_ttl" "$PROJ" "$@")
    if [[ -f "$_bl_cache" ]]; then
      cat "$_bl_cache"
      exit 0
    fi
  fi
  if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
    FG_TEXT=$(make_fg "$(hex_to_rgb "$fb_text")")
    FG_ACCENT=$(make_fg "$(hex_to_rgb "$fb_accent")")
    _bar_gradient="$fb_gradient"
  else
    _bar_gradient="$BOTTOMLINE_GRADIENT"
  fi
}

# bl_bar_finish <gradient_json>
# Wraps the post-render tail. Returns 0 if _sc is empty (nothing to render).
# Otherwise captures flush output, caches it if _bl_ttl > 0, and prints it.
bl_bar_finish() {
  local gradient_json="$1"
  # shellcheck disable=SC2154  # _sc declared in lib/ansi.sh
  (( ${#_sc[@]} == 0 )) && return 0
  local out
  out=$(flush "$gradient_json")
  if [[ "$_bl_ttl" -gt 0 && -n "$out" ]]; then
    bl_cache_write "$_bl_cache" "$out"
  fi
  printf '%s' "$out"
}

# bl_icon_set <var_name> <nerd_bytes> <emoji> [fallback]
# Sets a single icon variable based on BOTTOMLINE_ICON_TYPE.
bl_icon_set() {
  local var="$1" nerd="$2" emoji="$3" fallback="${4:-}"
  [[ "$var" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1
  case "${BOTTOMLINE_ICON_TYPE:-}" in
    nerd)  printf -v "$var" '%s' "$nerd"     ;;
    emoji) printf -v "$var" '%s' "$emoji"    ;;
    *)     printf -v "$var" '%s' "$fallback" ;;
  esac
}

# bl_version_seg <icon> <label> [version]
# Emits an "icon label [vX.Y.Z]" segment. Always renders the label (and icon
# if non-empty). Appends version only if non-empty.
# Note: in icon-type=none mode, this helper drops the icon entirely
# (no leading FG_ACCENT escape or space), unlike the pre-refactor
# inline pattern which preserved them. The cleaner output is
# intentional.
bl_version_seg() {
  local icon="$1" label="$2" version="$3"
  local seg
  if [[ -n "$icon" ]]; then
    seg="${FG_ACCENT}${icon} ${FG_TEXT}${label}"
  else
    seg="${FG_TEXT}${label}"
  fi
  [[ -n "$version" ]] && seg+=" ${FG_ACCENT}v${version}"
  add_seg "$seg"
}
