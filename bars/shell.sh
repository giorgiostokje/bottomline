#!/usr/bin/env bash
# Bottomline bar: Shell / Bash ecosystem bar
# Only renders when .sh scripts exist at the project root.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init shell "#c8e8b0" "#4eb144" '["#0b1a06","#18330e"]'

# Hard guard: exit silently when no shell scripts exist at the project root.
_has_sh=false
for _f in "$PROJ"/*.sh; do [[ -f "$_f" ]] && _has_sh=true && break; done
$_has_sh || exit 0
unset _f _has_sh

# ── Icons ─────────────────────────────────────────────────────────────────────
bl_icon_set IC_SHELL $'\xef\x84\xa0' '🐚'  # U+F120  nf-fa-terminal
bl_icon_set IC_SC    $'\xef\x80\x8c' '✓'   # U+F00C  nf-fa-check
bl_icon_set IC_TEST  $'\xef\x81\x80' '🧪'  # U+F040  nf-fa-pencil
bl_icon_set IC_MAKE  $'\xef\x82\x85' '⚙'   # U+F085  nf-fa-cogs

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

# ── Segments (canonical slot order) ───────────────────────────────────────────

# Slot 1: Runtime
bl_version_seg "$IC_SHELL" "$target_shell" "$bash_version"

# Slot 5: Testing
$has_bats && bl_version_seg "$IC_TEST" bats "$bats_version"

# Slot 6: Tooling
[[ -n "$sc_version" ]] && bl_version_seg "$IC_SC" ShellCheck "$sc_version"
$has_make && add_seg "${FG_ACCENT}${IC_MAKE} ${FG_TEXT}make"

bl_bar_finish "$_bar_gradient"
