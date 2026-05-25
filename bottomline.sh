#!/usr/bin/env bash
# Claude Code status line — Bottomline plugin
# Config precedence (highest → lowest):
#   <project>/.claude/bottomline.json  — project overrides
#   ~/.claude/bottomline.json          — user overrides
#   <plugin-dir>/settings.json         — shipped defaults

# ── ANSI helpers ──────────────────────────────────────────────────────────────
R=$'\e[0m'
B=$'\e[1m'

# ── Pure utilities ────────────────────────────────────────────────────────────
_BL_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=lib/functions.sh
source "$_BL_DIR/lib/functions.sh"
# shellcheck source=lib/ansi.sh
source "$_BL_DIR/lib/ansi.sh"
# shellcheck source=lib/config.sh
source "$_BL_DIR/lib/config.sh"
# shellcheck source=lib/colors.sh
source "$_BL_DIR/lib/colors.sh"
# shellcheck source=lib/icons.sh
source "$_BL_DIR/lib/icons.sh"
# shellcheck source=lib/state.sh
source "$_BL_DIR/lib/state.sh"
# shellcheck source=lib/segments.sh
source "$_BL_DIR/lib/segments.sh"
# shellcheck source=lib/auto-bars.sh
source "$_BL_DIR/lib/auto-bars.sh"

# ── Read state & init subsystems ─────────────────────────────────────────────
bl_read_state
bl_load_config
bl_init_colors
bl_init_icons
bl_render_main_line
bl_apply_auto_bars

# ── Bar helpers (used by bar execution loop) ─────────────────────────────────

# Resolve a bar script value to an executable path.
# Names containing "/" are treated as literal paths (~ expanded).
# Bare names (no slash) are searched as <name>.sh in:
#   <project>/.claude/bottomline/bars/ then <plugin-dir>/bars/
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

# Resolve a color value from a bar segment's colors object.
# Accepts named references (text/accent/warning/danger), hex strings, or falls
# back to the provided default hex when the value is absent/null.
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

# Resolve a single params value for a script bar:
#   file:~/path   → read from $HOME/path (tilde expanded, absolute only)
#   file:/abs     → read from /abs path
#   anything else → return as literal
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

# ── Bars ──────────────────────────────────────────────────────────────────────
bar_count=$(printf '%s' "$CFG_BARS" | jq 'length' 2>/dev/null || echo 0)

