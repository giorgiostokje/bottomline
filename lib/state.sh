#!/usr/bin/env bash
# lib/state.sh — reads stdin JSON and resolves environmental state.
# Does I/O against git and the transcript file.
#
# Inputs : stdin (Claude Code JSON payload)
# Outputs: input, cdir, model, transcript, effort, cw_size,
#          ctx_used, sum_in, sum_out, sum_cache_read, sum_cache_create,
#          branch, branch_url, short_dir, dir_label,
#          five_pct, week_pct, five_rem, week_rem
# Exports: j, secs_until_reset (internal helpers)

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
  input=$(cat)

  cdir=$(j '.workspace.current_dir'); [[ -z "$cdir" ]] && cdir=$(j '.cwd')

  model=$(j '.model.display_name')
  transcript=$(j '.transcript_path')
  effort=$(j '.effort.level')

  cw_size=200000
  hint=$(j '.context_window.context_window_size // empty')
  [[ -n "$hint" && "$hint" -gt 0 ]] 2>/dev/null && cw_size=$hint

  ctx_used=0; sum_in=0; sum_out=0; sum_cache_read=0; sum_cache_create=0
  if [[ -n "$transcript" && -f "$transcript" ]]; then
    read -r ctx_used sum_in sum_out sum_cache_read sum_cache_create <<<"$(
      jq -rs '
        [ .[] | select(.type=="assistant") | .message.usage // empty ] as $u
        | ($u | last) as $last
        | [
            (( ($last.input_tokens // 0) + ($last.cache_read_input_tokens // 0)
             + ($last.cache_creation_input_tokens // 0) ) | floor),
            ([ $u[].input_tokens // 0 ]                    | add // 0),
            ([ $u[].output_tokens // 0 ]                   | add // 0),
            ([ $u[].cache_read_input_tokens // 0 ]          | add // 0),
            ([ $u[].cache_creation_input_tokens // 0 ]      | add // 0)
          ] | @tsv
      ' "$transcript" 2>/dev/null
    )"
    ctx_used=${ctx_used:-0}; sum_in=${sum_in:-0}; sum_out=${sum_out:-0}
    sum_cache_read=${sum_cache_read:-0}; sum_cache_create=${sum_cache_create:-0}
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

  five_pct=$(j '.rate_limits.five_hour.used_percentage')
  week_pct=$(j '.rate_limits.seven_day.used_percentage')
  five_raw=$(j '.rate_limits.five_hour.reset_at // .rate_limits.five_hour.resets_at // .rate_limits.five_hour.resets_in // empty')
  week_raw=$(j '.rate_limits.seven_day.reset_at // .rate_limits.seven_day.resets_at // .rate_limits.seven_day.resets_in // empty')
  five_rem=$(secs_until_reset "$five_raw")
  week_rem=$(secs_until_reset "$week_raw")
}
