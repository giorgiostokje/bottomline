#!/usr/bin/env bash
# lib/auto-bars.sh — scans $cdir for bar signal files and prepends
# auto-detected bars to CFG_BARS. Union of auto_bars.disabled across
# all three config layers is computed here (not via dmerge).
#
# Inputs : MERGED_CFG, CFG_BARS, cdir,
#          SETTINGS_CFG, USER_CFG, PROJ_CFG (paths set by lib/config.sh)
# Outputs: mutates CFG_BARS (prepends auto-detected entries)
# Exports: bl_apply_auto_bars (public entry)

# _bl_find_in_subdirs <cdir> <sig_glob> <max_depth>
# Returns the directory containing the shallowest (then lexically first) file
# matching sig_glob within subdirectories of cdir, up to max_depth levels deep.
# Prunes .git, node_modules, vendor, .build, target, Pods, DerivedData, dist,
# build, .venv so large/noisy dirs are never traversed.
# Prints the parent directory and returns 0 on success; returns 1 if no match.
_bl_find_in_subdirs() {
  local cdir="$1" sig="$2" max_depth="$3"
  local found
  found=$(find "$cdir" -maxdepth "$(( max_depth + 1 ))" \
    \( -type d \( -name ".git"       -o -name "node_modules" \
                  -o -name "vendor"  -o -name ".build"       \
                  -o -name "target"  -o -name "Pods"         \
                  -o -name "DerivedData" -o -name "dist"     \
                  -o -name "build"   -o -name ".venv" \) -prune \) \
    -o -type f -name "$sig" -print 2>/dev/null \
    | awk 'BEGIN{mind=999}{d=gsub("/","/",$0); if(d<mind||(d==mind&&$0<best)){mind=d;best=$0}} END{if(best)print best}')
  [[ -n "$found" ]] && dirname "$found" && return 0
  return 1
}

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

    local _global_depth
    _global_depth=$(printf '%s' "$MERGED_CFG" | jq -r '.auto_bars.search_depth // 0' 2>/dev/null)
    [[ "$_global_depth" =~ ^[0-9]+$ ]] || _global_depth=0

    local _auto='[]'
    local _entry_count
    _entry_count=$(printf '%s' "$_auto_bars_cfg" | jq 'length' 2>/dev/null || echo 0)

    local _ei _bar_name _matched _sig _f _found_dir _entry_depth _search_depth _sd_result
    for (( _ei=0; _ei<_entry_count; _ei++ )); do
      _bar_name=$(printf '%s' "$_auto_bars_cfg" | jq -r ".[$_ei].script // empty" 2>/dev/null)
      [[ -z "$_bar_name" ]] && continue
      _is_explicit "$_bar_name" && continue
      _is_disabled "$_bar_name" && continue

      _matched=false
      _found_dir="$cdir"

      # Root-level detection (unchanged behaviour)
      while IFS= read -r _sig; do
        [[ -z "$_sig" ]] && continue
        for _f in "$cdir"/$_sig; do [[ -e "$_f" ]] && { _matched=true; break 2; }; done
      done < <(printf '%s' "$_auto_bars_cfg" | jq -r ".[$_ei].signals[]? // empty" 2>/dev/null)

      # Subdir detection — only when root missed and search_depth > 0
      _entry_depth=$(printf '%s' "$_auto_bars_cfg" | jq -r ".[$_ei].search_depth // empty" 2>/dev/null)
      _search_depth="${_entry_depth:-$_global_depth}"
      [[ "$_search_depth" =~ ^[0-9]+$ ]] || _search_depth=0
      if ! "$_matched" && [[ "$_search_depth" -gt 0 ]]; then
        while IFS= read -r _sig; do
          [[ -z "$_sig" ]] && continue
          _sd_result=$(_bl_find_in_subdirs "$cdir" "$_sig" "$_search_depth") && {
            _matched=true
            _found_dir="$_sd_result"
            break
          }
        done < <(printf '%s' "$_auto_bars_cfg" | jq -r ".[$_ei].signals[]? // empty" 2>/dev/null)
      fi

      if "$_matched"; then
        local _bar_entry
        _bar_entry=$(printf '%s' "$_auto_bars_cfg" | jq -c ".[$_ei] | del(.signals)")
        [[ "$_found_dir" != "$cdir" ]] && \
          _bar_entry=$(printf '%s' "$_bar_entry" | jq -c --arg d "$_found_dir" '. + {project_dir: $d}')
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
