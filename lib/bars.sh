#!/usr/bin/env bash
# lib/bars.sh — bar execution loop. Two paths: external script bars
# (run inside ( ... ) subshell for export isolation between bars) and
# inline bars (rendered at parent scope from .segments JSON).
#
# Inputs : CFG_BARS, CFG_TEXT_HEX, CFG_ACCENT_HEX, CFG_WARN_HEX, CFG_CRIT_HEX,
#          CFG_BG, CFG_ICON_TYPE, SEP, B, R,
#          C_R[0], C_G[0], C_B[0],
#          IC_DANGER, cdir, _BL_DIR,
#          FG_TEXT, FG_ACCENT, FG_WARN, FG_CRIT (set by lib/colors.sh)
# Outputs: writes ANSI to stdout via flush; transiently exports BOTTOMLINE_*
#          env vars to bar subprocesses (script bars only)
# Exports: bl_render_bars (public entry),
#          resolve_bar_script, resolve_bar_color (file-scope helpers)

resolve_bar_script() {
  local name="$1"
  [[ -z "$name" || "$name" == "null" ]] && return
  if [[ "$name" == */* ]]; then
    printf '%s' "${name/#\~/$HOME}"
    return
  fi
  local candidate
  if [[ -n "$cdir" ]]; then
    candidate="$cdir/.claude/bottomline/bars/${name}.sh"
    [[ -f "$candidate" ]] && printf '%s' "$candidate" && return
  fi
  candidate="$_BL_DIR/bars/${name}.sh"
  [[ -f "$candidate" ]] && printf '%s' "$candidate"
}

resolve_bar_color() {
  local val="$1" default_hex="$2"
  [[ -z "$val" || "$val" == "null" ]] && val="$default_hex"
  case "$val" in
    text)    printf '%s' "$FG_TEXT"   ;;
    accent)  printf '%s' "$FG_ACCENT" ;;
    warning) printf '%s' "$FG_WARN"   ;;
    danger)  printf '%s' "$FG_CRIT"   ;;
    \#*)     make_fg "$(hex_to_rgb "$val")" ;;
    *)       make_fg "$(hex_to_rgb "$default_hex")" ;;
  esac
}

_bl_resolve_param_val() {
  local v="$1"
  if [[ "$v" == "file:~/"* ]]; then
    local _fpath="${HOME}/${v:7}"
    [[ -f "$_fpath" ]] && tr -d '\n' < "$_fpath" || printf ''
  elif [[ "$v" == "file:/"* ]]; then
    local _fpath="${v:5}"
    [[ -f "$_fpath" ]] && tr -d '\n' < "$_fpath" || printf ''
  else
    printf '%s' "$v"
  fi
}

_bl_export_bar_env() {
  export BOTTOMLINE_TEXT_HEX="$CFG_TEXT_HEX"   BOTTOMLINE_ACCENT_HEX="$CFG_ACCENT_HEX"
  export BOTTOMLINE_WARN_HEX="$CFG_WARN_HEX"   BOTTOMLINE_DANGER_HEX="$CFG_CRIT_HEX"
  export BOTTOMLINE_BG_R="${C_R[0]}" BOTTOMLINE_BG_G="${C_G[0]}" BOTTOMLINE_BG_B="${C_B[0]}"
  export BOTTOMLINE_SEP="$SEP" BOTTOMLINE_BOLD="$B" BOTTOMLINE_RESET="$R"
  export BOTTOMLINE_ICON_TYPE="$CFG_ICON_TYPE"
  export BOTTOMLINE_IC_DANGER="$IC_DANGER"
  export BOTTOMLINE_PROJECT_DIR="$cdir"
  export BOTTOMLINE_GRADIENT="$CFG_BG"
  export BOTTOMLINE_LIB="$_BL_DIR/lib"
}

_bl_resolve_bar_colors() {
  local bar="$1"
  local _colors_type
  _colors_type=$(printf '%s' "$bar" | jq -r '.colors | type' 2>/dev/null)
  if [[ "$_colors_type" == "object" ]]; then
    export BOTTOMLINE_BAR_COLORS=1
    local _v
    _v=$(printf '%s' "$bar" | jq -r '.colors.text       // empty')
    if [[ -n "$_v" ]]; then
      BOTTOMLINE_TEXT_HEX=$(resolve_color_hex "$_v"); export BOTTOMLINE_TEXT_HEX
    fi
    _v=$(printf '%s' "$bar" | jq -r '.colors.accent     // empty')
    if [[ -n "$_v" ]]; then
      BOTTOMLINE_ACCENT_HEX=$(resolve_color_hex "$_v"); export BOTTOMLINE_ACCENT_HEX
    fi
    _v=$(printf '%s' "$bar" | jq -r '.colors.warning    // empty')
    if [[ -n "$_v" ]]; then
      BOTTOMLINE_WARN_HEX=$(resolve_color_hex "$_v"); export BOTTOMLINE_WARN_HEX
    fi
    _v=$(printf '%s' "$bar" | jq -r '.colors.danger     // empty')
    if [[ -n "$_v" ]]; then
      BOTTOMLINE_DANGER_HEX=$(resolve_color_hex "$_v"); export BOTTOMLINE_DANGER_HEX
    fi
    local _bg_raw
    _bg_raw=$(printf '%s' "$bar" | jq -c '.colors.background // empty')
    if [[ -n "$_bg_raw" ]]; then
      if [[ "$(printf '%s' "$_bg_raw" | jq -r 'type' 2>/dev/null)" == "array" ]]; then
        export BOTTOMLINE_GRADIENT="$_bg_raw"
        local _first _r _g _b
        _first=$(printf '%s' "$_bg_raw" | jq -r '.[0]' 2>/dev/null)
        [[ -n "$_first" ]] && read -r _r _g _b <<< "$(hex_to_rgb "$_first")" \
          && export BOTTOMLINE_BG_R="$_r" BOTTOMLINE_BG_G="$_g" BOTTOMLINE_BG_B="$_b"
      else
        local _bg_hex _r _g _b
        _bg_hex=$(resolve_color_hex "$(printf '%s' "$_bg_raw" | jq -r '.')")
        read -r _r _g _b <<< "$(hex_to_rgb "$_bg_hex")"
        export BOTTOMLINE_BG_R="$_r" BOTTOMLINE_BG_G="$_g" BOTTOMLINE_BG_B="$_b"
        export BOTTOMLINE_GRADIENT="\"$_bg_hex\""
      fi
    fi
  elif [[ "$_colors_type" == "string" ]]; then
    export BOTTOMLINE_BAR_COLORS=1
  fi
}

_bl_resolve_bar_params() {
  local bar="$1"
  local _rm
  _rm=$(printf '%s' "$bar" | jq -r '.refresh_minutes // empty' 2>/dev/null)
  if [[ "$_rm" =~ ^[0-9]+$ ]]; then
    export BOTTOMLINE_BAR_REFRESH_MINUTES="$_rm"
  else
    unset BOTTOMLINE_BAR_REFRESH_MINUTES
  fi

  local _params_raw
  _params_raw=$(printf '%s' "$bar" | jq -c '.params // empty' 2>/dev/null)
  if [[ -n "$_params_raw" && "$_params_raw" != 'null' ]]; then
    local _params_resolved='{}' _pk _pt _pv _rv
    while IFS= read -r _pk; do
      _pt=$(printf '%s' "$_params_raw" | jq -r --arg k "$_pk" '.[$k] | type')
      if [[ "$_pt" == "string" ]]; then
        _pv=$(printf '%s' "$_params_raw" | jq -r --arg k "$_pk" '.[$k]')
        _rv=$(_bl_resolve_param_val "$_pv")
        _params_resolved=$(printf '%s' "$_params_resolved" \
          | jq -c --arg k "$_pk" --arg v "$_rv" '.[$k] = $v')
      else
        _rv=$(printf '%s' "$_params_raw" | jq -c --arg k "$_pk" '.[$k]')
        _params_resolved=$(printf '%s' "$_params_resolved" \
          | jq -c --arg k "$_pk" --argjson v "$_rv" '.[$k] = $v')
      fi
    done < <(printf '%s' "$_params_raw" | jq -r 'keys[]')
    export BOTTOMLINE_BAR_PARAMS="$_params_resolved"
  else
    unset BOTTOMLINE_BAR_PARAMS
  fi

  local _bar_segs
  _bar_segs=$(printf '%s' "$bar" | jq -c '.segments // empty' 2>/dev/null)
  if [[ -n "$_bar_segs" \
        && "$(printf '%s' "$_bar_segs" | jq -r 'type' 2>/dev/null)" == "array" ]]; then
    export BOTTOMLINE_BAR_SEGMENTS="$_bar_segs"
  else
    unset BOTTOMLINE_BAR_SEGMENTS
  fi
}

_bl_render_inline_bar() {
  local bar="$1"
  local seg_count
  seg_count=$(printf '%s' "$bar" | jq '.segments | length' 2>/dev/null || echo 0)
  (( seg_count == 0 )) && return

  local _bar_colors_type _bar_text_hex _bar_accent_hex _bar_bg
  _bar_colors_type=$(printf '%s' "$bar" | jq -r '.colors | type' 2>/dev/null)
  _bar_text_hex="$CFG_TEXT_HEX"
  _bar_accent_hex="$CFG_ACCENT_HEX"
  _bar_bg="$CFG_BG"
  if [[ "$_bar_colors_type" == "object" ]]; then
    local _v _bg_raw
    _v=$(printf '%s' "$bar" | jq -r '.colors.text       // empty')
    [[ -n "$_v" ]] && _bar_text_hex=$(resolve_color_hex "$_v")
    _v=$(printf '%s' "$bar" | jq -r '.colors.accent     // empty')
    [[ -n "$_v" ]] && _bar_accent_hex=$(resolve_color_hex "$_v")
    _bg_raw=$(printf '%s' "$bar" | jq -c '.colors.background // empty')
    if [[ -n "$_bg_raw" ]]; then
      if [[ "$(printf '%s' "$_bg_raw" | jq -r 'type' 2>/dev/null)" == "array" ]]; then
        _bar_bg="$_bg_raw"
      else
        _bar_bg="\"$(resolve_color_hex "$(printf '%s' "$_bg_raw" | jq -r '.')")\""
      fi
    fi
  fi

  _sc=()

  local si segment
  for ((si=0; si<seg_count; si++)); do
    segment=$(printf '%s' "$bar" | jq -c ".segments[$si]" 2>/dev/null)
    [[ -z "$segment" || "$segment" == "null" ]] && continue

    local seg_fg_text seg_fg_accent
    seg_fg_text=$(resolve_bar_color \
      "$(printf '%s' "$segment" | jq -r '.colors.text   // empty')" "$_bar_text_hex")
    seg_fg_accent=$(resolve_bar_color \
      "$(printf '%s' "$segment" | jq -r '.colors.accent // empty')" "$_bar_accent_hex")

    local icon_raw icon_val
    icon_raw=$(printf '%s' "$segment" | jq -r '.icon // empty')
    if [[ "${icon_raw:0:1}" == "{" ]]; then
      icon_val=$(printf '%s' "$segment" | jq -r --arg t "$CFG_ICON_TYPE" '.icon[$t] // ""')
      [[ "$CFG_ICON_TYPE" == "none" ]] && icon_val=""
    else
      icon_val=$(get_icon "$icon_raw")
    fi

    local seg_ansi content_text content_file content_script seg_content
    seg_ansi=$(printf '%s' "$segment" | jq -r '.ansi // false')
    content_text=$(printf '%s'   "$segment" | jq -r '.content // empty')
    content_file=$(printf '%s'   "$segment" | jq -r '.file    // empty')
    content_script=$(printf '%s' "$segment" | jq -r '.script  // empty')

    seg_content=''
    if [[ -n "$content_text" && "$content_text" != "null" ]]; then
      seg_content="$content_text"
    elif [[ -n "$content_file" && "$content_file" != "null" ]]; then
      content_file="${content_file/#\~/$HOME}"
      [[ -f "$content_file" ]] && seg_content=$(< "$content_file")
    elif [[ -n "$content_script" && "$content_script" != "null" ]]; then
      content_script=$(resolve_bar_script "$content_script")
      [[ -n "$content_script" ]] && seg_content=$(bash "$content_script")
    fi
    [[ -z "$seg_content" ]] && continue

    local local_icon=''
    [[ -n "$icon_val" ]] && local_icon="${seg_fg_accent}${icon_val} "

    if [[ "$seg_ansi" == "true" ]]; then
      seg "${local_icon}${seg_content}"
    else
      seg "${local_icon}${seg_fg_text}${seg_content}"
    fi
  done

  (( ${#_sc[@]} == 0 )) && return
  printf '\n'
  flush "$_bar_bg"
}

bl_render_bars() {
  local bar_count
  bar_count=$(printf '%s' "$CFG_BARS" | jq 'length' 2>/dev/null || echo 0)
  (( bar_count == 0 )) && return

  _bl_export_bar_env

  local bi bar bar_script script_path
  for ((bi=0; bi<bar_count; bi++)); do
    bar=$(printf '%s' "$CFG_BARS" | jq -c ".[$bi]" 2>/dev/null)
    [[ -z "$bar" || "$bar" == "null" ]] && continue

    bar_script=$(printf '%s' "$bar" | jq -r '.script // empty')

    if [[ -n "$bar_script" ]]; then
      script_path=$(resolve_bar_script "$bar_script")
      [[ -z "$script_path" ]] && continue
      printf '\n'
      (
        _bl_resolve_bar_colors "$bar"
        _bl_resolve_bar_params "$bar"
        bash "$script_path"
      )
      continue
    fi

    _bl_render_inline_bar "$bar"
  done
}
