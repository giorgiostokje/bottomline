#!/usr/bin/env bash
# Bottomline bar: Shell / Bash ecosystem bar
# Only renders when .sh scripts exist at the project root.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
if [[ "$_bl_ttl" -gt 0 ]]; then
  _bl_cache=$(bl_cache_path "shell" "$_bl_ttl" "$PROJ")
  [[ -f "$_bl_cache" ]] && cat "$_bl_cache" && exit 0
fi

# Hard guard: exit silently when no shell scripts exist at the project root.
_has_sh=false
for _f in "$PROJ"/*.sh; do [[ -f "$_f" ]] && _has_sh=true && break; done
$_has_sh || exit 0
unset _f _has_sh

# ── Icons ─────────────────────────────────────────────────────────────────────
case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_SHELL=$'\xef\x84\xa0'    # U+F120  nf-fa-terminal
    IC_SC=$'\xef\x80\x8c'       # U+F00C  nf-fa-check
    IC_TEST=$'\xef\x81\x80'     # U+F040  nf-fa-pencil
    IC_MAKE=$'\xef\x82\x85'     # U+F085  nf-fa-cogs
    ;;
  emoji)
    IC_SHELL='🐚'
    IC_SC='✓'
    IC_TEST='🧪'
    IC_MAKE='⚙'
    ;;
  *)
    IC_SHELL='' IC_SC='' IC_TEST='' IC_MAKE=''
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

# ── bats ──────────────────────────────────────────────────────────────────────
bats_version=''
if command -v bats > /dev/null 2>&1; then
  bats_version=$(bats --version 2>/dev/null | awk '{print $2; exit}')
fi
has_bats=false
[[ -n "$bats_version" ]] && has_bats=true
# Fallback: any .bats file in the project tree (max 3 levels deep)
if ! $has_bats; then
  if find "$PROJ" -maxdepth 3 -type f -name '*.bats' -print -quit 2>/dev/null | grep -q .; then
    has_bats=true
  fi
fi

# ── make ──────────────────────────────────────────────────────────────────────
has_make=false
[[ -f "$PROJ/Makefile" ]] && has_make=true

_bl_out=$(
  # ── Segments (canonical slot order) ───────────────────────────────────────────
  # Slot 1: Runtime
  shell_seg="${FG_ACCENT}${IC_SHELL} ${FG_TEXT}${target_shell}"
  [[ -n "$bash_version" ]] && shell_seg+=" ${FG_ACCENT}v${bash_version}"
  add_seg "$shell_seg"

  # Slot 5: Testing
  if $has_bats; then
    if [[ -n "$bats_version" ]]; then
      add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}bats ${FG_ACCENT}v${bats_version}"
    else
      add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}bats"
    fi
  fi

  # Slot 6: Tooling
  [[ -n "$sc_version" ]] && add_seg "${FG_ACCENT}${IC_SC} ${FG_TEXT}ShellCheck ${FG_ACCENT}v${sc_version}"
  $has_make && add_seg "${FG_ACCENT}${IC_MAKE} ${FG_TEXT}make"

  (( ${#_sc[@]} == 0 )) && exit 0
  flush "$_bar_gradient"
)
if [[ "$_bl_ttl" -gt 0 ]]; then
  bl_cache_write "$_bl_cache" "$_bl_out"
fi
printf '%s' "$_bl_out"