if (( bar_count > 0 )); then
  export BOTTOMLINE_TEXT_HEX="$CFG_TEXT_HEX"   BOTTOMLINE_ACCENT_HEX="$CFG_ACCENT_HEX"
  export BOTTOMLINE_WARN_HEX="$CFG_WARN_HEX"   BOTTOMLINE_DANGER_HEX="$CFG_CRIT_HEX"
  export BOTTOMLINE_BG_R="${C_R[0]}" BOTTOMLINE_BG_G="${C_G[0]}" BOTTOMLINE_BG_B="${C_B[0]}"
  export BOTTOMLINE_SEP="$SEP" BOTTOMLINE_BOLD="$B" BOTTOMLINE_RESET="$R"
  export BOTTOMLINE_ICON_TYPE="$CFG_ICON_TYPE"
  export BOTTOMLINE_IC_DANGER="$IC_DANGER"
  export BOTTOMLINE_PROJECT_DIR="$cdir"
  export BOTTOMLINE_GRADIENT="$CFG_BG"
  export BOTTOMLINE_LIB="$_BL_DIR/lib"

  for ((bi=0; bi<bar_count; bi++)); do
    bar=$(printf '%s' "$CFG_BARS" | jq -c ".[$bi]" 2>/dev/null)
    [[ -z "$bar" || "$bar" == "null" ]] && continue

    bar_script=$(printf '%s' "$bar" | jq -r '.script // empty')

    if [[ -n "$bar_script" ]]; then
      script_path=$(resolve_bar_script "$bar_script")
      [[ -z "$script_path" ]] && continue
      printf '\n'
      (
        # object = apply overrides; string ("inherit") or absent = use merged config colors
        # BOTTOMLINE_BAR_COLORS=1 tells bar scripts not to apply their built-in palette
        _colors_type=$(printf '%s' "$bar" | jq -r '.colors | type' 2>/dev/null)
        if [[ "$_colors_type" == "object" ]]; then
          export BOTTOMLINE_BAR_COLORS=1
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
          _bg_raw=$(printf '%s' "$bar" | jq -c '.colors.background // empty')
          if [[ -n "$_bg_raw" ]]; then
            if [[ "$(printf '%s' "$_bg_raw" | jq -r 'type' 2>/dev/null)" == "array" ]]; then
              export BOTTOMLINE_GRADIENT="$_bg_raw"
              _first=$(printf '%s' "$_bg_raw" | jq -r '.[0]' 2>/dev/null)
              [[ -n "$_first" ]] && read -r _r _g _b <<< "$(hex_to_rgb "$_first")" \
                && export BOTTOMLINE_BG_R="$_r" BOTTOMLINE_BG_G="$_g" BOTTOMLINE_BG_B="$_b"
            else
              _bg_hex=$(resolve_color_hex "$(printf '%s' "$_bg_raw" | jq -r '.')")
              read -r _r _g _b <<< "$(hex_to_rgb "$_bg_hex")"
              export BOTTOMLINE_BG_R="$_r" BOTTOMLINE_BG_G="$_g" BOTTOMLINE_BG_B="$_b"
              export BOTTOMLINE_GRADIENT="\"$_bg_hex\""
            fi
          fi
        elif [[ "$_colors_type" == "string" ]]; then
          export BOTTOMLINE_BAR_COLORS=1
        fi
        _rm=$(printf '%s' "$bar" | jq -r '.refresh_minutes // empty' 2>/dev/null)
        if [[ "$_rm" =~ ^[0-9]+$ ]]; then
          export BOTTOMLINE_BAR_REFRESH_MINUTES="$_rm"
        else
          unset BOTTOMLINE_BAR_REFRESH_MINUTES
        fi
        # ── params resolution ──────────────────────────────────────────────
        _params_raw=$(printf '%s' "$bar" | jq -c '.params // empty' 2>/dev/null)
        if [[ -n "$_params_raw" && "$_params_raw" != 'null' ]]; then
          _params_resolved='{}'
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

        # ── segments export ────────────────────────────────────────────────
        _bar_segs=$(printf '%s' "$bar" | jq -c '.segments // empty' 2>/dev/null)
        if [[ -n "$_bar_segs" \
              && "$(printf '%s' "$_bar_segs" | jq -r 'type' 2>/dev/null)" == "array" ]]; then
          export BOTTOMLINE_BAR_SEGMENTS="$_bar_segs"
        else
          unset BOTTOMLINE_BAR_SEGMENTS
        fi

        bash "$script_path"
      )
      continue
    fi

    seg_count=$(printf '%s' "$bar" | jq '.segments | length' 2>/dev/null || echo 0)
    (( seg_count == 0 )) && continue

    # Bar-level color defaults — "inherit" or absent = use merged config colors
    _bar_colors_type=$(printf '%s' "$bar" | jq -r '.colors | type' 2>/dev/null)
    _bar_text_hex="$CFG_TEXT_HEX"
    _bar_accent_hex="$CFG_ACCENT_HEX"
    _bar_bg="$CFG_BG"
    if [[ "$_bar_colors_type" == "object" ]]; then
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

    for ((si=0; si<seg_count; si++)); do
      segment=$(printf '%s' "$bar" | jq -c ".segments[$si]" 2>/dev/null)
      [[ -z "$segment" || "$segment" == "null" ]] && continue

      # Foreground colors — segment overrides bar defaults
      seg_fg_text=$(resolve_bar_color \
        "$(printf '%s' "$segment" | jq -r '.colors.text   // empty')" "$_bar_text_hex")
      seg_fg_accent=$(resolve_bar_color \
        "$(printf '%s' "$segment" | jq -r '.colors.accent // empty')" "$_bar_accent_hex")

      # Icon — flat string (named or literal) or per-type object
      icon_raw=$(printf '%s' "$segment" | jq -r '.icon // empty')
      if [[ "${icon_raw:0:1}" == "{" ]]; then
        icon_val=$(printf '%s' "$segment" | jq -r --arg t "$CFG_ICON_TYPE" '.icon[$t] // ""')
        [[ "$CFG_ICON_TYPE" == "none" ]] && icon_val=""
      else
        icon_val=$(get_icon "$icon_raw")
      fi

      # Content — content > file > script
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

      local_icon=''
      [[ -n "$icon_val" ]] && local_icon="${seg_fg_accent}${icon_val} "

      if [[ "$seg_ansi" == "true" ]]; then
        seg "${local_icon}${seg_content}"
      else
        seg "${local_icon}${seg_fg_text}${seg_content}"
      fi
    done

    (( ${#_sc[@]} == 0 )) && continue
    printf '\n'
    flush "$_bar_bg"
  done
fi
