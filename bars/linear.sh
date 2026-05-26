#!/usr/bin/env bash
# Bottomline bar: Linear project management
# Segments (default order): label, cycle, in_progress, review, assigned
# Opt-in segments: team, priority, overdue, due_soon, cycle_days, blocked, mentions
#
# Cache deviation: this bar does NOT use bl_bar_init because (1) refresh
# defaults to 0 (no caching unless explicitly opted in via refresh_minutes),
# (2) it uses "team:api_key" as the cache discriminator instead of the
# project dir, and (3) on API failure it falls back to a stale cache file
# (any bucket) rather than re-running the request. Manages its own cache
# lifecycle below.

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
    IC_LINEAR=$'\xef\x88\x99'     # U+F219  nf-fa-diamond
    IC_CYCLE=$'\xef\x8c\x81'      # U+F301  nf-mdi-sync
    IC_PROGRESS=$'\xef\x87\x99'   # U+F1D9  nf-fa-circle_o_notch
    IC_REVIEW=$'\xef\x81\xae'     # U+F06E  nf-fa-eye
    IC_ASSIGNED=$'\xef\x82\xae'   # U+F0AE  nf-fa-tasks
    IC_PRIORITY=$'\xef\x81\xaa'   # U+F06A  nf-fa-exclamation_circle
    IC_OVERDUE=$'\xef\x81\xb3'    # U+F073  nf-fa-calendar
    IC_DUE=$'\xef\x81\xb3'        # U+F073  nf-fa-calendar
    IC_DAYS=$'\xef\x89\x92'       # U+F252  nf-fa-hourglass_half
    IC_BLOCKED=$'\xef\x81\x9e'    # U+F05E  nf-fa-ban
    IC_MENTIONS=$'\xef\x87\xba'   # U+F1FA  nf-fa-at
    ;;
  emoji)
    IC_LINEAR='◈'
    IC_CYCLE='🔄'; IC_PROGRESS='⏳'; IC_REVIEW='👁'
    IC_ASSIGNED='📋'; IC_PRIORITY='❗'; IC_OVERDUE='📅'; IC_DUE='📅'
    IC_DAYS='⌛'; IC_BLOCKED='🚫'; IC_MENTIONS='@'
    ;;
  *)
    IC_LINEAR=''
    IC_CYCLE=''; IC_PROGRESS=''; IC_REVIEW=''
    IC_ASSIGNED=''; IC_PRIORITY='!'; IC_OVERDUE=''; IC_DUE=''
    IC_DAYS=''; IC_BLOCKED=''; IC_MENTIONS='@'
    ;;
esac

# ── Params ────────────────────────────────────────────────────────────────────
_params="$BOTTOMLINE_BAR_PARAMS"
if [[ -z "$_params" ]]; then _params='{}'; fi
_api_key=$(printf '%s' "$_params" | jq -r '.api_key // empty')
_team=$(printf '%s' "$_params" | jq -r '.team // empty')

[[ -z "$_api_key" || -z "$_team" ]] && exit 0

# ── Caching setup ─────────────────────────────────────────────────────────────
_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-0}"
_cache_file=$(bl_cache_path "linear" "$(( _bl_ttl > 0 ? _bl_ttl : 1 ))" "${_team}:${_api_key}")
_cache_dir=$(dirname "$_cache_file")

# Stale-cache glob: same name+projhash+fingerprint, any bucket
_cache_stem="${_cache_file%_*_*.txt}"
_stale_cache=$(find -L "$_cache_dir" -maxdepth 1 \
  -name "${_cache_stem##*/}_*.txt" 2>/dev/null | head -1)

if [[ "$_bl_ttl" -gt 0 && -f "$_cache_file" ]]; then
  cat "$_cache_file"
  exit 0
fi

# ── API call ──────────────────────────────────────────────────────────────────
# shellcheck disable=SC2016
_gql='query BottomlineLinear($team: String!) {
  teams(filter: { key: { eq: $team } }) {
    nodes {
      name
      activeCycle {
        id name endsAt
        completedIssueCountHistory
        issueCountHistory
      }
    }
  }
  viewer {
    id
    assignedIssues(
      filter: { state: { type: { nin: ["completed","cancelled"] } } }
    ) {
      nodes {
        state { type name }
        priority
        dueDate
        cycle { id }
        relations { nodes { type relatedIssue { state { type } } } }
      }
    }
  }
  notificationsUnreadCount
}'

