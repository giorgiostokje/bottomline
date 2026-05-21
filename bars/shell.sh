#!/usr/bin/env bash
# Bottomline bar: Shell / Bash ecosystem bar
# Only renders when .sh scripts exist at the project root.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# Hard guard: exit silently when no shell scripts exist at the project root.
_has_sh=false
for _f in "$PROJ"/*.sh; do [[ -f "$_f" ]] && _has_sh=true && break; done
$_has_sh || exit 0
unset _f _has_sh

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

# ── Icons ─────────────────────────────────────────────────────────────────────
case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_SHELL=$'\xef\x84\xa0'    # U+F120  nf-fa-terminal
    IC_SC=$'\xef\x80\x8c'       # U+F00C  nf-fa-check
    ;;
  emoji)
    IC_SHELL='🐚'
    IC_SC='✓'
    ;;
  *)
    IC_SHELL='' IC_SC=''
    ;;
esac

# ── Palette ───────────────────────────────────────────────────────────────────
if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg   "$(hex_to_rgb "#c8e8b0")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#4eb144")")
  _bar_gradient='["#0b1a06","#18330e"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

# ── Target shell ──────────────────────────────────────────────────────────────
# Read declared shell from .shellcheckrc if present; fall back to bash.
target_shell='bash'
if [[ -f "$PROJ/.shellcheckrc" ]]; then
  _sc_shell=$(awk -F= '/^shell[ \t]*=/{gsub(/[ \t]/,"",$2); print $2; exit}' \
    "$PROJ/.shellcheckrc" 2>/dev/null)
  [[ -n "$_sc_shell" ]] && target_shell="$_sc_shell"
  unset _sc_shell
fi

# ── Bash version ──────────────────────────────────────────────────────────────
# BASH_VERSION is always set; strip the build/release suffix.
bash_version="${BASH_VERSION%%(*}"

# ── ShellCheck ────────────────────────────────────────────────────────────────
sc_version=''
if command -v shellcheck > /dev/null 2>&1; then
  sc_version=$(shellcheck --version 2>/dev/null | awk '/^version:/{print $2; exit}')
fi

# ── Segments ──────────────────────────────────────────────────────────────────
shell_seg="${FG_ACCENT}${IC_SHELL} ${FG_TEXT}${target_shell}"
[[ -n "$bash_version" ]] && shell_seg+=" ${FG_ACCENT}v${bash_version}"
add_seg "$shell_seg"

[[ -n "$sc_version" ]] && add_seg "${FG_ACCENT}${IC_SC} ${FG_TEXT}sc ${FG_ACCENT}v${sc_version}"

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
