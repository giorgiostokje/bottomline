#!/usr/bin/env bash
# Bottomline bar: Go ecosystem bar
# Only renders when the project contains a go.mod.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" || ! -f "$PROJ/go.mod" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#c8e8f4")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#29bcd8")")
  _bar_gradient='["#031824","#054860"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_GO=$'\xee\x9c\xa4'        # U+E724  nf-seti-go_lang
    IC_WORKSPACE=$'\xef\x81\xae' # U+F06E  nf-fa-eye
    ;;
  emoji)
    IC_GO='🐹'
    IC_WORKSPACE='🗂'
    ;;
  *)
    IC_GO='' IC_WORKSPACE=''
    ;;
esac


# ── Read go.mod ───────────────────────────────────────────────────────────────
go_version=$(awk '/^go /{print $2; exit}' "$PROJ/go.mod" 2>/dev/null)
is_workspace=false
[[ -f "$PROJ/go.work" ]] && is_workspace=true


# ── Go runtime ────────────────────────────────────────────────────────────────
go_seg="${FG_ACCENT}${IC_GO} ${FG_TEXT}Go"
[[ -n "$go_version" ]] && go_seg+=" ${FG_ACCENT}v${go_version}"
$is_workspace && go_seg+=" ${FG_ACCENT}${IC_WORKSPACE}${FG_TEXT} workspace"
add_seg "$go_seg"

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
