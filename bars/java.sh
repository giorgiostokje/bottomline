#!/usr/bin/env bash
# Bottomline bar: Java ecosystem bar
# Renders for projects with pom.xml, build.gradle, or build.gradle.kts.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
if [[ "$_bl_ttl" -gt 0 ]]; then
  _bl_cache=$(bl_cache_path "java" "$_bl_ttl" "$PROJ")
  [[ -f "$_bl_cache" ]] && cat "$_bl_cache" && exit 0
fi

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

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#f5e4c0")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#ed8b00")")
  _bar_gradient='["#1c1000","#2e1e00"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_MAVEN=$'\xee\x9c\xb8'     # U+E738  nf-dev-java
    IC_GRADLE=$'\xef\x80\x93'    # U+F013  nf-fa-cog
    IC_SPRING=$'\xef\x81\xac'    # U+F06C  nf-fa-leaf  (Spring's leaf logo)
    IC_QUARKUS=$'\xef\x84\xb5'   # U+F135  nf-fa-rocket
    IC_MICRONAUT=$'\xef\x83\xa7' # U+F0E7  nf-fa-bolt
    IC_TEST=$'\xef\x81\x80'      # U+F040  nf-fa-pencil
    IC_GEAR=$'\xef\x82\x85'      # U+F085  nf-fa-cogs (codegen)
    IC_LINT=$'\xef\x80\x8c'      # U+F00C  nf-fa-check
    IC_BUG=$'\xef\x86\x88'       # U+F188  nf-fa-bug
    ;;
  emoji)
    IC_MAVEN='📦'
    IC_GRADLE='🐘'
    IC_SPRING='🌱'
    IC_QUARKUS='🚀'
    IC_MICRONAUT='⚡'
    IC_TEST='🧪' IC_GEAR='⚙' IC_LINT='✓' IC_BUG='🐞'
    ;;
  *)
    IC_MAVEN='' IC_GRADLE='' IC_SPRING='' IC_QUARKUS='' IC_MICRONAUT=''
    IC_TEST='' IC_GEAR='' IC_LINT='' IC_BUG=''
    ;;
esac


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


_bl_out=$(
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
  if $has_spring; then
    spring_seg="${FG_ACCENT}${IC_SPRING} ${FG_TEXT}Spring Boot"
    [[ -n "$spring_version" ]] && spring_seg+=" ${FG_ACCENT}v${spring_version}"
    add_seg "$spring_seg"
  elif $has_quarkus; then
    quarkus_seg="${FG_ACCENT}${IC_QUARKUS} ${FG_TEXT}Quarkus"
    [[ -n "$quarkus_version" ]] && quarkus_seg+=" ${FG_ACCENT}v${quarkus_version}"
    add_seg "$quarkus_seg"
  elif $has_micronaut; then
    micronaut_seg="${FG_ACCENT}${IC_MICRONAUT} ${FG_TEXT}Micronaut"
    [[ -n "$micronaut_version" ]] && micronaut_seg+=" ${FG_ACCENT}v${micronaut_version}"
    add_seg "$micronaut_seg"
  fi

  # Slot 5: Testing
  $has_junit5 && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}JUnit 5"
  $has_junit4 && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}JUnit 4"
  $has_testng && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}TestNG"

  # Slot 6: Tooling
  if $has_checkstyle; then
    cs_seg="${FG_ACCENT}${IC_LINT} ${FG_TEXT}Checkstyle"
    [[ -n "$checkstyle_version" ]] && cs_seg+=" ${FG_ACCENT}v${checkstyle_version}"
    add_seg "$cs_seg"
  fi
  if $has_spotbugs; then
    sb_seg="${FG_ACCENT}${IC_BUG} ${FG_TEXT}SpotBugs"
    [[ -n "$spotbugs_version" ]] && sb_seg+=" ${FG_ACCENT}v${spotbugs_version}"
    add_seg "$sb_seg"
  fi
  if $has_pmd; then
    pmd_seg="${FG_ACCENT}${IC_LINT} ${FG_TEXT}PMD"
    [[ -n "$pmd_version" ]] && pmd_seg+=" ${FG_ACCENT}v${pmd_version}"
    add_seg "$pmd_seg"
  fi
  if $has_lombok; then
    lk_seg="${FG_ACCENT}${IC_GEAR} ${FG_TEXT}Lombok"
    [[ -n "$lombok_version" ]] && lk_seg+=" ${FG_ACCENT}v${lombok_version}"
    add_seg "$lk_seg"
  fi

  (( ${#_sc[@]} == 0 )) && exit 0
  flush "$_bar_gradient"
)
if [[ "$_bl_ttl" -gt 0 ]]; then
  bl_cache_write "$_bl_cache" "$_bl_out"
fi
printf '%s' "$_bl_out"
