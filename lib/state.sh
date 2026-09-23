#!/usr/bin/env bash
# lib/state.sh — reads stdin JSON and resolves environmental state.
# Does I/O against git; the transcript is read by lib/usage.sh.
#
# Inputs : stdin (Claude Code JSON payload)
# Outputs: input, cdir, model, transcript, effort, cw_size,
#          ctx_used, ctx_from_payload, total_cost,
#          branch, branch_url, short_dir, dir_label,
#          five_pct, week_pct, five_rem, week_rem,
#          pc_observed, pc_warm, pc_ttl, pc_expires, pc_recache
#          (token totals are read separately by lib/usage.sh)
# Exports: j, secs_until_reset (internal helpers)

# shellcheck disable=SC2034  # all output vars consumed by lib/segments.sh
# shellcheck disable=SC2154  # vars set by caller, used by downstream

j()    { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

secs_until_reset() {
  local val="$1"; [[ -z "$val" ]] && return
  local now; now=$(date '+%s')
  local target
  if [[ "$val" =~ ^[0-9]+$ ]]; then
    (( val < 700000 )) && { (( val > 0 )) && printf '%d' "$val"; return; }
    target=$val
  else
    target=$(date -j -f '%Y-%m-%dT%H:%M:%SZ' "$val" '+%s' 2>/dev/null) \
         || target=$(date -d "$val" '+%s' 2>/dev/null)
  fi
  [[ -z "$target" ]] && return
  local rem=$(( target - now )); (( rem > 0 )) && printf '%d' "$rem"
}

bl_read_state() {
  local hint five_raw week_raw remote_url host path
  input=$(cat)

  # One jq pass over the payload. Fields are joined with the ASCII unit
  # separator (not a tab): IFS whitespace would collapse empty fields.
  IFS=$'\x1f' read -r cdir model transcript effort hint ctx_payload total_cost \
    five_pct week_pct five_raw week_raw \
    pc_observed pc_warm pc_ttl pc_expires pc_recache <<<"$(
    printf '%s' "$input" | jq -r '[
        (.workspace.current_dir // .cwd),
        .model.display_name,
        .transcript_path,
        .effort.level,
        .context_window.context_window_size,
        .context_window.total_input_tokens,
        .cost.total_cost_usd,
        .rate_limits.five_hour.used_percentage,
        .rate_limits.seven_day.used_percentage,
        (.rate_limits.five_hour.reset_at // .rate_limits.five_hour.resets_at // .rate_limits.five_hour.resets_in),
        (.rate_limits.seven_day.reset_at // .rate_limits.seven_day.resets_at // .rate_limits.seven_day.resets_in),
        .prompt_cache.caching_observed,
        .prompt_cache.warm,
        .prompt_cache.ttl,
        .prompt_cache.expires_at,
        .prompt_cache.recache_tokens_if_cold
      ] | map(if . == null then "" else tostring end) | join("\u001f")
    ' 2>/dev/null
  )"

  cw_size=200000
  [[ -n "$hint" && "$hint" -gt 0 ]] 2>/dev/null && cw_size=$hint

  # Context comes from the payload (same input + cache-read + cache-write sum);
  # lib/usage.sh falls back to the transcript on Claude Code versions without it.
  ctx_used=0; ctx_from_payload=''
  if [[ "$ctx_payload" =~ ^[0-9]+$ ]]; then
    ctx_used=$ctx_payload; ctx_from_payload=1
  fi

  branch='' branch_url=''
  if [[ -n "$cdir" && -d "$cdir" ]]; then
    branch=$(git -C "$cdir" symbolic-ref --short -q HEAD 2>/dev/null)
    if [[ -n "$branch" ]]; then
      remote_url=$(git -C "$cdir" config --get remote.origin.url 2>/dev/null)
      if [[ -n "$remote_url" ]]; then
        case "$remote_url" in
          git@*)
            host=${remote_url#git@}; host=${host%%:*}
            path=${remote_url#*:};   path=${path%.git}
            branch_url="https://${host}/${path}/tree/${branch}" ;;
          https://*|http://*)
            path=${remote_url%.git}
            case "$path" in
              *github.com*|*gitlab.com*|*bitbucket.org*)
                branch_url="${path}/tree/${branch}" ;;
            esac ;;
        esac
      fi
    fi
  fi

  short_dir="$cdir"
  [[ -n "$HOME" ]] && short_dir="${cdir/#$HOME/~}"
  dir_label="${short_dir##*/}"; [[ -z "$dir_label" ]] && dir_label="$short_dir"

  five_rem=$(secs_until_reset "$five_raw")
  week_rem=$(secs_until_reset "$week_raw")
}
