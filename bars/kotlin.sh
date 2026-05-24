#!/usr/bin/env bash
# Bottomline bar: Kotlin ecosystem bar
# Only renders when the project contains a build.gradle.kts with Kotlin plugin.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
if [[ "$_bl_ttl" -gt 0 ]]; then
  _bl_cache=$(bl_cache_path "kotlin" "$_bl_ttl" "$PROJ" \
    "$PROJ/build.gradle.kts" "$PROJ/gradle/wrapper/gradle-wrapper.properties")
  [[ -f "$_bl_cache" ]] && cat "$_bl_cache" && exit 0
fi

# Hard guard: AFTER cache block
[[ ! -f "$PROJ/build.gradle.kts" ]] && exit 0
# Secondary guard: must actually use the Kotlin plugin (not just Kotlin DSL for a Java project)
grep -qE 'kotlin\(|org\.jetbrains\.kotlin' "$PROJ/build.gradle.kts" 2>/dev/null || exit 0

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#e8dff5")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#7f52ff")")
  _bar_gradient='["#1a0a3d","#2d1b6e"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_KOTLIN=$'\xee\x9c\xb2'   # U+E732  nf-dev-kotlin
    IC_GRADLE=$'\xef\x80\x93'   # U+F013  nf-fa-cog
    IC_TEST=$'\xef\x81\x80'     # U+F040  nf-fa-pencil
    IC_LINT=$'\xef\x80\x8c'     # U+F00C  nf-fa-check
    IC_WEB=$'\xef\x83\xac'      # U+F0EC  nf-fa-exchange
    ;;
  emoji)
    IC_KOTLIN='🎯'
    IC_GRADLE='🐘'
    IC_TEST='🧪'
    IC_LINT='✓'
    IC_WEB='🌐'
    ;;
  *)
    IC_KOTLIN='' IC_GRADLE='' IC_TEST='' IC_LINT='' IC_WEB=''
    ;;
esac

# ── Slot 1: Kotlin version ────────────────────────────────────────────────────
kotlin_version=$(grep -m1 -oE 'kotlin\([^)]*\)\s+version\s+"[0-9][0-9.]*"' "$PROJ/build.gradle.kts" 2>/dev/null \
  | grep -oE '"[0-9][0-9.]*"' | tr -d '"')
if [[ -z "$kotlin_version" ]]; then
  kotlin_version=$(grep -m1 -oE 'id\("org\.jetbrains\.kotlin\.[^"]*"\)\s+version\s+"[0-9][0-9.]*"' "$PROJ/build.gradle.kts" 2>/dev/null \
    | grep -oE '"[0-9][0-9.]*"' | head -1 | tr -d '"')
