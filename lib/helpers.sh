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
R="$BOTTOMLINE_RESET"
B="$BOTTOMLINE_BOLD"
SEP="$BOTTOMLINE_SEP"
# shellcheck disable=SC2034  # used by scripts that source this file
FG_TEXT=$(make_fg   "$(hex_to_rgb "$BOTTOMLINE_TEXT_HEX")")
# shellcheck disable=SC2034
FG_ACCENT=$(make_fg "$(hex_to_rgb "$BOTTOMLINE_ACCENT_HEX")")
# shellcheck disable=SC2034
FG_WARN=$(make_fg   "$(hex_to_rgb "${BOTTOMLINE_WARN_HEX:-#f4a261}")")
# shellcheck disable=SC2034
FG_CRIT=$(make_fg   "$(hex_to_rgb "${BOTTOMLINE_DANGER_HEX:-#e05a4e}")")