_body=$(jq -n --arg q "$_gql" --arg t "$_team" \
  '{"query":$q,"variables":{"team":$t}}')

_response=$(curl -s -X POST "https://api.linear.app/graphql" \
  -H "Authorization: $_api_key" \
  -H "Content-Type: application/json" \
  --connect-timeout 5 \
  --max-time 10 \
  --data "$_body" 2>/dev/null)
_curl_exit=$?
bl_log debug linear "curl exit=${_curl_exit} response_len=${#_response}"
[[ -n "$_response" ]] && bl_log debug linear "response: ${_response:0:500}"

# ── Error handling ────────────────────────────────────────────────────────────
if [[ -z "$_response" ]]; then
  if [[ -n "$_stale_cache" ]]; then
    bl_log warn linear "no response (curl exit=${_curl_exit}), using stale cache"
    cat "$_stale_cache"
    exit 0
  fi
  bl_log error linear "no response (curl exit=${_curl_exit}) and no stale cache"
  bl_data_seg "$IC_LINEAR" Linear offline warn 1
  flush "$_bar_gradient"
  exit 0
fi

_errors=$(printf '%s' "$_response" | jq -r 'if ((.errors // []) | length) > 0 then "yes" else "" end' 2>/dev/null)
if [[ -n "$_errors" ]]; then
  _error_msgs=$(printf '%s' "$_response" | jq -r '[.errors[].message] | join("; ")' 2>/dev/null)
  bl_log warn linear "API errors: ${_error_msgs}"
  bl_data_seg "$IC_LINEAR" Linear "API error" crit 1
  flush "$_bar_gradient"
  exit 0
fi

# ── Data extraction ───────────────────────────────────────────────────────────
_cycle_id=$(printf '%s' "$_response" | jq -r '.data.teams.nodes[0].activeCycle.id // empty')
_team_name=$(printf '%s' "$_response" | jq -r '.data.teams.nodes[0].name // empty')
_cycle_name=$(printf '%s' "$_response" | jq -r '.data.teams.nodes[0].activeCycle.name // empty')
_cycle_done=$(printf '%s' "$_response" | jq -r '(.data.teams.nodes[0].activeCycle.completedIssueCountHistory // []) | if length > 0 then last else 0 end')
_cycle_total=$(printf '%s' "$_response" | jq -r '(.data.teams.nodes[0].activeCycle.issueCountHistory // []) | if length > 0 then last else 0 end')
_issues=$(printf '%s' "$_response" | jq -c '.data.viewer.assignedIssues.nodes // []')
_notif_count=$(printf '%s' "$_response" | jq '.data.notificationsUnreadCount // 0')
_today=$(date +%Y-%m-%d)   # used by overdue/due_soon opt-in segments

_count_in_progress=$(printf '%s' "$_issues" | jq \
  --arg cid "$_cycle_id" '[.[] | select(
    .state.type == "started" and
    (.state.name | ascii_downcase | contains("review") | not) and
    (if $cid != "" then .cycle.id == $cid else true end)
  )] | length')

_count_review=$(printf '%s' "$_issues" | jq \
  --arg cid "$_cycle_id" '[.[] | select(
    .state.type == "started" and
    (.state.name | ascii_downcase | contains("review")) and
    (if $cid != "" then .cycle.id == $cid else true end)
  )] | length')

_count_assigned=$(printf '%s' "$_issues" | jq 'length')

# Counts for opt-in segments
_count_priority=$(printf '%s' "$_issues" | jq \
  '[.[] | select(.priority == 1 or .priority == 2)] | length')

_count_overdue=$(printf '%s' "$_issues" | jq \
  --arg today "$_today" \
  '[.[] | select(.dueDate != null and .dueDate < $today)] | length')

_due_soon_days=$(printf '%s' "$_params" | jq -r '.due_soon_days // 3')
[[ "$_due_soon_days" =~ ^[0-9]+$ ]] || _due_soon_days=3
_future=$(date -d "+${_due_soon_days} days" +%Y-%m-%d 2>/dev/null \
          || date -v "+${_due_soon_days}d" +%Y-%m-%d 2>/dev/null)
