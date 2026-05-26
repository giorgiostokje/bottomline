#!/usr/bin/env bash
# Bottomline bar: Go ecosystem bar
# Only renders when the project contains a go.mod.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init go "#c8e8f4" "#29bcd8" '["#031824","#054860"]' \
  "$PROJ/go.mod" "$PROJ/go.work"

[[ ! -f "$PROJ/go.mod" ]] && exit 0

bl_icon_set IC_GO        $'\xee\x9c\xa4' '🐹'  # U+E724  nf-seti-go_lang
bl_icon_set IC_WORKSPACE $'\xef\x81\xae' '🗂'  # U+F06E  nf-fa-eye
bl_icon_set IC_WEB       $'\xef\x83\xac' '🌐'  # U+F0EC  nf-fa-exchange
bl_icon_set IC_TEST      $'\xef\x81\x80' '🧪'  # U+F040  nf-fa-pencil
bl_icon_set IC_DB        $'\xef\x87\x80' '🗄'  # U+F1C0  nf-fa-database
bl_icon_set IC_LINT      $'\xef\x80\x8c' '✓'   # U+F00C  nf-fa-check
bl_icon_set IC_CLI       $'\xef\x84\xa1' '⌨'   # U+F121  nf-fa-keyboard
bl_icon_set IC_PROTO     $'\xef\x80\xa2' '📡'   # U+F022  nf-fa-signal


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

has_cobra=false
cobra_version=''
grep -q 'github.com/spf13/cobra' "$PROJ/go.mod" 2>/dev/null && has_cobra=true \
  && cobra_version=$(grep 'github.com/spf13/cobra' "$PROJ/go.mod" 2>/dev/null \
     | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | sed 's/^v//')

has_gorm=false
gorm_version=''
grep -q 'gorm.io/gorm' "$PROJ/go.mod" 2>/dev/null && has_gorm=true \
  && gorm_version=$(grep 'gorm.io/gorm' "$PROJ/go.mod" 2>/dev/null \
     | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | sed 's/^v//')

has_ent=false
ent_version=''
grep -q 'entgo.io/ent' "$PROJ/go.mod" 2>/dev/null && has_ent=true \
  && ent_version=$(grep 'entgo.io/ent' "$PROJ/go.mod" 2>/dev/null \
     | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | sed 's/^v//')

has_sqlc=false
sqlc_version=''
if [[ -f "$PROJ/sqlc.yaml" || -f "$PROJ/sqlc.yml" ]]; then
  has_sqlc=true
elif grep -q 'github.com/sqlc-dev/sqlc' "$PROJ/go.mod" 2>/dev/null; then
  has_sqlc=true
  sqlc_version=$(grep 'github.com/sqlc-dev/sqlc' "$PROJ/go.mod" 2>/dev/null \
    | grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 | sed 's/^v//')
fi

has_buf=false
[[ -f "$PROJ/buf.yaml" || -f "$PROJ/buf.gen.yaml" ]] && has_buf=true

has_golangci=false
golangci_version=''
if command -v golangci-lint > /dev/null 2>&1; then
  has_golangci=true
  _golangci_raw=$(golangci-lint --version 2>/dev/null)
  _golangci_exit=$?
  (( _golangci_exit != 0 )) && bl_log debug go "golangci-lint --version exit=${_golangci_exit}"
  golangci_version=$(printf '%s' "$_golangci_raw" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
elif [[ -f "$PROJ/.golangci.yml" || -f "$PROJ/.golangci.yaml" || -f "$PROJ/.golangci.toml" ]]; then
  has_golangci=true
fi

  # ── Segments (canonical slot order) ───────────────────────────────────────────
  # Slot 1: Runtime
  go_seg="${FG_ACCENT}${IC_GO} ${FG_TEXT}Go"
  [[ -n "$go_version" ]] && go_seg+=" ${N}${FG_ACCENT}v${go_version}"
  $is_workspace && go_seg+=" ${FG_ACCENT}${IC_WORKSPACE}${FG_TEXT} workspace"
  add_seg "$go_seg"

  # Slot 3: Framework
  [[ -n "$framework" ]] && bl_seg "$IC_WEB" "$framework_display" "$framework_version"
  $has_cobra && bl_seg "$IC_CLI" Cobra "$cobra_version"

  # Slot 5: Testing
  $has_ginkgo  && bl_version_seg "$IC_TEST" Ginkgo  "$ginkgo_version"
  $has_testify && bl_version_seg "$IC_TEST" testify "$testify_version"

  # Slot 6: Tooling
  # static analysis first
  $has_golangci && bl_seg "$IC_LINT" golangci-lint "$golangci_version"
  # ORM second
  $has_gorm && bl_version_seg "$IC_DB" GORM "$gorm_version"
  $has_ent && bl_version_seg "$IC_DB" ent "$ent_version"
  $has_sqlc && bl_version_seg "$IC_DB" sqlc "$sqlc_version"
  $has_buf && bl_seg "$IC_PROTO" buf

bl_bar_finish "$_bar_gradient"
