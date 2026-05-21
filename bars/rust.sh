#!/usr/bin/env bash
# Bottomline bar: Rust ecosystem bar
# Only renders when the project contains a Cargo.toml.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" || ! -f "$PROJ/Cargo.toml" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#f0ddd8")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#d05a38")")
  _bar_gradient='["#1a0a04","#301508"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_RUST=$'\xee\x9a\x8b'      # U+E68B  nf-seti-rust (Nerd Fonts v3+)
    IC_WORKSPACE=$'\xef\x81\xae' # U+F06E  nf-fa-eye
    ;;
  emoji)
    IC_RUST='🦀'
    IC_WORKSPACE='🗂'
    ;;
  *)
    IC_RUST='' IC_WORKSPACE=''
    ;;
esac


# ── Read Cargo.toml ───────────────────────────────────────────────────────────
edition=$(awk -F'"' '/^edition[[:space:]]*=/{print $2; exit}' "$PROJ/Cargo.toml" 2>/dev/null)
is_workspace=false
grep -q '^\[workspace\]' "$PROJ/Cargo.toml" && is_workspace=true


# ── Rust runtime ──────────────────────────────────────────────────────────────
rust_seg="${FG_ACCENT}${IC_RUST} ${FG_TEXT}Rust"
[[ -n "$edition" ]] && rust_seg+=" ${FG_ACCENT}${edition}"
$is_workspace && rust_seg+=" ${FG_ACCENT}${IC_WORKSPACE}${FG_TEXT} workspace"
add_seg "$rust_seg"

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
