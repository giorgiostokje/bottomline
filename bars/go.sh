#!/usr/bin/env bash
# Bottomline bar: Go ecosystem bar
# Only renders when the project contains a go.mod.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
if [[ "$_bl_ttl" -gt 0 ]]; then
  _bl_cache=$(bl_cache_path "go" "$_bl_ttl" "$PROJ")
  [[ -f "$_bl_cache" ]] && cat "$_bl_cache" && exit 0
fi

[[ ! -f "$PROJ/go.mod" ]] && exit 0

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
    IC_WEB=$'\xef\x83\xac'       # U+F0EC  nf-fa-exchange
    IC_TEST=$'\xef\x81\x80'      # U+F040  nf-fa-pencil
    IC_DB=$'\xef\x87\x80'        # U+F1C0  nf-fa-database
    IC_LINT=$'\xef\x80\x8c'      # U+F00C  nf-fa-check
    ;;
  emoji)
    IC_GO='🐹'
    IC_WORKSPACE='🗂'
    IC_WEB='🌐'
    IC_TEST='🧪'
    IC_DB='🗄'
    IC_LINT='✓'
    ;;
  *)
    IC_GO='' IC_WORKSPACE='' IC_WEB='' IC_TEST='' IC_DB='' IC_LINT=''
    ;;
esac


# ── Read go.mod ───────────────────────────────────────────────────────────────
go_version=$(awk '/^go /{print $2; exit}' "$PROJ/go.mod" 2>/dev/null)
is_workspace=false
[[ -f "$PROJ/go.work" ]] && is_workspace=true

# ── Detect frameworks/libraries ───────────────────────────────────────────────
framework=''
framework_display=''
framework_version=''
for fw in gin echo fiber chi; do
  case "$fw" in
    gin)   pat='github.com/gin-gonic/gin'   ; disp='Gin'   ;;
    echo)  pat='github.com/labstack/echo'   ; disp='Echo'  ;;
    fiber) pat='github.com/gofiber/fiber'   ; disp='Fiber' ;;
    chi)   pat='github.com/go-chi/chi'      ; disp='chi'   ;;
  esac
  if grep -q "$pat" "$PROJ/go.mod" 2>/dev/null; then
    framework="$fw"
    framework_display="$disp"
    framework_version=$(grep "$pat" "$PROJ/go.mod" 2>/dev/null \
      | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | sed 's/^v//')
    break
  fi
done

has_ginkgo=false
has_testify=false
ginkgo_version=''
testify_version=''
grep -q 'github.com/onsi/ginkgo' "$PROJ/go.mod" 2>/dev/null && has_ginkgo=true \
  && ginkgo_version=$(grep 'github.com/onsi/ginkgo' "$PROJ/go.mod" 2>/dev/null \
     | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | sed 's/^v//')
grep -q 'github.com/stretchr/testify' "$PROJ/go.mod" 2>/dev/null && has_testify=true \
  && testify_version=$(grep 'github.com/stretchr/testify' "$PROJ/go.mod" 2>/dev/null \
     | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | sed 's/^v//')
# Layering: Ginkgo suppresses testify
$has_ginkgo && has_testify=false

has_gorm=false
gorm_version=''
grep -q 'gorm.io/gorm' "$PROJ/go.mod" 2>/dev/null && has_gorm=true \
  && gorm_version=$(grep 'gorm.io/gorm' "$PROJ/go.mod" 2>/dev/null \
     | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | sed 's/^v//')

has_golangci=false
golangci_version=''
if command -v golangci-lint > /dev/null 2>&1; then
  has_golangci=true
  golangci_version=$(golangci-lint --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
elif [[ -f "$PROJ/.golangci.yml" || -f "$PROJ/.golangci.yaml" || -f "$PROJ/.golangci.toml" ]]; then
  has_golangci=true
fi

_bl_out=$(
  # ── Segments (canonical slot order) ───────────────────────────────────────────
  # Slot 1: Runtime
  go_seg="${FG_ACCENT}${IC_GO} ${FG_TEXT}Go"
  [[ -n "$go_version" ]] && go_seg+=" ${FG_ACCENT}v${go_version}"
  $is_workspace && go_seg+=" ${FG_ACCENT}${IC_WORKSPACE}${FG_TEXT} workspace"
  add_seg "$go_seg"

  # Slot 3: Framework
  if [[ -n "$framework" ]]; then
    fw_seg="${FG_ACCENT}${IC_WEB} ${FG_TEXT}${framework_display}"
    [[ -n "$framework_version" ]] && fw_seg+=" ${FG_ACCENT}v${framework_version}"
    add_seg "$fw_seg"
  fi

  # Slot 5: Testing
  if $has_ginkgo; then
    ginkgo_seg="${FG_ACCENT}${IC_TEST} ${FG_TEXT}Ginkgo"
    [[ -n "$ginkgo_version" ]] && ginkgo_seg+=" ${FG_ACCENT}v${ginkgo_version}"
    add_seg "$ginkgo_seg"
  fi
  if $has_testify; then
    testify_seg="${FG_ACCENT}${IC_TEST} ${FG_TEXT}testify"
    [[ -n "$testify_version" ]] && testify_seg+=" ${FG_ACCENT}v${testify_version}"
    add_seg "$testify_seg"
  fi

  # Slot 6: Tooling
  # static analysis first
  if $has_golangci; then
    lint_seg="${FG_ACCENT}${IC_LINT} ${FG_TEXT}golangci-lint"
    [[ -n "$golangci_version" ]] && lint_seg+=" ${FG_ACCENT}v${golangci_version}"
    add_seg "$lint_seg"
  fi
  # ORM second
  if $has_gorm; then
    gorm_seg="${FG_ACCENT}${IC_DB} ${FG_TEXT}GORM"
    [[ -n "$gorm_version" ]] && gorm_seg+=" ${FG_ACCENT}v${gorm_version}"
    add_seg "$gorm_seg"
  fi

  (( ${#_sc[@]} == 0 )) && exit 0
  flush "$_bar_gradient"
)
if [[ "$_bl_ttl" -gt 0 ]]; then
  bl_cache_write "$_bl_cache" "$_bl_out"
fi
printf '%s' "$_bl_out"
