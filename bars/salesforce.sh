#!/usr/bin/env bash
# Bottomline bar: Salesforce ecosystem bar
# Renders when the project contains a sfdx-project.json.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" || ! -f "$PROJ/sfdx-project.json" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

# ── Palette (Salesforce Lightning brand colours) ───────────────────────────────
if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg   "$(hex_to_rgb "#c7e0f4")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#1B96FF")")
  _bar_gradient='["#032D60","#0B4B8B"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

# ── Icons ─────────────────────────────────────────────────────────────────────
case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_SF=$'\xef\x83\x82'   # U+F0C2  nf-fa-cloud
    IC_ORG=$'\xef\x86\xad'  # U+F1AD  nf-fa-building
    IC_USER=$'\xef\x80\x87' # U+F007  nf-fa-user
    IC_API=$'\xef\x84\xa1'  # U+F121  nf-fa-code
    ;;
  emoji)
    IC_SF='☁️'
    IC_ORG='🏢'
    IC_USER='👤'
    IC_API='🔗'
    ;;
  *)
    IC_SF='' IC_ORG='' IC_USER='' IC_API=''
    ;;
esac

# ── Parse sfdx-project.json ───────────────────────────────────────────────────
proj_json="$PROJ/sfdx-project.json"
api_version=$(jq -r '.sourceApiVersion // empty' "$proj_json" 2>/dev/null)
login_url=$(jq -r '.sfdcLoginUrl // empty' "$proj_json" 2>/dev/null)
namespace=$(jq -r '.namespace // empty' "$proj_json" 2>/dev/null)

org_type=''
[[ "$login_url" == *"test.salesforce.com"* ]] && org_type='sandbox'

# ── Resolve target org ────────────────────────────────────────────────────────
target_org=''
# Project-level config (highest priority)
if [[ -f "$PROJ/.sf/config.json" ]]; then
  target_org=$(jq -r '."target-org" // empty' "$PROJ/.sf/config.json" 2>/dev/null)
fi
# Legacy project .sfdx/sfdx-config.json
if [[ -z "$target_org" && -f "$PROJ/.sfdx/sfdx-config.json" ]]; then
  target_org=$(jq -r '.defaultusername // .defaultdevhubusername // empty' \
    "$PROJ/.sfdx/sfdx-config.json" 2>/dev/null)
fi
# Global user config
if [[ -z "$target_org" && -f "$HOME/.sf/config.json" ]]; then
  target_org=$(jq -r '."target-org" // empty' "$HOME/.sf/config.json" 2>/dev/null)
fi

# ── Resolve username from target org alias ────────────────────────────────────
username=''
if [[ -n "$target_org" ]]; then
  if [[ "$target_org" == *@* ]]; then
    # target-org is already a full username
    username="$target_org"
  elif [[ -f "$HOME/.sf/alias.json" ]]; then
    username=$(jq -r --arg a "$target_org" '.orgs[$a] // empty' \
      "$HOME/.sf/alias.json" 2>/dev/null)
  fi
  # Legacy: ~/.sfdx/<alias>.json
  if [[ -z "$username" && -f "$HOME/.sfdx/${target_org}.json" ]]; then
    username=$(jq -r '.username // empty' "$HOME/.sfdx/${target_org}.json" 2>/dev/null)
  fi
fi

# ── SF CLI version ────────────────────────────────────────────────────────────
sf_version=''
if command -v sf &>/dev/null; then
  sf_version=$(sf --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
fi

# ── Segments ──────────────────────────────────────────────────────────────────
# 1. SF header: icon + label + CLI version
sf_seg="${FG_ACCENT}${IC_SF} ${FG_TEXT}Salesforce"
[[ -n "$sf_version" ]] && sf_seg+=" ${FG_ACCENT}v${sf_version}"
seg "$sf_seg"

# 2. Target org alias, plus sandbox flag when applicable
if [[ -n "$target_org" ]]; then
  org_seg="${FG_ACCENT}${IC_ORG} ${FG_TEXT}${target_org}"
  [[ "$org_type" == 'sandbox' ]] && org_seg+=" ${FG_WARN}(sandbox)"
  seg "$org_seg"
fi

# 3. Authenticated username — only when it differs from the displayed alias
if [[ -n "$username" && "$username" != "$target_org" ]]; then
  seg "${FG_ACCENT}${IC_USER} ${FG_TEXT}${username}"
fi

# 4. Source API version
[[ -n "$api_version" ]] && seg "${FG_ACCENT}${IC_API} ${FG_TEXT}API ${FG_ACCENT}v${api_version}"

# 5. Namespace (when explicitly set in the project config)
[[ -n "$namespace" ]] && seg "${FG_TEXT}ns:${FG_ACCENT}${namespace}"

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
