#!/usr/bin/env bash
# lib/auto-bars.sh — scans $cdir for bar signal files and prepends
# auto-detected bars to CFG_BARS. Union of auto_bars.disabled across
# all three config layers is computed here (not via dmerge).
#
# Inputs : MERGED_CFG, CFG_BARS, cdir,
#          SETTINGS_CFG, USER_CFG, PROJ_CFG (paths set by lib/config.sh)
# Outputs: mutates CFG_BARS (prepends auto-detected entries)
# Exports: bl_apply_auto_bars (public entry)

bl_apply_auto_bars() {
  local _auto_bars_enabled
  _auto_bars_enabled=$(printf '%s' "$MERGED_CFG" | jq -r 'if .auto_bars.enabled == false then "false" else "true" end' 2>/dev/null)
  if [[ "$_auto_bars_enabled" != "false" && -n "$cdir" ]]; then
    [[ -z "$CFG_BARS" || "$CFG_BARS" == "null" ]] && CFG_BARS='[]'

    local _auto_bars_cfg
    _auto_bars_cfg=$(cfg_json '.auto_bars.scripts')
    [[ -z "$_auto_bars_cfg" || "$_auto_bars_cfg" == "null" ]] && _auto_bars_cfg='[]'

    # auto_bars.disabled accumulates across all config levels (union) so that a
    # project can add its own exclusions without re-listing the user's exclusions.
    local _d_s _d_u _d_p _disabled
    _d_s=$(jq -c '.auto_bars.disabled // empty' "$SETTINGS_CFG" 2>/dev/null)
    _d_u=''; [[ -f "$USER_CFG" ]]  && _d_u=$(jq -c '.auto_bars.disabled // empty' "$USER_CFG"  2>/dev/null)
    _d_p=''; [[ -n "$PROJ_CFG" ]] && _d_p=$(jq -c '.auto_bars.disabled // empty' "$PROJ_CFG" 2>/dev/null)
    _disabled=$(jq -n \
      --argjson s "${_d_s:-[]}" --argjson u "${_d_u:-[]}" --argjson p "${_d_p:-[]}" \
      '($s + $u + $p) | unique' 2>/dev/null || printf '[]')

    local _inherit_colors
    _inherit_colors=$(printf '%s' "$MERGED_CFG" | jq -r '.auto_bars.inherit_colors // false' 2>/dev/null)
    [[ "$_inherit_colors" != "true" ]] && _inherit_colors="false"

    _is_explicit() {
      printf '%s' "$CFG_BARS" \
        | jq -e --arg n "$1" 'any(.[]; .script == $n)' > /dev/null 2>&1
    }
    _is_disabled() {
      printf '%s' "$_disabled" \
        | jq -e --arg n "$1" 'any(.[]; . == $n)' > /dev/null 2>&1
    }

    local _auto='[]'
    local _entry_count
    _entry_count=$(printf '%s' "$_auto_bars_cfg" | jq 'length' 2>/dev/null || echo 0)

    local _ei _bar_name _matched _sig _f
    for (( _ei=0; _ei<_entry_count; _ei++ )); do
      _bar_name=$(printf '%s' "$_auto_bars_cfg" | jq -r ".[$_ei].script // empty" 2>/dev/null)
      [[ -z "$_bar_name" ]] && continue
      _is_explicit "$_bar_name" && continue
      _is_disabled "$_bar_name" && continue

      _matched=false
      while IFS= read -r _sig; do
        [[ -z "$_sig" ]] && continue
        for _f in "$cdir"/$_sig; do [[ -e "$_f" ]] && { _matched=true; break 2; }; done
      done < <(printf '%s' "$_auto_bars_cfg" | jq -r ".[$_ei].signals[]? // empty" 2>/dev/null)

      if "$_matched"; then
        local _bar_entry
        _bar_entry=$(printf '%s' "$_auto_bars_cfg" | jq -c ".[$_ei] | del(.signals)")
        [[ "$_inherit_colors" == "true" ]] && \
          _bar_entry=$(printf '%s' "$_bar_entry" | jq -c '.colors = "inherit"')
        local _global_rm _entry_rm _resolved_rm
        _global_rm=$(printf '%s' "$MERGED_CFG" | jq -r '.auto_bars.refresh_minutes // empty' 2>/dev/null)
        _entry_rm=$(printf '%s' "$_auto_bars_cfg" | jq -r ".[$_ei].refresh_minutes // empty" 2>/dev/null)
        _resolved_rm="${_entry_rm:-$_global_rm}"
        [[ -n "$_resolved_rm" ]] && \
          _bar_entry=$(printf '%s' "$_bar_entry" | jq -c --arg rm "$_resolved_rm" \
            '.refresh_minutes = ($rm | tonumber)')
        _auto=$(printf '%s' "$_auto" | jq --argjson e "$_bar_entry" '. + [$e]')
      fi
    done

    if [[ "$_auto" != "[]" ]]; then
      CFG_BARS=$(printf '%s' "$_auto" | jq --argjson cfg "$CFG_BARS" '. + $cfg')
    fi

    unset -f _is_explicit _is_disabled
  fi
}
