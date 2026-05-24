#!/usr/bin/env bash
# Bottomline bar: .NET ecosystem bar
# Renders for projects with *.csproj, *.sln, global.json, or Directory.Build.props.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
if [[ "$_bl_ttl" -gt 0 ]]; then
  _bl_cache=$(bl_cache_path "dotnet" "$_bl_ttl" "$PROJ" \
    "$PROJ/global.json" "$PROJ/Directory.Build.props" "$PROJ/Directory.Build.targets")
  [[ -f "$_bl_cache" ]] && cat "$_bl_cache" && exit 0
fi

shopt -s nullglob
_csproj=("$PROJ"/*.csproj)
_sln=("$PROJ"/*.sln)
shopt -u nullglob
[[ ${#_csproj[@]} -eq 0 && ${#_sln[@]} -eq 0 \
  && ! -f "$PROJ/global.json" \
  && ! -f "$PROJ/Directory.Build.props" \
  && ! -f "$PROJ/Directory.Build.targets" ]] && exit 0

# Extracts PackageReference version from .csproj by partial package name match.
_csproj_pkg_version() {
  local pkg="$1" csproj="$2"
  grep -i "$pkg" "$csproj" 2>/dev/null \
    | grep -oiE 'Version="[^"]*"' \
    | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+(-[^"]+)?)?' | head -1
}

# ── Palette (.NET brand purple) ───────────────────────────────────────────────
if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg   "$(hex_to_rgb "#e8d9f5")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#512BD4")")
  _bar_gradient='["#1a0640","#2d0e6e"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

# ── Icons ─────────────────────────────────────────────────────────────────────
case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_DOTNET=$'\xee\x9d\xbf'   # U+E77F  nf-dev-dotnet
    IC_WEB=$'\xef\x83\xac'      # U+F0EC  nf-fa-exchange
    IC_TEST=$'\xef\x81\x80'     # U+F040  nf-fa-pencil
    IC_DB=$'\xef\x87\x80'       # U+F1C0  nf-fa-database
    IC_LINT=$'\xef\x80\x8c'     # U+F00C  nf-fa-check
    ;;
  emoji)
    IC_DOTNET='🔷' IC_WEB='🌐' IC_TEST='🧪' IC_DB='🗄' IC_LINT='✓'
    ;;
  *)
    IC_DOTNET='' IC_WEB='' IC_TEST='' IC_DB='' IC_LINT=''
    ;;
esac

# ── SDK version ───────────────────────────────────────────────────────────────
sdk_version=''
if [[ -f "$PROJ/global.json" ]]; then
  sdk_version=$(jq -r '.sdk.version // empty' "$PROJ/global.json" 2>/dev/null)
fi
if [[ -z "$sdk_version" ]] && command -v dotnet &>/dev/null; then
  sdk_version=$(dotnet --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
fi

# ── Target framework from first .csproj ───────────────────────────────────────
target_framework=''
if [[ ${#_csproj[@]} -gt 0 ]]; then
  target_framework=$(grep -m1 '<TargetFramework>' "${_csproj[0]}" 2>/dev/null \
    | sed 's/.*<TargetFramework>\(.*\)<\/TargetFramework>.*/\1/' | tr -d '[:space:]')
fi

# ── Detect ecosystem from *.csproj ────────────────────────────────────────────
csproj=''
[[ ${#_csproj[@]} -gt 0 ]] && csproj="${_csproj[0]}"
framework=''
has_xunit=false
has_nunit=false
has_mstest=false
has_ef=false
has_stylecop=false
has_sonar=false

if [[ -n "$csproj" ]]; then
  grep -q 'Microsoft.AspNetCore.Components' "$csproj" 2>/dev/null && framework='Blazor'
  [[ -z "$framework" ]] && grep -q 'Microsoft.AspNetCore' "$csproj" 2>/dev/null && framework='ASP.NET Core'
  [[ -z "$framework" ]] && grep -q 'Microsoft.Maui' "$csproj" 2>/dev/null && framework='MAUI'

  grep -q '"xunit"' "$csproj" 2>/dev/null     && has_xunit=true
  grep -q '"NUnit"' "$csproj" 2>/dev/null     && has_nunit=true
  grep -q '"MSTest' "$csproj" 2>/dev/null     && has_mstest=true
  grep -q 'Microsoft.EntityFrameworkCore' "$csproj" 2>/dev/null && has_ef=true
  grep -q 'StyleCop.Analyzers' "$csproj" 2>/dev/null            && has_stylecop=true
  grep -q 'SonarAnalyzer.CSharp' "$csproj" 2>/dev/null          && has_sonar=true
fi

# Extract versions for EF Core, StyleCop, SonarAnalyzer
ef_version='' stylecop_version='' sonar_version=''
if [[ -n "$csproj" ]]; then
  $has_ef       && ef_version=$(_csproj_pkg_version "EntityFrameworkCore" "$csproj")
  $has_stylecop && stylecop_version=$(_csproj_pkg_version "StyleCop" "$csproj")
  $has_sonar    && sonar_version=$(_csproj_pkg_version "SonarAnalyzer" "$csproj")
fi

_bl_out=$(
  # ── Segments ──────────────────────────────────────────────────────────────────
  dotnet_seg="${FG_ACCENT}${IC_DOTNET} ${FG_TEXT}.NET"
  [[ -n "$sdk_version" ]] && dotnet_seg+=" ${FG_ACCENT}v${sdk_version}"
  add_seg "$dotnet_seg"

  [[ -n "$target_framework" ]] && add_seg "${FG_TEXT}${target_framework}"

  # Slot 3: Framework
  [[ -n "$framework" ]] \
    && add_seg "${FG_ACCENT}${IC_WEB} ${FG_TEXT}${framework}"

  # Slot 5: Testing
  $has_xunit  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}xUnit"
  $has_nunit  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}NUnit"
  $has_mstest && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}MSTest"

  # Slot 6: Tooling
  if $has_stylecop; then
    sc_seg="${FG_ACCENT}${IC_LINT} ${FG_TEXT}StyleCop"
    [[ -n "$stylecop_version" ]] && sc_seg+=" ${FG_ACCENT}v${stylecop_version}"
    add_seg "$sc_seg"
  fi
  if $has_sonar; then
    sn_seg="${FG_ACCENT}${IC_LINT} ${FG_TEXT}SonarAnalyzer"
    [[ -n "$sonar_version" ]] && sn_seg+=" ${FG_ACCENT}v${sonar_version}"
    add_seg "$sn_seg"
  fi
  if $has_ef; then
    ef_seg="${FG_ACCENT}${IC_DB} ${FG_TEXT}EF Core"
    [[ -n "$ef_version" ]] && ef_seg+=" ${FG_ACCENT}v${ef_version}"
    add_seg "$ef_seg"
  fi

  (( ${#_sc[@]} == 0 )) && exit 0
  flush "$_bar_gradient"
)
if [[ "$_bl_ttl" -gt 0 ]]; then
  bl_cache_write "$_bl_cache" "$_bl_out"
fi
printf '%s' "$_bl_out"
