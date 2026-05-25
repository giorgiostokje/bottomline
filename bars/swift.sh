#!/usr/bin/env bash
# Bottomline bar: Swift ecosystem bar
# Only renders when the project contains a Package.swift.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init swift "#f5ddd8" "#f05138" '["#1c0a06","#331008"]' "$PROJ/Package.swift" "$PROJ/Package.resolved"

[[ ! -f "$PROJ/Package.swift" ]] && exit 0

bl_icon_set IC_SWIFT $'\xee\x9d\x95' '🦅'
bl_icon_set IC_VAPOR $'\xef\x83\x90' '💧'
bl_icon_set IC_WEB   $'\xef\x83\xac' '🌐'
bl_icon_set IC_NET   $'\xef\x82\xac' '📡'
bl_icon_set IC_TEST  $'\xef\x81\x80' '🧪'
bl_icon_set IC_LINT  $'\xef\x80\x8c' '✓'
bl_icon_set IC_FMT   $'\xef\x80\xb1' '🖋'


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

# ── Detect ecosystem from Package.resolved ────────────────────────────────────
has_hummingbird=false
has_alamofire=false
alamofire_version=''
has_quick=false
has_swift_testing=false
if [[ -f "$resolved" ]]; then
  grep -q '"hummingbird"' "$resolved" 2>/dev/null && has_hummingbird=true
  grep -q '"alamofire"' "$resolved" 2>/dev/null && has_alamofire=true
  grep -q '"quick"' "$resolved" 2>/dev/null && has_quick=true
  grep -q '"swift-testing"' "$resolved" 2>/dev/null && has_swift_testing=true
fi

# Alamofire version detection
if $has_alamofire && [[ -f "$resolved" ]]; then
  alamofire_version=$(jq -r '
    .pins[] | select(.identity == "alamofire" or ((.package // "") | ascii_downcase) == "alamofire")
    | .state.version // ""
  ' "$resolved" 2>/dev/null)
fi

# XCTest: present when Package.swift declares a .testTarget AND Quick/SwiftTesting absent
has_xctest=false
if [[ -f "$PROJ/Package.swift" ]] && grep -q '.testTarget' "$PROJ/Package.swift" 2>/dev/null; then
  has_xctest=true
fi
# Layering: Quick suppresses XCTest; Swift Testing replaces XCTest in segment shown
$has_quick && has_xctest=false
$has_swift_testing && has_xctest=false

has_swiftlint=false
if [[ -f "$PROJ/.swiftlint.yml" || -f "$PROJ/.swiftlint.yaml" ]]; then
  has_swiftlint=true
elif command -v swiftlint > /dev/null 2>&1; then
  has_swiftlint=true
fi

has_swiftformat=false
if [[ -f "$PROJ/.swiftformat" ]]; then
  has_swiftformat=true
elif command -v swiftformat > /dev/null 2>&1; then
  has_swiftformat=true
fi

# ── Swift runtime ─────────────────────────────────────────────────────────────
swift_seg="${FG_ACCENT}${IC_SWIFT} ${FG_TEXT}Swift"
[[ -n "$tools_version" ]] && swift_seg+=" ${N}${FG_ACCENT}tools v${tools_version}"
add_seg "$swift_seg"

# ── Vapor ─────────────────────────────────────────────────────────────────────
$has_vapor && bl_version_seg "$IC_VAPOR" Vapor "$vapor_version"

# Slot 3: Hummingbird (alongside Vapor if both present)
$has_hummingbird \
  && add_seg "${FG_ACCENT}${IC_WEB} ${FG_TEXT}Hummingbird"

# Slot 5: Testing (layering: Quick > XCTest; Swift Testing standalone)
$has_quick \
  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}Quick"
$has_swift_testing \
  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}Swift Testing"
$has_xctest \
  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}XCTest"

# Slot 6: Tooling (order: SwiftLint → SwiftFormat → Alamofire)
$has_swiftlint \
  && add_seg "${FG_ACCENT}${IC_LINT} ${FG_TEXT}SwiftLint"
$has_swiftformat \
  && add_seg "${FG_ACCENT}${IC_FMT} ${FG_TEXT}SwiftFormat"
$has_alamofire && bl_version_seg "$IC_NET" Alamofire "$alamofire_version"

bl_bar_finish "$_bar_gradient"
