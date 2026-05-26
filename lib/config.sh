#!/usr/bin/env bash
# lib/config.sh — three-layer config merge + theme overrides.
#
# Inputs : $_BL_DIR (plugin root), $cdir (project dir, may be empty)
# Outputs: SETTINGS_CFG, USER_CFG, PROJ_CFG, MERGED_CFG,
#          CFG_TEXT_HEX, CFG_ACCENT_HEX, CFG_WARN_HEX, CFG_CRIT_HEX, CFG_BG,
#          CFG_EFFORT, CFG_CTX_THR, CFG_BRANCH, CFG_USAGE_THR,
#          CFG_ITEMS, CFG_HIDDEN, CFG_ICON_TYPE, CFG_ICON_OVR,
#          CFG_BARS, CFG_SEP_RAW
# Exports: cfg_str, cfg_json (functions)

# shellcheck disable=SC2034  # all CFG_* vars are consumed by sourced consumers

cfg_str()  { printf '%s' "$MERGED_CFG" | jq -r "$1 // empty" 2>/dev/null; }
cfg_json() { printf '%s' "$MERGED_CFG" | jq -c "$1 // empty" 2>/dev/null; }

bl_load_config() {
  SETTINGS_CFG="$_BL_DIR/settings.json"
  USER_CFG="$HOME/.claude/bottomline.json"
  PROJ_CFG=""
  [[ -n "$cdir" && -f "$cdir/.claude/bottomline.json" ]] && PROJ_CFG="$cdir/.claude/bottomline.json"

  # Deep-merge all three config layers: settings < user < project.
  # Objects are merged recursively — a partial object in a higher-priority file
  # fills in only the keys it defines; the rest fall through from lower layers.
  # Arrays and scalars: the highest-priority non-null value wins entirely.
  local _s_json _u_json _p_json
  _s_json=$(jq '.' "$SETTINGS_CFG" 2>/dev/null || printf '{}')
  _u_json='null'; [[ -f "$USER_CFG" ]]  && _u_json=$(jq '.' "$USER_CFG"  2>/dev/null || printf 'null')
  _p_json='null'; [[ -n "$PROJ_CFG" ]]  && _p_json=$(jq '.' "$PROJ_CFG"  2>/dev/null || printf 'null')

  MERGED_CFG=$(jq -n \
    --argjson s "$_s_json" --argjson u "$_u_json" --argjson p "$_p_json" '
      def dmerge(a; b):
        if b == null then a
        elif (a | type) == "object" and (b | type) == "object"
        then reduce (b | keys_unsorted[]) as $k (a; .[$k] = dmerge(a[$k]; b[$k]))
        elif (a | type) == "array" and (b | type) == "array"
             and (a | length > 0 and (.[0] | type == "object" and has("script")))
             and (b | length > 0 and (.[0] | type == "object" and has("script")))
        then
          (b | map({(.script): .}) | add // {}) as $bi |
          (a | map(. as $ae | dmerge($ae; $bi[$ae.script]))) +
          (b | map(select(.script as $s | (a | map(.script) | index($s)) == null)))
        else b
        end;
      dmerge(dmerge($s; $u); $p)
    ' 2>/dev/null || printf '{}')
  unset _s_json _u_json _p_json

  CFG_TEXT_HEX=$(cfg_str  '.appearance.colors.text')
  CFG_ACCENT_HEX=$(cfg_str '.appearance.colors.accent')
  CFG_WARN_HEX=$(cfg_str  '.appearance.colors.warning')
  CFG_CRIT_HEX=$(cfg_str  '.appearance.colors.danger')
  CFG_BG=$(cfg_json        '.appearance.colors.background')
  CFG_EFFORT=$(cfg_json  '.segments.effort')
  CFG_CTX_THR=$(cfg_json '.segments.context')
  CFG_BRANCH=$(cfg_json  '.segments.git_branch')
  CFG_USAGE_THR=$(cfg_json '.segments.usage')
  CFG_ITEMS=$(cfg_json     '.segments.enabled')
  CFG_HIDDEN=$(cfg_json    '.segments.disabled')
  CFG_ICON_TYPE=$(cfg_str  '.appearance.icons.type')
  CFG_ICON_OVR=$(cfg_json  '.appearance.icons.overrides')
  CFG_BARS=$(cfg_json    '.bars')
  CFG_SEP_RAW=$(cfg_str  '.segments.separator')
  CFG_LOG_LEVEL=$(cfg_str  '.debug.log_level')

  # When a theme is set in any config file (project > user > settings), its
  # colors take priority over all per-file color settings.
  local _theme_name _theme_file _v
  _theme_name=$(cfg_str '.appearance.theme')
  if [[ -n "$_theme_name" ]]; then
    _theme_file="$_BL_DIR/themes/${_theme_name}.json"
    if [[ -f "$_theme_file" ]]; then
      _v=$(jq -r '.colors.text       // empty' "$_theme_file" 2>/dev/null); [[ -n "$_v" ]] && CFG_TEXT_HEX="$_v"
      _v=$(jq -r '.colors.accent     // empty' "$_theme_file" 2>/dev/null); [[ -n "$_v" ]] && CFG_ACCENT_HEX="$_v"
      _v=$(jq -r '.colors.warning    // empty' "$_theme_file" 2>/dev/null); [[ -n "$_v" ]] && CFG_WARN_HEX="$_v"
      _v=$(jq -r '.colors.danger     // empty' "$_theme_file" 2>/dev/null); [[ -n "$_v" ]] && CFG_CRIT_HEX="$_v"
      _v=$(jq -c '.colors.background // empty' "$_theme_file" 2>/dev/null); [[ -n "$_v" ]] && CFG_BG="$_v"
    fi
    unset _theme_file _v
  fi
  unset _theme_name
}