fi
if [[ -z "$kotlin_version" ]]; then
  kotlin_version=$(grep -m1 -E 'kotlin_version\s*=\s*"[0-9]|ext\["kotlinVersion"\]\s*=' "$PROJ/build.gradle.kts" 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
fi

# ── Slot 2: Gradle wrapper version ───────────────────────────────────────────
gradle_version=$(grep 'distributionUrl' "$PROJ/gradle/wrapper/gradle-wrapper.properties" 2>/dev/null \
  | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)

# ── Slot 3: Framework ─────────────────────────────────────────────────────────
has_ktor=false has_spring=false
ktor_version='' spring_version=''

grep -q 'io\.ktor' "$PROJ/build.gradle.kts" 2>/dev/null && has_ktor=true \
  && ktor_version=$(grep -m1 'io\.ktor' "$PROJ/build.gradle.kts" 2>/dev/null \
       | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

grep -q 'org\.springframework\.boot' "$PROJ/build.gradle.kts" 2>/dev/null && has_spring=true \
  && spring_version=$(grep -m1 'spring.boot.*version\|springBootVersion\|org\.springframework\.boot' "$PROJ/build.gradle.kts" 2>/dev/null \
       | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

# Ktor takes priority if both present
$has_ktor && has_spring=false

# ── Slot 5: Testing ───────────────────────────────────────────────────────────
has_kotest=false has_junit5=false has_mockk=false
kotest_version='' junit5_version='' mockk_version=''

grep -q 'io\.kotest' "$PROJ/build.gradle.kts" 2>/dev/null && has_kotest=true \
  && kotest_version=$(grep -m1 'io\.kotest' "$PROJ/build.gradle.kts" 2>/dev/null \
       | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

grep -qE 'junit-jupiter|junit5|org\.junit\.jupiter' "$PROJ/build.gradle.kts" 2>/dev/null && has_junit5=true \
  && junit5_version=$(grep -m1 -E 'junit-jupiter|org\.junit\.jupiter' "$PROJ/build.gradle.kts" 2>/dev/null \
       | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

grep -q 'io\.mockk' "$PROJ/build.gradle.kts" 2>/dev/null && has_mockk=true \
  && mockk_version=$(grep -m1 'io\.mockk' "$PROJ/build.gradle.kts" 2>/dev/null \
       | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

# Layering: Kotest suppresses JUnit5
$has_kotest && has_junit5=false

# ── Slot 6: Tooling ───────────────────────────────────────────────────────────
has_detekt=false has_ktlint=false
detekt_version='' ktlint_version=''

if grep -qE 'io\.gitlab\.arturbosch\.detekt|detekt' "$PROJ/build.gradle.kts" 2>/dev/null \
     || [[ -f "$PROJ/.detekt.yml" || -f "$PROJ/detekt.yml" ]]; then
  has_detekt=true
  detekt_version=$(grep -m1 -E 'io\.gitlab\.arturbosch\.detekt|detekt' "$PROJ/build.gradle.kts" 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
fi

grep -qE 'ktlint|jlleitschuh\.gradle\.ktlint' "$PROJ/build.gradle.kts" 2>/dev/null && has_ktlint=true \
  && ktlint_version=$(grep -m1 -E 'ktlint|jlleitschuh\.gradle\.ktlint' "$PROJ/build.gradle.kts" 2>/dev/null \
       | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

_bl_out=$(
  # ── Slot 1: Runtime ───────────────────────────────────────────────────────────
  kotlin_seg="${FG_ACCENT}${IC_KOTLIN} ${FG_TEXT}Kotlin"
  [[ -n "$kotlin_version" ]] && kotlin_seg+=" ${FG_ACCENT}v${kotlin_version}"
  add_seg "$kotlin_seg"

  # ── Slot 2: Build tool ────────────────────────────────────────────────────────
  gradle_seg="${FG_ACCENT}${IC_GRADLE} ${FG_TEXT}Gradle"
  [[ -n "$gradle_version" ]] && gradle_seg+=" ${FG_ACCENT}v${gradle_version}"
  add_seg "$gradle_seg"

  # ── Slot 3: Framework ─────────────────────────────────────────────────────────
  if $has_ktor; then
    ktor_seg="${FG_ACCENT}${IC_WEB} ${FG_TEXT}Ktor"
    [[ -n "$ktor_version" ]] && ktor_seg+=" ${FG_ACCENT}v${ktor_version}"
    add_seg "$ktor_seg"
  elif $has_spring; then
    spring_seg="${FG_ACCENT}${IC_WEB} ${FG_TEXT}Spring Boot"
    [[ -n "$spring_version" ]] && spring_seg+=" ${FG_ACCENT}v${spring_version}"
    add_seg "$spring_seg"
  fi

  # ── Slot 5: Testing ───────────────────────────────────────────────────────────
  if $has_kotest; then
    kotest_seg="${FG_ACCENT}${IC_TEST} ${FG_TEXT}Kotest"
    [[ -n "$kotest_version" ]] && kotest_seg+=" ${FG_ACCENT}v${kotest_version}"
    add_seg "$kotest_seg"
  fi
  if $has_junit5; then
    junit5_seg="${FG_ACCENT}${IC_TEST} ${FG_TEXT}JUnit 5"
    [[ -n "$junit5_version" ]] && junit5_seg+=" ${FG_ACCENT}v${junit5_version}"
    add_seg "$junit5_seg"
  fi
  if $has_mockk; then
    mockk_seg="${FG_ACCENT}${IC_TEST} ${FG_TEXT}MockK"
    [[ -n "$mockk_version" ]] && mockk_seg+=" ${FG_ACCENT}v${mockk_version}"
    add_seg "$mockk_seg"
  fi

  # ── Slot 6: Tooling (static analysis first) ───────────────────────────────────
  if $has_detekt; then
    detekt_seg="${FG_ACCENT}${IC_LINT} ${FG_TEXT}Detekt"
    [[ -n "$detekt_version" ]] && detekt_seg+=" ${FG_ACCENT}v${detekt_version}"
    add_seg "$detekt_seg"
  fi
  if $has_ktlint; then
    ktlint_seg="${FG_ACCENT}${IC_LINT} ${FG_TEXT}ktlint"
    [[ -n "$ktlint_version" ]] && ktlint_seg+=" ${FG_ACCENT}v${ktlint_version}"
    add_seg "$ktlint_seg"
  fi

  (( ${#_sc[@]} == 0 )) && exit 0
  flush "$_bar_gradient"
)
if [[ "$_bl_ttl" -gt 0 ]]; then
  bl_cache_write "$_bl_cache" "$_bl_out"
fi
printf '%s' "$_bl_out"
