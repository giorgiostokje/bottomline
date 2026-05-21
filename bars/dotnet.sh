#!/usr/bin/env bash
# Bottomline bar: .NET ecosystem bar
# Renders for projects with *.csproj, *.sln, global.json, or Directory.Build.props.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

shopt -s nullglob
_csproj=("$PROJ"/*.csproj)
_sln=("$PROJ"/*.sln)
shopt -u nullglob
[[ ${#_csproj[@]} -eq 0 && ${#_sln[@]} -eq 0 \
  && ! -f "$PROJ/global.json" \
  && ! -f "$PROJ/Directory.Build.props" \
  && ! -f "$PROJ/Directory.Build.targets" ]] && exit 0

source "$BOTTOMLINE_LIB/helpers.sh"

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
  nerd)  IC_DOTNET=$'\xee\x9d\xbf' ;;  # U+E77F  nf-dev-dotnet
  emoji) IC_DOTNET='🔷'             ;;
  *)     IC_DOTNET=''               ;;
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

# ── Segments ──────────────────────────────────────────────────────────────────
dotnet_seg="${FG_ACCENT}${IC_DOTNET} ${FG_TEXT}.NET"
[[ -n "$sdk_version" ]] && dotnet_seg+=" ${FG_ACCENT}v${sdk_version}"
add_seg "$dotnet_seg"

[[ -n "$target_framework" ]] && add_seg "${FG_TEXT}${target_framework}"

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
