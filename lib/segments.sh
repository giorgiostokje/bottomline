#!/usr/bin/env bash
# lib/segments.sh — main status line: build_* functions, gauge, threshold
# resolution, the dispatch loop, and the trailing flush.
#
# Inputs : (all CFG_* set by lib/config.sh),
#          FG_TEXT, FG_ACCENT, FG_WARN, FG_CRIT (set by lib/colors.sh),
#          IC_MODEL, IC_EFFORT, IC_CONTEXT, IC_DIRECTORY, IC_GIT_BRANCH,
#          IC_TOKENS_IN, IC_TOKENS_OUT, IC_USAGE_5H, IC_USAGE_7D,
#          IC_COST (set by lib/icons.sh),
#          model, effort, cw_size, ctx_used, sum_in, sum_out,
#          sum_cache_read, sum_cache_create, web_searches, total_cost,
#          branch, branch_url,
#          cdir, dir_label, five_pct, week_pct, five_rem, week_rem
#          (all set by lib/state.sh)
# Outputs: writes ANSI to stdout via flush; mutates _sc array (from lib/ansi.sh)
# Exports: gauge, threshold_resolve (internal),
#          build_* (internal), bl_render_main_line (public entry)

# shellcheck disable=SC2154  # vars set by lib/state.sh and lib/config.sh
# shellcheck disable=SC2034  # THR_COLOR_ANSI, THR_ICON set by threshold_resolve

gauge() {
  local used=$1 total=$2 width=${3:-10}
  [[ -z "$used" || -z "$total" || "$total" -le 0 ]] && return
  local filled=$(( used * width / total ))
  (( filled > width )) && filled=$width; (( filled < 0 )) && filled=0
  (( used > 0 && filled < 1 )) && filled=1
  local bar='' i
  for ((i=0; i<width; i++)); do
    (( i < filled )) && bar+="${FG_ACCENT}▰" || bar+="${FG_TEXT}▱"
  done
  printf '%s' "$bar"
}

# Thresholds must be sorted descending by .above.
# Sets globals: THR_COLOR_ANSI, THR_ICON (icon string for current icons.type, empty if none)
threshold_resolve() {
  local thresholds="$1" value="$2"
  THR_COLOR_ANSI="$FG_TEXT"; THR_ICON=''
  while IFS=$'\t' read -r above color icon_val; do
    (( value >= above )) || continue
    THR_COLOR_ANSI="$(resolve_color "${color:-text}")"
    THR_ICON=$(decode_icon "$icon_val")
    return
  done < <(printf '%s' "$thresholds" \
    | jq -r --arg t "$CFG_ICON_TYPE" \
      'to_entries | sort_by(.key | tonumber) | reverse | .[] | [(.key | tonumber), (.value.color // "text"), (.value.icon[$t] // "")] | @tsv' 2>/dev/null)
}

build_model() {
  [[ -z "$model" ]] && return
  add_seg "${FG_ACCENT}${IC_MODEL} ${FG_TEXT}${model}"
}

build_effort() {
  [[ -z "$effort" ]] && return
  local ef_entry ef_color ef_icon
  ef_entry=$(printf '%s' "$CFG_EFFORT" \
    | jq -c --arg e "$effort" '.[$e] // {}' 2>/dev/null)
  ef_color=$(printf '%s' "$ef_entry" | jq -r '.color // "text"' 2>/dev/null)
  ef_icon=$(printf '%s' "$ef_entry"  | jq -r --arg t "$CFG_ICON_TYPE" '.icon[$t] // empty' 2>/dev/null)
  [[ -n "$ef_icon" ]] && ef_icon=$(decode_icon "$ef_icon")
  [[ -z "$ef_color" ]] && ef_color="text"
  local ef_c; ef_c="$(resolve_color "$ef_color")"
  local suffix=''
  [[ -n "$ef_icon" ]] && suffix=" ${ef_c}${ef_icon}"
  add_seg "${FG_ACCENT}${IC_EFFORT} ${ef_c}${effort}${suffix}"
}

build_context() {
  (( cw_size <= 0 )) && return
  local bar; bar=$(gauge "$ctx_used" "$cw_size" 10)
  threshold_resolve "$CFG_CTX_THR" "$ctx_used"
  local suffix=''; [[ -n "$THR_ICON" ]] && suffix=" ${THR_COLOR_ANSI}${THR_ICON}"
  add_seg "${FG_ACCENT}${IC_CONTEXT} ${bar} ${THR_COLOR_ANSI}$(fmt_k "$ctx_used")/$(fmt_k "$cw_size")${suffix}"
}

