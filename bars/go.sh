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
for fw in gin echo fiber chi; do
  case "$fw" in
    gin)   pat='github.com/gin-gonic/gin'   ;;
    echo)  pat='github.com/labstack/echo'   ;;
    fiber) pat='github.com/gofiber/fiber'   ;;
    chi)   pat='github.com/go-chi/chi'      ;;
  esac
  if grep -q "$pat" "$PROJ/go.mod" 2>/dev/null; then
    framework="$fw"; break
  fi
done

has_ginkgo=false
has_testify=false
grep -q 'github.com/onsi/ginkgo' "$PROJ/go.mod" 2>/dev/null && has_ginkgo=true
grep -q 'github.com/stretchr/testify' "$PROJ/go.mod" 2>/dev/null && has_testify=true
# Layering: Ginkgo suppresses testify
$has_ginkgo && has_testify=false

has_gorm=false
grep -q 'gorm.io/gorm' "$PROJ/go.mod" 2>/dev/null && has_gorm=true

has_golangci=false
if command -v golangci-lint > /dev/null 2>&1; then
  has_golangci=true
elif [[ -f "$PROJ/.golangci.yml" || -f "$PROJ/.golangci.yaml" || -f "$PROJ/.golangci.toml" ]]; then
  has_golangci=true
fi

# ── Segments (canonical slot order) ───────────────────────────────────────────
# Slot 1: Runtime
go_seg="${FG_ACCENT}${IC_GO} ${FG_TEXT}Go"
[[ -n "$go_version" ]] && go_seg+=" ${FG_ACCENT}v${go_version}"
$is_workspace && go_seg+=" ${FG_ACCENT}${IC_WORKSPACE}${FG_TEXT} workspace"
add_seg "$go_seg"

# Slot 3: Framework
[[ -n "$framework" ]] \
  && add_seg "${FG_ACCENT}${IC_WEB} ${FG_TEXT}${framework}"

# Slot 5: Testing
$has_ginkgo \
  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}Ginkgo"
$has_testify \
  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}testify"

# Slot 6: Tooling
$has_gorm \
  && add_seg "${FG_ACCENT}${IC_DB} ${FG_TEXT}gorm"
$has_golangci \
  && add_seg "${FG_ACCENT}${IC_LINT} ${FG_TEXT}golangci-lint"

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
