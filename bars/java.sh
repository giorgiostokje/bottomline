#!/usr/bin/env bash
# Bottomline bar: Java ecosystem bar
# Renders for projects with pom.xml, build.gradle, or build.gradle.kts.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init java "#f5e4c0" "#ed8b00" '["#1c1000","#2e1e00"]' "$PROJ/pom.xml" "$PROJ/build.gradle" "$PROJ/build.gradle.kts"

has_maven=false has_gradle=false
[[ -f "$PROJ/pom.xml" ]]             && has_maven=true
[[ -f "$PROJ/build.gradle" ]]        && has_gradle=true
[[ -f "$PROJ/build.gradle.kts" ]]    && has_gradle=true
$has_maven || $has_gradle || exit 0

# Extracts version from pom.xml for the named artifactId.
_pom_dep_version() {
  local artifact="$1" pom="$2"
  awk -v a="$artifact" '
    /<artifactId>/ {
      v=$0; gsub(/.*<artifactId>|<\/artifactId>.*/,"",v)
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); found=(v==a)
    }
    found && /<version>/ {
      v=$0; gsub(/.*<version>|<\/version>.*/,"",v)
      gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); print v; exit
    }
  ' "$pom" 2>/dev/null
}

# Extracts version from a Gradle build file for a substring pattern.
_gradle_dep_version() {
  local pattern="$1" gradle="$2"
  grep -Ei "$pattern" "$gradle" 2>/dev/null \
    | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

bl_icon_set IC_MAVEN     $'\xee\x9c\xb8' '📦'  # U+E738  nf-dev-java
bl_icon_set IC_GRADLE    $'\xef\x80\x93' '🐘'  # U+F013  nf-fa-cog
bl_icon_set IC_SPRING    $'\xef\x81\xac' '🌱'  # U+F06C  nf-fa-leaf  (Spring's leaf logo)
bl_icon_set IC_QUARKUS   $'\xef\x84\xb5' '🚀'  # U+F135  nf-fa-rocket
bl_icon_set IC_MICRONAUT $'\xef\x83\xa7' '⚡'  # U+F0E7  nf-fa-bolt
bl_icon_set IC_TEST      $'\xef\x81\x80' '🧪'  # U+F040  nf-fa-pencil
bl_icon_set IC_GEAR      $'\xef\x82\x85' '⚙'   # U+F085  nf-fa-cogs (codegen)
bl_icon_set IC_LINT      $'\xef\x80\x8c' '✓'   # U+F00C  nf-fa-check
bl_icon_set IC_BUG       $'\xef\x86\x88' '🐞'  # U+F188  nf-fa-bug


# ── Detect framework and version ──────────────────────────────────────────────
has_spring=false has_quarkus=false has_micronaut=false
spring_version='' quarkus_version='' micronaut_version=''
java_version=''

if $has_maven; then
  _pom="$PROJ/pom.xml"
  java_version=$(grep -m1 '<java\.version>' "$_pom" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)*')
  [[ -z "$java_version" ]] && \
    java_version=$(grep -m1 'maven\.compiler\.source' "$_pom" 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)*')

  if grep -q 'spring-boot' "$_pom" 2>/dev/null; then
    has_spring=true
    spring_version=$(grep -A3 'spring-boot-starter-parent\|spring-boot-dependencies' "$_pom" 2>/dev/null \
      | grep -m1 '<version>' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  fi
  grep -q 'quarkus' "$_pom" 2>/dev/null && has_quarkus=true \
    && quarkus_version=$(grep -m1 'quarkus.*version\|quarkus-bom' "$_pom" 2>/dev/null \
      | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  grep -q 'micronaut' "$_pom" 2>/dev/null && has_micronaut=true \
    && micronaut_version=$(grep -m1 'micronaut.*version\|micronaut-bom' "$_pom" 2>/dev/null \
      | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
fi

if $has_gradle; then
  _gradle_file="$PROJ/build.gradle"
  [[ -f "$PROJ/build.gradle.kts" ]] && _gradle_file="$PROJ/build.gradle.kts"

  if grep -q 'spring-boot\|org\.springframework' "$_gradle_file" 2>/dev/null; then
    has_spring=true
    spring_version=$(grep -m1 'springBootVersion\|spring-boot.*version\|id.*spring-boot' "$_gradle_file" 2>/dev/null \
      | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  fi
  grep -q 'quarkus' "$_gradle_file" 2>/dev/null && has_quarkus=true \
    && quarkus_version=$(grep -m1 'quarkusPlatformVersion\|quarkus.*version' "$_gradle_file" 2>/dev/null \
      | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  grep -q 'micronaut' "$_gradle_file" 2>/dev/null && has_micronaut=true \
    && micronaut_version=$(grep -m1 'micronautVersion\|micronaut.*version' "$_gradle_file" 2>/dev/null \
      | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
fi

# ── Detect ecosystem from pom.xml or build.gradle ─────────────────────────────
_build_files=()
$has_maven && _build_files+=("$PROJ/pom.xml")
$has_gradle && _build_files+=("$PROJ/build.gradle")
[[ -f "$PROJ/build.gradle.kts" ]] && _build_files+=("$PROJ/build.gradle.kts")

has_junit5=false
has_junit4=false
has_testng=false
has_lombok=false
has_checkstyle=false
has_spotbugs=false
has_pmd=false

for _bf in "${_build_files[@]}"; do
  grep -q 'junit-jupiter' "$_bf" 2>/dev/null && has_junit5=true
  grep -Eq '<artifactId>junit</artifactId>|"junit:junit:' "$_bf" 2>/dev/null && has_junit4=true
  grep -Eq '<artifactId>testng</artifactId>|"org.testng:testng' "$_bf" 2>/dev/null && has_testng=true
  grep -Eq 'projectlombok|"org.projectlombok:lombok' "$_bf" 2>/dev/null && has_lombok=true
  grep -q 'checkstyle' "$_bf" 2>/dev/null && has_checkstyle=true
  grep -q 'spotbugs' "$_bf" 2>/dev/null && has_spotbugs=true
  grep -Eq 'maven-pmd-plugin|"net.sourceforge.pmd' "$_bf" 2>/dev/null && has_pmd=true
done
unset _bf _build_files

# Layering: JUnit 5 suppresses JUnit 4
$has_junit5 && has_junit4=false

# Extract versions for Lombok, Checkstyle, SpotBugs, PMD
lombok_version='' checkstyle_version='' spotbugs_version='' pmd_version=''
if $has_maven && [[ -f "$PROJ/pom.xml" ]]; then
  _pom="$PROJ/pom.xml"
  $has_lombok     && lombok_version=$(_pom_dep_version "lombok" "$_pom")
  $has_checkstyle && checkstyle_version=$(_pom_dep_version "maven-checkstyle-plugin" "$_pom")
  $has_spotbugs   && spotbugs_version=$(_pom_dep_version "spotbugs-maven-plugin" "$_pom")
  $has_pmd        && pmd_version=$(_pom_dep_version "maven-pmd-plugin" "$_pom")
fi
if $has_gradle; then
  _gf="$PROJ/build.gradle"; [[ -f "$PROJ/build.gradle.kts" ]] && _gf="$PROJ/build.gradle.kts"
  [[ -z "$lombok_version" ]]     && $has_lombok     && lombok_version=$(_gradle_dep_version "projectlombok:lombok:" "$_gf")
  [[ -z "$checkstyle_version" ]] && $has_checkstyle && checkstyle_version=$(_gradle_dep_version "checkstyle" "$_gf")
  [[ -z "$spotbugs_version" ]]   && $has_spotbugs   && spotbugs_version=$(_gradle_dep_version "spotbugs" "$_gf")
  [[ -z "$pmd_version" ]]        && $has_pmd        && pmd_version=$(_gradle_dep_version "pmd" "$_gf")
fi

# ── Build tool ────────────────────────────────────────────────────────────────
if $has_maven; then
  java_seg="${FG_ACCENT}${IC_MAVEN} ${FG_TEXT}Maven"
  [[ -n "$java_version" ]] && java_seg+=" ${FG_ACCENT}(Java ${java_version})"
  add_seg "$java_seg"
elif $has_gradle; then
  java_seg="${FG_ACCENT}${IC_GRADLE} ${FG_TEXT}Gradle"
  [[ -n "$java_version" ]] && java_seg+=" ${FG_ACCENT}(Java ${java_version})"
  add_seg "$java_seg"
fi

# ── Framework ─────────────────────────────────────────────────────────────────
$has_spring && bl_version_seg "$IC_SPRING" "Spring Boot" "$spring_version"
$has_quarkus && bl_version_seg "$IC_QUARKUS" "Quarkus" "$quarkus_version"
$has_micronaut && bl_version_seg "$IC_MICRONAUT" "Micronaut" "$micronaut_version"

# Slot 5: Testing
$has_junit5 && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}JUnit 5"
$has_junit4 && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}JUnit 4"
$has_testng && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}TestNG"

# Slot 6: Tooling
$has_checkstyle && bl_version_seg "$IC_LINT" Checkstyle "$checkstyle_version"
$has_spotbugs && bl_version_seg "$IC_BUG" SpotBugs "$spotbugs_version"
$has_pmd && bl_version_seg "$IC_LINT" PMD "$pmd_version"
$has_lombok && bl_version_seg "$IC_GEAR" Lombok "$lombok_version"

bl_bar_finish "$_bar_gradient"