build_directory() {
  [[ -z "$cdir" ]] && return
  local content="${FG_ACCENT}${IC_DIRECTORY} ${FG_TEXT}${dir_label}"
  add_seg "$(link "file://${cdir}" "$content")"
}

build_branch() {
  [[ -z "$branch" ]] && return
  local br_entry br_color br_icon
  br_entry=$(printf '%s' "$CFG_BRANCH" | jq -c --arg b "$branch" '.[$b] // {}' 2>/dev/null)
  br_color=$(printf '%s' "$br_entry" | jq -r '.color // "text"' 2>/dev/null)
  br_icon=$(printf '%s' "$br_entry"  | jq -r --arg t "$CFG_ICON_TYPE" '.icon[$t] // empty' 2>/dev/null)
  [[ -n "$br_icon" ]] && br_icon=$(decode_icon "$br_icon")
  [[ -z "$br_color" ]] && br_color="text"
  local br_c; br_c="$(resolve_color "$br_color")"
  local suffix=''
  [[ -n "$br_icon" ]] && suffix=" ${br_c}${br_icon}"
  local content="${FG_ACCENT}${IC_GIT_BRANCH} ${br_c}${branch}${suffix}"
  [[ -n "$branch_url" ]] && content="$(link "$branch_url" "$content")"
  add_seg "$content"
}

build_tokens_in() {
  local base=$(( sum_in + sum_cache_create ))
  (( base + sum_cache_read <= 0 )) && return
  local tok; tok="${FG_ACCENT}${IC_TOKENS_IN} ${FG_TEXT}$(fmt_n "$base")"
  (( sum_cache_read > 0 )) && tok+="${N}${FG_ACCENT}+$(fmt_n "$sum_cache_read")"
  add_seg "$tok"
}

build_tokens_out() {
  (( sum_out <= 0 )) && return
  add_seg "${FG_ACCENT}${IC_TOKENS_OUT} ${FG_TEXT}$(fmt_n "$sum_out")"
}

build_usage_5h() {
  [[ -z "$five_pct" ]] && return
  local five_int; five_int=$(printf '%.0f' "$five_pct")
  threshold_resolve "$CFG_USAGE_THR" "$five_int"
  local lbl="${FG_ACCENT}${IC_USAGE_5H} ${THR_COLOR_ANSI}${five_int}%"
  [[ -n "$five_rem" ]] && lbl+=" ${N}${FG_ACCENT}$(fmt_remaining "$five_rem")" || lbl+="${N}${FG_ACCENT}/5h"
  add_seg "$lbl"
}

build_usage_7d() {
  [[ -z "$week_pct" ]] && return
  local week_int; week_int=$(printf '%.0f' "$week_pct")
  threshold_resolve "$CFG_USAGE_THR" "$week_int"
  local lbl="${FG_ACCENT}${IC_USAGE_7D} ${THR_COLOR_ANSI}${week_int}%"
  [[ -n "$week_rem" ]] && lbl+=" ${N}${FG_ACCENT}$(fmt_remaining "$week_rem")" || lbl+="${N}${FG_ACCENT}/7d"
  add_seg "$lbl"
}

# Session spend. Claude Code reports its own running total in
# .cost.total_cost_usd: it covers every model and version (including
# subagents running on other models), fast mode, 1-hour cache writes and any
# org modelPricing overrides, so it is used whenever present.
#
# Fallback for Claude Code versions without that field: estimate from the
# transcript totals, priced at the *current* model's rates. Per-MTok rates and
# the $10/1,000 web-search rate are from
# https://platform.claude.com/docs/en/about-claude/pricing. Cache writes use the
# 5-minute rate (1.25x input). The version is parsed from the model string
# ("Opus 4.8" or id form "claude-opus-4-8"); unknown versions get the current
# pricing for their family, unknown families get Sonnet rates.
build_cost() {
  local c
  if [[ -n "$total_cost" ]]; then
    c=$total_cost
  else
    (( sum_in + sum_out + sum_cache_read + sum_cache_create + ${web_searches:-0} <= 0 )) && return
    c=$(bl_estimate_cost)
  fi
  local cost_fmt
  cost_fmt=$(awk -v c="$c" 'BEGIN {
      if (c + 0 <= 0)     exit 1
      if (c < 0.005) printf "< $0.01"
      else           printf "$%.2f", c
    }') || return
  add_seg "${FG_ACCENT}${IC_COST} ${FG_TEXT}${cost_fmt}"
}

