#!/usr/bin/env bash
# Bottomline bar: Salesforce ecosystem bar
# Renders when the project contains a sfdx-project.json.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init salesforce "#c7e0f4" "#1B96FF" '["#032D60","#0B4B8B"]' "$PROJ/sfdx-project.json" "$PROJ/.sf/config.json"

[[ ! -f "$PROJ/sfdx-project.json" ]] && exit 0

bl_icon_set IC_SF   $'\xef\x83\x82' '☁️'  # U+F0C2  nf-fa-cloud
bl_icon_set IC_ORG  $'\xef\x86\xad' '🏢'  # U+F1AD  nf-fa-building
bl_icon_set IC_USER $'\xef\x80\x87' '👤'  # U+F007  nf-fa-user
bl_icon_set IC_API  $'\xef\x84\xa1' '🔗'  # U+F121  nf-fa-code
bl_icon_set IC_PMD  $'\xef\x80\x8c' '🔍'  # U+F00C  nf-fa-check
bl_icon_set IC_LWC  $'\xef\x84\xa1' '⚡'  # U+F121  nf-fa-code

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
  elif [[ -f "$HOME/.sfdx/alias.json" ]]; then
    username=$(jq -r --arg a "$target_org" '.orgs[$a] // empty' \
      "$HOME/.sfdx/alias.json" 2>/dev/null)
  fi
  # Legacy: ~/.sfdx/<alias>.json — basename prevents path traversal from a
  # jq-parsed alias value containing directory separators.
  safe_alias=$(basename "$target_org")
  if [[ -z "$username" && -f "$HOME/.sfdx/${safe_alias}.json" ]]; then
    username=$(jq -r '.username // empty' "$HOME/.sfdx/${safe_alias}.json" 2>/dev/null)
  fi
fi

# ── SF CLI version ────────────────────────────────────────────────────────────
sf_version=''
if command -v sf &>/dev/null; then
  _sf_raw=$(sf --version 2>/dev/null)
  _sf_exit=$?
  (( _sf_exit != 0 )) && bl_log debug salesforce "sf --version exit=${_sf_exit}"
  sf_version=$(printf '%s' "$_sf_raw" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
fi

# ── PMD (Apex static analysis) ────────────────────────────────────────────────
has_pmd=false
[[ -f "$PROJ/.pmdrc" ]] && has_pmd=true
! $has_pmd && command -v pmd > /dev/null 2>&1 && has_pmd=true

# ── ESLint for LWC ───────────────────────────────────────────────────────────
has_lwc_eslint=false
if [[ -f "$PROJ/package.json" ]]; then
  if jq -e '((.dependencies // {}) + (.devDependencies // {})) | has("@salesforce/eslint-config-lwc")' \
    "$PROJ/package.json" > /dev/null 2>&1; then
    has_lwc_eslint=true
  fi
fi

# ── Segments ──────────────────────────────────────────────────────────────────
# Slot 5 (testing): Salesforce has no widely-adopted local test runner that can
# be detected from project files; test execution happens on-platform.

# 1. SF header: icon + label + CLI version
bl_version_seg "$IC_SF" Salesforce "$sf_version"

# 2. Target org alias, plus sandbox flag when applicable
if [[ -n "$target_org" ]]; then
  org_seg="${FG_ACCENT}${IC_ORG} ${FG_TEXT}${target_org}"
  [[ "$org_type" == 'sandbox' ]] && org_seg+=" ${FG_WARN}(sandbox)"
  add_seg "$org_seg"
fi

# 3. Authenticated username — only when it differs from the displayed alias
if [[ -n "$username" && "$username" != "$target_org" ]]; then
  seg "${FG_ACCENT}${IC_USER} ${FG_TEXT}${username}"
fi

# 4. Source API version
[[ -n "$api_version" ]] && bl_version_seg "$IC_API" API "$api_version"

# 5. Namespace (when explicitly set in the project config)
[[ -n "$namespace" ]] && seg "${FG_TEXT}ns:${FG_ACCENT}${namespace}"

# Slot 6: Tooling
$has_pmd         && seg "${FG_ACCENT}${IC_PMD} ${FG_TEXT}PMD"
$has_lwc_eslint  && seg "${FG_ACCENT}${IC_LWC} ${FG_TEXT}ESLint (LWC)"

bl_bar_finish "$_bar_gradient"