_count_due_soon=$(printf '%s' "$_issues" | jq \
  --arg today "$_today" --arg future "$_future" \
  '[.[] | select(.dueDate != null and .dueDate >= $today and .dueDate <= $future)] | length')

_count_blocked=$(printf '%s' "$_issues" | jq \
  '[.[] | select(
    .relations.nodes | any(
      .type == "blocked_by" and
      .relatedIssue.state.type != "completed" and
      .relatedIssue.state.type != "cancelled"
    )
  )] | length')

_cycle_days_left=0
if [[ -n "$_cycle_id" ]]; then
  _cycle_ends=$(printf '%s' "$_response" \
    | jq -r '.data.teams.nodes[0].activeCycle.endsAt // empty')
  if [[ -n "$_cycle_ends" ]]; then
    _end_secs=$(date -d "$_cycle_ends" +%s 2>/dev/null \
                || date -j -f "%Y-%m-%dT%H:%M:%S.000Z" "${_cycle_ends%%.*}.000Z" +%s 2>/dev/null)
    if [[ -n "$_end_secs" ]]; then
      _now_secs=$(date +%s)
      _cycle_days_left=$(( (_end_secs - _now_secs) / 86400 ))
      (( _cycle_days_left < 0 )) && _cycle_days_left=0
    fi
  fi
fi

# ── Segment list ──────────────────────────────────────────────────────────────
_default_segs='["label","cycle","in_progress","review","assigned"]'
_seg_list="${BOTTOMLINE_BAR_SEGMENTS:-$_default_segs}"

# ── Render ────────────────────────────────────────────────────────────────────
while IFS= read -r _seg_name; do
  case "$_seg_name" in
    label)
      bl_data_seg "$IC_LINEAR" Linear "$_team" "" "1"
      ;;
    team)
      [[ -n "$_team_name" ]] && \
        bl_seg "" "$_team_name"
      ;;
    cycle)
      [[ -n "$_cycle_name" ]] && \
        bl_data_seg "$IC_CYCLE" "$_cycle_name" "${_cycle_done}/${_cycle_total}" "" "1"
      ;;
    in_progress)
      (( _count_in_progress > 0 )) && bl_data_seg "$IC_PROGRESS" "$_count_in_progress" "wip"
      ;;
    review)
      (( _count_review > 0 )) && bl_data_seg "$IC_REVIEW" "$_count_review" "review"
      ;;
    assigned)
      (( _count_assigned > 0 )) && bl_data_seg "$IC_ASSIGNED" "$_count_assigned" "open"
      ;;
    priority)
      (( _count_priority > 0 )) && bl_data_seg "$IC_PRIORITY" "$_count_priority" "urgent" "warn"
      ;;
    overdue)
      (( _count_overdue > 0 )) && bl_data_seg "$IC_OVERDUE" "$_count_overdue" "overdue" "crit"
      ;;
    due_soon)
      (( _count_due_soon > 0 )) && bl_data_seg "$IC_DUE" "$_count_due_soon" "due soon" "warn"
      ;;
    cycle_days)
      [[ -n "$_cycle_id" && "$_cycle_days_left" -gt 0 ]] && bl_data_seg "$IC_DAYS" "${_cycle_days_left}d" "left"
      ;;
    blocked)
      (( _count_blocked > 0 )) && bl_data_seg "$IC_BLOCKED" "$_count_blocked" "blocked" "warn"
      ;;
    mentions)
      (( _notif_count > 0 )) && bl_data_seg "$IC_MENTIONS" "$_notif_count" "unread"
      ;;
    *)
      ;; # unknown segment: silently skip
  esac
done < <(printf '%s' "$_seg_list" | jq -r '.[]' 2>/dev/null)

(( ${#_sc[@]} == 0 )) && exit 0
_bl_out=$(flush "$_bar_gradient")
if [[ "$_bl_ttl" -gt 0 ]]; then
  bl_cache_write "$_cache_file" "$_bl_out"
fi
printf '%s' "$_bl_out"
