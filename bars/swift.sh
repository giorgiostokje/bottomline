#!/usr/bin/env bash
# Bottomline bar: Swift ecosystem bar
# Only renders when the project contains a Package.swift.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" || ! -f "$PROJ/Package.swift" ]] && exit 0

source "$BOTTOMLINE_LIB/helpers.sh"

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#f5ddd8")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#f05138")")
  _bar_gradient='["#1c0a06","#331008"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_SWIFT=$'\xee\x9d\x95'   # U+E755  nf-dev-swift
    IC_VAPOR=$'\xef\x83\x90'   # U+F0D0  nf-fa-diamond  (Vapor's logo shape)
    ;;
  emoji)
    IC_SWIFT='🦅'
    IC_VAPOR='💧'
    ;;
  *)
    IC_SWIFT='' IC_VAPOR=''
    ;;
esac


# ── Read Swift tools version from Package.swift first line ────────────────────
# e.g. // swift-tools-version: 5.9
tools_version=$(head -1 "$PROJ/Package.swift" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')

# ── Detect Vapor from Package.resolved ───────────────────────────────────────
has_vapor=false vapor_version=''
resolved="$PROJ/Package.resolved"
if [[ -f "$resolved" ]]; then
  if jq -e '.pins | any(.[]; .identity == "vapor" or (.package // "") == "vapor")' \
       "$resolved" > /dev/null 2>&1; then
    has_vapor=true
    vapor_version=$(jq -r '
      .pins[] | select(.identity == "vapor" or (.package // "") == "vapor")
      | .state.version // ""
    ' "$resolved" 2>/dev/null)
  fi
fi

# Fallback: grep Package.swift for vapor dependency declaration.
if ! $has_vapor && grep -qi 'vapor/vapor\|\.package.*vapor' "$PROJ/Package.swift" 2>/dev/null; then
  has_vapor=true
fi


# ── Swift runtime ─────────────────────────────────────────────────────────────
swift_seg="${FG_ACCENT}${IC_SWIFT} ${FG_TEXT}Swift"
[[ -n "$tools_version" ]] && swift_seg+=" ${FG_ACCENT}tools v${tools_version}"
add_seg "$swift_seg"

# ── Vapor ─────────────────────────────────────────────────────────────────────
if $has_vapor; then
  vapor_seg="${FG_ACCENT}${IC_VAPOR} ${FG_TEXT}Vapor"
  [[ -n "$vapor_version" ]] && vapor_seg+=" ${FG_ACCENT}v${vapor_version}"
  add_seg "$vapor_seg"
fi

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
