#!/usr/bin/env bash
# Bottomline bar: Java ecosystem bar
# Renders for projects with pom.xml, build.gradle, or build.gradle.kts.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

has_maven=false has_gradle=false
[[ -f "$PROJ/pom.xml" ]]             && has_maven=true
[[ -f "$PROJ/build.gradle" ]]        && has_gradle=true
[[ -f "$PROJ/build.gradle.kts" ]]    && has_gradle=true
$has_maven || $has_gradle || exit 0

source "$BOTTOMLINE_LIB/helpers.sh"

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#f5e4c0")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#ed8b00")")
  _bar_gradient='["#1c1000","#2e1e00"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_JAVA=$'\xee\x9c\xb8'      # U+E738  nf-dev-java
    IC_MAVEN=$'\xee\x9c\xb8'     # U+E738  nf-dev-java  (no dedicated Maven glyph)
    IC_GRADLE=$'\xef\x80\x93'    # U+F013  nf-fa-cog
    IC_SPRING=$'\xef\x81\xac'    # U+F06C  nf-fa-leaf  (Spring's leaf logo)
    IC_QUARKUS=$'\xef\x84\xb5'   # U+F135  nf-fa-rocket
    IC_MICRONAUT=$'\xef\x83\xa7' # U+F0E7  nf-fa-bolt
    ;;
  emoji)
    IC_JAVA='☕'
    IC_MAVEN='📦'
    IC_GRADLE='🐘'
    IC_SPRING='🌱'
    IC_QUARKUS='🚀'
    IC_MICRONAUT='⚡'
    ;;
  *)
    IC_JAVA='' IC_MAVEN='' IC_GRADLE='' IC_SPRING='' IC_QUARKUS='' IC_MICRONAUT=''
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

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