bl_estimate_cost() {
  local price_in price_out price_cache_read price_cache_write
  local maj=0 min=0
  if [[ "$model" =~ ([0-9]+)([.-]([0-9]+))? ]]; then
    maj=${BASH_REMATCH[1]}
    # A trailing date suffix ("-20241022") is not a minor version
    [[ -n "${BASH_REMATCH[3]}" && ${#BASH_REMATCH[3]} -le 2 ]] && min=$((10#${BASH_REMATCH[3]}))
  fi
  case "$model" in
    *Fable*|*fable*|*Mythos*|*mythos*)
      if (( maj == 5 && min == 0 )); then
        price_in=10; price_out=50; price_cache_read=1.00; price_cache_write=12.50
      else
        # Fable 5.1+ — cheaper cache reads
        price_in=10; price_out=50; price_cache_read=0.25; price_cache_write=12.50
      fi ;;
    *Opus*|*opus*)
      if (( maj > 0 && (maj < 4 || (maj == 4 && min <= 1)) )); then
        # Opus 4.1 and earlier — legacy pricing
        price_in=15; price_out=75; price_cache_read=1.50; price_cache_write=18.75
      elif (( maj == 5 && min == 0 || maj == 4 )); then
        # Opus 4.5 – 5
        price_in=5;  price_out=25; price_cache_read=0.50; price_cache_write=6.25
      else
        # Opus 5.5+ — current pricing
        price_in=4;  price_out=20; price_cache_read=0.20; price_cache_write=5.00
      fi ;;
    *Haiku*|*haiku*)
      if (( maj > 0 && maj < 4 )); then
        # Haiku 3.5 — retired pricing
        price_in=0.80; price_out=4; price_cache_read=0.08; price_cache_write=1.00
      else
        # Haiku 4.5+ — current pricing
        price_in=1;    price_out=5; price_cache_read=0.10; price_cache_write=1.25
      fi ;;
    *Sonnet*|*sonnet*)
      if (( maj > 0 && maj < 5 )); then
        # Sonnet 3.x / 4 / 4.5 / 4.6
        price_in=3; price_out=15; price_cache_read=0.30; price_cache_write=3.75
      else
        # Sonnet 5+ — current pricing
        price_in=2; price_out=10; price_cache_read=0.20; price_cache_write=2.50
      fi ;;
    *)
      price_in=3; price_out=15; price_cache_read=0.30; price_cache_write=3.75 ;;
  esac
  awk \
    -v in_tok="$sum_in"  -v out_tok="$sum_out" \
    -v cr="$sum_cache_read" -v cw="$sum_cache_create" \
    -v ws="${web_searches:-0}" \
    -v pi="$price_in"    -v po="$price_out" \
    -v pcr="$price_cache_read" -v pcw="$price_cache_write" \
    'BEGIN {
      # ws*10000/1e6 == ws * ($10 / 1000 searches) == ws * $0.01
      printf "%.6f", (in_tok*pi + out_tok*po + cr*pcr + cw*pcw + ws*10000) / 1000000
    }'
}

bl_render_main_line() {
  _is_seg_hidden() {
    [[ -z "$CFG_HIDDEN" || "$CFG_HIDDEN" == "null" ]] && return 1
    printf '%s' "$CFG_HIDDEN" | jq -e --arg n "$1" 'any(.[]; . == $n)' > /dev/null 2>&1
  }

  _items_out=$(printf '%s' "$CFG_ITEMS" | jq -r '.[]' 2>/dev/null)
  [[ -z "$_items_out" ]] && _items_out="model
effort
context
directory
git_branch
tokens_in
tokens_out
usage_5h
usage_7d"

  while IFS= read -r _item; do
    [[ -z "$_item" ]] && continue
    _is_seg_hidden "$_item" && continue
    case "$_item" in
      model)     build_model     ;;
      effort)    build_effort    ;;
      context)   build_context   ;;
      directory) build_directory ;;
      git_branch)  build_branch      ;;
      tokens_in)   build_tokens_in  ;;
      tokens_out)  build_tokens_out ;;
      usage_5h)    build_usage_5h   ;;
      usage_7d)  build_usage_7d  ;;
      cost)      build_cost      ;;
    esac
  done <<< "$_items_out"
  unset -f _is_seg_hidden
  unset _item _items_out

  flush "$CFG_BG"
}
