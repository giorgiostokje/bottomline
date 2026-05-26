#!/usr/bin/env bash
# Bottomline bar: .NET ecosystem bar
# Renders for projects with *.csproj, *.sln, global.json, or Directory.Build.props.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init dotnet "#e8d9f5" "#512BD4" '["#1a0640","#2d0e6e"]' "$PROJ/global.json" "$PROJ/Directory.Build.props" "$PROJ/Directory.Build.targets"

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

# ── Icons ─────────────────────────────────────────────────────────────────────
bl_icon_set IC_DOTNET  $'\xee\x9d\xbf' '🔷'  # U+E77F  nf-dev-dotnet
bl_icon_set IC_WEB     $'\xef\x83\xac' '🌐'  # U+F0EC  nf-fa-exchange
bl_icon_set IC_TEST    $'\xef\x81\x80' '🧪'  # U+F040  nf-fa-pencil
bl_icon_set IC_DB      $'\xef\x87\x80' '🗄'  # U+F1C0  nf-fa-database
bl_icon_set IC_LINT    $'\xef\x80\x8c' '✓'   # U+F00C  nf-fa-check
bl_icon_set IC_PROTO   $'\xef\x80\xa2' '📡'  # U+F022  nf-fa-signal
bl_icon_set IC_VALID   $'\xef\x80\x8c' '✓'   # U+F00C  nf-fa-check
bl_icon_set IC_PATTERN $'\xef\x83\xa2' '⟳'   # U+F0E2  nf-fa-refresh
bl_icon_set IC_LOG     $'\xef\x81\xab' '📋'  # U+F06B  nf-fa-tag

# ── SDK version ───────────────────────────────────────────────────────────────
sdk_version=''
if [[ -f "$PROJ/global.json" ]]; then
  sdk_version=$(jq -r '.sdk.version // empty' "$PROJ/global.json" 2>/dev/null)
fi
if [[ -z "$sdk_version" ]] && command -v dotnet &>/dev/null; then
  _dotnet_raw=$(dotnet --version 2>/dev/null)
  _dotnet_exit=$?
  (( _dotnet_exit != 0 )) && bl_log debug dotnet "dotnet --version exit=${_dotnet_exit}"
  sdk_version=$(printf '%s' "$_dotnet_raw" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
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
has_grpc=false
has_signalr=false
has_ef=false
has_dapper=false
has_stylecop=false
has_sonar=false
has_fv=false
has_mediatr=false
has_serilog=false

if [[ -n "$csproj" ]]; then
  grep -q 'Microsoft.AspNetCore.Components' "$csproj" 2>/dev/null && framework='Blazor'
  [[ -z "$framework" ]] && grep -q 'Microsoft.AspNetCore' "$csproj" 2>/dev/null && framework='ASP.NET Core'
  [[ -z "$framework" ]] && grep -q 'Microsoft.Maui' "$csproj" 2>/dev/null && framework='MAUI'

  grep -q '"xunit"' "$csproj" 2>/dev/null     && has_xunit=true
  grep -q '"NUnit"' "$csproj" 2>/dev/null     && has_nunit=true
  grep -q '"MSTest' "$csproj" 2>/dev/null     && has_mstest=true
  grep -q 'Grpc.AspNetCore' "$csproj" 2>/dev/null              && has_grpc=true
  grep -qE 'Microsoft\.AspNetCore\.SignalR(\.Client)?' "$csproj" 2>/dev/null && has_signalr=true
  grep -q 'Microsoft.EntityFrameworkCore' "$csproj" 2>/dev/null && has_ef=true
  grep -q '"Dapper"' "$csproj" 2>/dev/null                     && has_dapper=true
  grep -q 'StyleCop.Analyzers' "$csproj" 2>/dev/null            && has_stylecop=true
  grep -q 'SonarAnalyzer.CSharp' "$csproj" 2>/dev/null          && has_sonar=true
  grep -qE '"FluentValidation(\.AspNetCore)?"' "$csproj" 2>/dev/null && has_fv=true
  grep -q '"MediatR"' "$csproj" 2>/dev/null                     && has_mediatr=true
  grep -q '"Serilog"' "$csproj" 2>/dev/null                     && has_serilog=true
fi

# Extract versions for EF Core, StyleCop, SonarAnalyzer
ef_version='' stylecop_version='' sonar_version=''
if [[ -n "$csproj" ]]; then
  $has_ef       && ef_version=$(_csproj_pkg_version "EntityFrameworkCore" "$csproj")
  $has_stylecop && stylecop_version=$(_csproj_pkg_version "StyleCop" "$csproj")
  $has_sonar    && sonar_version=$(_csproj_pkg_version "SonarAnalyzer" "$csproj")
fi

# ── Segments ──────────────────────────────────────────────────────────────────
bl_version_seg "$IC_DOTNET" .NET "$sdk_version"

[[ -n "$target_framework" ]] && bl_seg "" "$target_framework"

# Slot 3: Framework
[[ -n "$framework" ]] && bl_seg "$IC_WEB" "$framework"

# Slot 4: Add-ons
$has_grpc    && bl_seg "$IC_PROTO" gRPC
$has_signalr && bl_seg "$IC_WEB" SignalR

# Slot 5: Testing
$has_xunit  && bl_seg "$IC_TEST" xUnit
$has_nunit  && bl_seg "$IC_TEST" NUnit
$has_mstest && bl_seg "$IC_TEST" MSTest

# Slot 6: Tooling
$has_stylecop && bl_version_seg "$IC_LINT" StyleCop "$stylecop_version"
$has_sonar    && bl_version_seg "$IC_LINT" SonarAnalyzer "$sonar_version"
$has_fv       && bl_seg "$IC_VALID" FluentValidation
$has_mediatr  && bl_seg "$IC_PATTERN" MediatR
$has_ef       && bl_version_seg "$IC_DB" "EF Core" "$ef_version"
$has_dapper   && bl_seg "$IC_DB" Dapper
$has_serilog  && bl_seg "$IC_LOG" Serilog

bl_bar_finish "$_bar_gradient"
