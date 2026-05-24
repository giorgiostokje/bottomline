#!/usr/bin/env bash
# Bottomline bar: Linear project management
# Segments (default order): cycle, in_progress, review, assigned
# Opt-in segments: priority, overdue, due_soon, cycle_days, blocked, mentions

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

# ── Palette ───────────────────────────────────────────────────────────────────
if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#e2e2f0")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#5E6AD2")")
  _bar_gradient='["#1a1a2e","#16162a"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

# ── Icons ─────────────────────────────────────────────────────────────────────
case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    _IC_LINEAR=$'\xee\x9c\xb7'    # U+E737  nf-dev-linear
    _IC_CYCLE=$'\xef\x8c\x81'     # U+F301  nf-mdi-sync
    _IC_PROGRESS=$'\xef\x87\x99'  # U+F1D9  nf-fa-circle_o_notch
    _IC_REVIEW=$'\xef\x81\xae'    # U+F06E  nf-fa-eye
    _IC_ASSIGNED=$'\xef\x82\xae'  # U+F0AE  nf-fa-tasks
    _IC_PRIORITY=$'\xef\x81\xaa'  # U+F06A  nf-fa-exclamation_circle
    _IC_OVERDUE=$'\xef\x81\xb3'   # U+F073  nf-fa-calendar
    _IC_DUE=$'\xef\x81\xb3'      # U+F073  nf-fa-calendar
    _IC_DAYS=$'\xef\x89\x92'      # U+F252  nf-fa-hourglass_half
    _IC_BLOCKED=$'\xef\x81\x9e'   # U+F05E  nf-fa-ban
    _IC_MENTIONS=$'\xef\x87\xba'  # U+F1FA  nf-fa-at
    _IC_WARN=$'\xef\x81\xb1'      # U+F071  nf-fa-warning
    ;;
  emoji)
    _IC_LINEAR='🔷'; _IC_CYCLE='🔄'; _IC_PROGRESS='⏳'; _IC_REVIEW='👁'
    _IC_ASSIGNED='📋'; _IC_PRIORITY='❗'; _IC_OVERDUE='📅'; _IC_DUE='📅'
    _IC_DAYS='⌛'; _IC_BLOCKED='🚫'; _IC_MENTIONS='@'; _IC_WARN='⚠️'
    ;;
  *)
    _IC_LINEAR=''; _IC_CYCLE=''; _IC_PROGRESS=''; _IC_REVIEW=''
    _IC_ASSIGNED=''; _IC_PRIORITY='!'; _IC_OVERDUE=''; _IC_DUE=''
    _IC_DAYS=''; _IC_BLOCKED=''; _IC_MENTIONS='@'; _IC_WARN='!'
    ;;
esac

# ── Params ────────────────────────────────────────────────────────────────────
_params="${BOTTOMLINE_BAR_PARAMS:-{}}"
_api_key=$(printf '%s' "$_params" | jq -r '.api_key // empty')
_team=$(printf '%s' "$_params" | jq -r '.team // empty')

# ── Validation (short-circuit: first failure exits) ───────────────────────────
if [[ -z "$_api_key" ]]; then
  add_seg "${FG_WARN}${_IC_WARN} Linear: missing api_key"
  flush "$_bar_gradient"
  exit 0
fi

if [[ -z "$_team" ]]; then
  add_seg "${FG_WARN}${_IC_WARN} Linear: missing team"
  flush "$_bar_gradient"
  exit 0
fi

# ── API call stub (will be expanded in Task 3) ────────────────────────────────
_response=$(curl -s -X POST "https://api.linear.app/graphql" \
  -H "Authorization: $_api_key" \
  -H "Content-Type: application/json" \
  --connect-timeout 5 \
  --max-time 10 \
  --data '{}' 2>/dev/null)

if [[ -z "$_response" ]]; then
  add_seg "${FG_WARN}${_IC_WARN} Linear: offline"
  flush "$_bar_gradient"
  exit 0
fi

_errors=$(printf '%s' "$_response" | jq -r 'if ((.errors // []) | length) > 0 then "yes" else "" end' 2>/dev/null)
if [[ -n "$_errors" ]]; then
  add_seg "${FG_WARN}${_IC_WARN} Linear: auth failed"
  flush "$_bar_gradient"
  exit 0
fi
