#!/usr/bin/env bash
# lib/icons.sh — Nerd Font / emoji icon constants and per-segment IC_* resolution.
# Depends on lib/functions.sh for decode_icon, lib/ansi.sh nothing (no ANSI).
#
# Inputs : CFG_ICON_TYPE, CFG_ICON_OVR, CFG_SEP_RAW (set by lib/config.sh)
# Outputs: IC_MODEL, IC_EFFORT, IC_CONTEXT, IC_DIRECTORY, IC_GIT_BRANCH,
#          IC_TOKENS_IN, IC_TOKENS_OUT, IC_USAGE_5H, IC_USAGE_7D,
#          IC_COST, IC_DANGER, SEP
# Exports: get_icon (function)

# shellcheck disable=SC2034  # output vars consumed by lib/segments.sh

SEP=$'\xee\x82\xb4'

NF_MODEL=$'\xef\x8b\x9b'   NF_BOLT=$'\xef\x83\xa7'   NF_CTX=$'\xef\x82\xae'
NF_DIR=$'\xef\x81\xbc'     NF_GIT=$'\xee\x82\xa0'    NF_UP=$'\xef\x81\xa2'
NF_DOWN=$'\xef\x81\xa3'    NF_CLOCK=$'\xef\x80\x97'  NF_CAL=$'\xef\x81\xb3'
NF_COST=$'\xef\x83\x96'    NF_WARN=$'\xef\x81\xb1'   NF_DANGER=$'\xef\x81\x9e'

EM_MODEL='🖥'  EM_BOLT='⚡'  EM_CTX='◈'   EM_DIR='📁'  EM_GIT='⎇'
EM_UP='↑'      EM_DOWN='↓'  EM_CLOCK='⏱' EM_CAL='📅'  EM_COST='💰'
EM_WARN='⚠'   EM_DANGER='🛑'

get_icon() {
  local name="$1" override
  override=$(printf '%s' "$CFG_ICON_OVR" | jq -r --arg n "$name" '.[$n] // empty' 2>/dev/null)
  if [[ -z "$override" && ("$name" == tokens_in || "$name" == tokens_out) ]]; then
    override=$(printf '%s' "$CFG_ICON_OVR" | jq -r '.tokens // empty' 2>/dev/null)
  fi
  [[ -n "$override" ]] && decode_icon "$override" && return
  case "$CFG_ICON_TYPE" in
    nerd)
      case "$name" in
        model)      printf '%s' "$NF_MODEL"  ;; effort)    printf '%s' "$NF_BOLT"   ;;
        context)    printf '%s' "$NF_CTX"    ;; directory) printf '%s' "$NF_DIR"    ;;
        git_branch) printf '%s' "$NF_GIT"    ;; tokens_in) printf '%s' "$NF_UP"     ;;
        tokens_out) printf '%s' "$NF_DOWN"   ;; usage_5h)  printf '%s' "$NF_CLOCK"  ;;
        usage_7d)   printf '%s' "$NF_CAL"    ;; cost)      printf '%s' "$NF_COST"   ;;
        warn)       printf '%s' "$NF_WARN"   ;; danger)    printf '%s' "$NF_DANGER" ;;
        *)          printf '%s' "$name"      ;;
      esac ;;
    emoji)
      case "$name" in
        model)      printf '%s' "$EM_MODEL"  ;; effort)    printf '%s' "$EM_BOLT"   ;;
        context)    printf '%s' "$EM_CTX"    ;; directory) printf '%s' "$EM_DIR"    ;;
        git_branch) printf '%s' "$EM_GIT"    ;; tokens_in) printf '%s' "$EM_UP"     ;;
        tokens_out) printf '%s' "$EM_DOWN"   ;; usage_5h)  printf '%s' "$EM_CLOCK"  ;;
        usage_7d)   printf '%s' "$EM_CAL"    ;; cost)      printf '%s' "$EM_COST"   ;;
        warn)       printf '%s' "$EM_WARN"   ;; danger)    printf '%s' "$EM_DANGER" ;;
        *)          printf '%s' "$name"      ;;
      esac ;;
    none) printf '' ;;
  esac
}

bl_init_icons() {
  IC_MODEL=$(get_icon model)         IC_EFFORT=$(get_icon effort)       IC_CONTEXT=$(get_icon context)
  IC_DIRECTORY=$(get_icon directory) IC_GIT_BRANCH=$(get_icon git_branch)
  IC_TOKENS_IN=$(get_icon tokens_in) IC_TOKENS_OUT=$(get_icon tokens_out)
  IC_USAGE_5H=$(get_icon usage_5h)   IC_USAGE_7D=$(get_icon usage_7d)
  IC_COST=$(get_icon cost)           IC_DANGER=$(get_icon danger)

  [[ -n "$CFG_SEP_RAW" ]] && SEP=$(decode_icon "$CFG_SEP_RAW")
}
