#!/usr/bin/env bash
# lib/colors.sh — resolves CFG_*_HEX into RGB triplets, ANSI FG escapes,
# and an 8-stop background gradient array. Depends on lib/ansi.sh for
# hex_to_rgb / make_fg / expand_bg.
#
# Inputs : CFG_TEXT_HEX, CFG_ACCENT_HEX, CFG_WARN_HEX, CFG_CRIT_HEX, CFG_BG
#          (set by lib/config.sh)
# Outputs: RGB_TEXT, RGB_ACCENT, RGB_WARN, RGB_CRIT,
#          FG_TEXT, FG_ACCENT, FG_WARN, FG_CRIT,
#          CFG_BG_EXP, C_R[0..7], C_G[0..7], C_B[0..7]
# Exports: resolve_color_hex, resolve_color (functions)

resolve_color_hex() {
  case "$1" in
    text)         printf '%s' "$CFG_TEXT_HEX"   ;;
    accent)       printf '%s' "$CFG_ACCENT_HEX" ;;
    warn|warning) printf '%s' "$CFG_WARN_HEX"   ;;
    crit|danger)  printf '%s' "$CFG_CRIT_HEX"   ;;
    *)            printf '%s' "$1" ;;
  esac
}

resolve_color() {
  case "$1" in
    text)            printf '%s' "$FG_TEXT"   ;;
    accent)          printf '%s' "$FG_ACCENT" ;;
    warn|warning)    printf '%s' "$FG_WARN"   ;;
    crit|danger)     printf '%s' "$FG_CRIT"   ;;
    \#*)             make_fg "$(hex_to_rgb "$1")" ;;
    *)               printf '%s' "$FG_TEXT"   ;;
  esac
}

declare -a C_R C_G C_B

bl_init_colors() {
  RGB_TEXT=$(hex_to_rgb   "$CFG_TEXT_HEX")
  RGB_ACCENT=$(hex_to_rgb "$CFG_ACCENT_HEX")
  RGB_WARN=$(hex_to_rgb   "$CFG_WARN_HEX")
  RGB_CRIT=$(hex_to_rgb   "$CFG_CRIT_HEX")

  FG_TEXT=$(make_fg "$RGB_TEXT")
  FG_ACCENT=$(make_fg "$RGB_ACCENT")
  FG_WARN=$(make_fg "$RGB_WARN")
  FG_CRIT=$(make_fg "$RGB_CRIT")

  CFG_BG_EXP=$(expand_bg "$CFG_BG" 8)
  local _i _hex
  for _i in $(seq 0 7); do
    _hex=$(printf '%s' "$CFG_BG_EXP" | jq -r ".[$_i]" 2>/dev/null)
    [[ -z "$_hex" ]] && _hex='#0F0F0F'
    read -r "C_R[$_i]" "C_G[$_i]" "C_B[$_i]" <<< "$(hex_to_rgb "$_hex")"
  done
}
