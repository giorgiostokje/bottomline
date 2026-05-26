#!/usr/bin/env bash
# Bottomline bar: Kotlin ecosystem bar
# Only renders when the project contains a build.gradle.kts with Kotlin plugin.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init kotlin "#e8dff5" "#7f52ff" '["#1a0a3d","#2d1b6e"]' \
  "$PROJ/build.gradle.kts" "$PROJ/gradle/wrapper/gradle-wrapper.properties"

# Hard guard: AFTER cache block
[[ ! -f "$PROJ/build.gradle.kts" ]] && exit 0
# Secondary guard: must actually use the Kotlin plugin (not just Kotlin DSL for a Java project)
grep -qE 'kotlin\(|org\.jetbrains\.kotlin' "$PROJ/build.gradle.kts" 2>/dev/null || exit 0

bl_icon_set IC_KOTLIN  $'\xee\x9c\xb2' '🎯'  # U+E732  nf-dev-kotlin
bl_icon_set IC_GRADLE  $'\xef\x80\x93' '🐘'  # U+F013  nf-fa-cog
bl_icon_set IC_TEST    $'\xef\x81\x80' '🧪'  # U+F040  nf-fa-pencil
bl_icon_set IC_LINT    $'\xef\x80\x8c' '✓'   # U+F00C  nf-fa-check
bl_icon_set IC_WEB     $'\xef\x83\xac' '🌐'  # U+F0EC  nf-fa-exchange
bl_icon_set IC_DI      $'\xef\x83\xac' '💉'  # U+F0EC  nf-fa-exchange (DI)
bl_icon_set IC_FP      $'\xef\x84\xa1' 'λ'   # U+F121  nf-fa-code (FP)
bl_icon_set IC_DB      $'\xef\x87\x80' '🗄'   # U+F1C0  nf-fa-database
bl_icon_set IC_SERIAL  $'\xef\x83\xa2' '⟨⟩'  # U+F0E2  nf-fa-code (serialization)

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

# ── Slot 4: Add-ons ───────────────────────────────────────────────────────────
has_koin=false has_arrow=false

{ grep -q 'io\.insert-koin:koin' "$PROJ/build.gradle.kts" 2>/dev/null \
  || grep -q 'io\.insert-koin:koin' "$PROJ/build.gradle" 2>/dev/null; } \
  && has_koin=true

{ grep -q 'io\.arrow-kt:arrow-core' "$PROJ/build.gradle.kts" 2>/dev/null \
  || grep -q 'io\.arrow-kt:arrow-core' "$PROJ/build.gradle" 2>/dev/null; } \
  && has_arrow=true

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

has_exposed=false has_serial=false

{ grep -q 'org\.jetbrains\.exposed:exposed' "$PROJ/build.gradle.kts" 2>/dev/null \
  || grep -q 'org\.jetbrains\.exposed:exposed' "$PROJ/build.gradle" 2>/dev/null; } \
  && has_exposed=true

{ grep -q 'kotlinx-serialization' "$PROJ/build.gradle.kts" 2>/dev/null \
  || grep -q 'plugin\.serialization' "$PROJ/build.gradle.kts" 2>/dev/null \
  || grep -q 'kotlinx-serialization' "$PROJ/build.gradle" 2>/dev/null \
  || grep -q 'plugin\.serialization' "$PROJ/build.gradle" 2>/dev/null; } \
  && has_serial=true

# ── Slot 1: Runtime ───────────────────────────────────────────────────────────
bl_version_seg "$IC_KOTLIN" Kotlin "$kotlin_version"

# ── Slot 2: Build tool ────────────────────────────────────────────────────────
bl_version_seg "$IC_GRADLE" Gradle "$gradle_version"

# ── Slot 3: Framework ─────────────────────────────────────────────────────────
$has_ktor  && bl_version_seg "$IC_WEB" Ktor "$ktor_version"
$has_spring && bl_version_seg "$IC_WEB" "Spring Boot" "$spring_version"

# ── Slot 4: Add-ons ───────────────────────────────────────────────────────────
$has_koin  && bl_version_seg "$IC_DI" Koin
$has_arrow && bl_version_seg "$IC_FP" Arrow

# ── Slot 5: Testing ───────────────────────────────────────────────────────────
$has_kotest && bl_version_seg "$IC_TEST" Kotest "$kotest_version"
$has_junit5 && bl_version_seg "$IC_TEST" "JUnit 5" "$junit5_version"
$has_mockk  && bl_version_seg "$IC_TEST" MockK "$mockk_version"

# ── Slot 6: Tooling (static analysis → ORM → serialization) ───────────────────
$has_detekt && bl_version_seg "$IC_LINT" Detekt "$detekt_version"
$has_ktlint && bl_version_seg "$IC_LINT" ktlint "$ktlint_version"
$has_exposed && bl_version_seg "$IC_DB" Exposed
$has_serial && bl_version_seg "$IC_SERIAL" kotlinx-serialization

bl_bar_finish "$_bar_gradient"
