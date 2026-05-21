#!/usr/bin/env bash
# Claude Code status line — Bottomline plugin
# Config precedence (highest → lowest):
#   <project>/.claude/bottomline.json  — project overrides
#   ~/.claude/bottomline.json          — user overrides
#   <plugin-dir>/settings.json         — shipped defaults

input=$(cat)

# ── ANSI helpers ──────────────────────────────────────────────────────────────
bg3() { printf '\e[48;2;%d;%d;%dm' "$1" "$2" "$3"; }
fg3() { printf '\e[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
R=$'\e[0m'
B=$'\e[1m'
SEP=$'\xee\x82\xb4'   # U+E0B4 rounded right chevron (default; overridden by segments.separator)

# ── Nerd Font icon bytes ──────────────────────────────────────────────────────
NF_MODEL=$'\xef\x8b\x9b'   NF_BOLT=$'\xef\x83\xa7'   NF_CTX=$'\xef\x82\xae'
NF_DIR=$'\xef\x81\xbc'     NF_GIT=$'\xee\x82\xa0'    NF_UP=$'\xef\x81\xa2'
NF_DOWN=$'\xef\x81\xa3'    NF_CLOCK=$'\xef\x80\x97'  NF_CAL=$'\xef\x81\xb3'
NF_COST=$'\xef\x83\x96'    NF_WARN=$'\xef\x81\xb1'   NF_DANGER=$'\xef\x81\x9e'

# ── Emoji fallback icons ──────────────────────────────────────────────────────
EM_MODEL='🖥'  EM_BOLT='⚡'  EM_CTX='◈'   EM_DIR='📁'  EM_GIT='⎇'
EM_UP='↑'      EM_DOWN='↓'  EM_CLOCK='⏱' EM_CAL='📅'  EM_COST='💰'
EM_WARN='⚠'   EM_DANGER='🛑'

# ── Pure utilities ────────────────────────────────────────────────────────────
_BL_DIR="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# shellcheck source=lib/functions.sh
source "$_BL_DIR/lib/functions.sh"

# ── Helpers ───────────────────────────────────────────────────────────────────
j()    { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }
link() { printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$1" "$2"; }

hex_to_rgb() {
  local h="${1#'#'}"
  [[ ${#h} -ne 6 ]] && printf '128 128 128' && return
  printf '%d %d %d' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}

make_fg() { local r g b; read -r r g b <<< "$1"; fg3 "$r" "$g" "$b"; }

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

# ── Config loading ────────────────────────────────────────────────────────────
cdir=$(j '.workspace.current_dir'); [[ -z "$cdir" ]] && cdir=$(j '.cwd')

SETTINGS_CFG="$_BL_DIR/settings.json"
USER_CFG="$HOME/.claude/bottomline.json"
PROJ_CFG=""
[[ -n "$cdir" && -f "$cdir/.claude/bottomline.json" ]] && PROJ_CFG="$cdir/.claude/bottomline.json"

# Deep-merge all three config layers: settings < user < project.
# Objects are merged recursively — a partial object in a higher-priority file
# fills in only the keys it defines; the rest fall through from lower layers.
# Arrays and scalars: the highest-priority non-null value wins entirely.
_s_json=$(jq '.' "$SETTINGS_CFG" 2>/dev/null || printf '{}')
_u_json='null'; [[ -f "$USER_CFG" ]]  && _u_json=$(jq '.' "$USER_CFG"  2>/dev/null || printf 'null')
_p_json='null'; [[ -n "$PROJ_CFG" ]]  && _p_json=$(jq '.' "$PROJ_CFG"  2>/dev/null || printf 'null')

MERGED_CFG=$(jq -n \
  --argjson s "$_s_json" --argjson u "$_u_json" --argjson p "$_p_json" '
    def dmerge(a; b):
      if b == null then a
      elif (a | type) == "object" and (b | type) == "object"
      then reduce (b | keys_unsorted[]) as $k (a; .[$k] = dmerge(a[$k]; b[$k]))
      else b
      end;
    dmerge(dmerge($s; $u); $p)
  ' 2>/dev/null || printf '{}')
unset _s_json _u_json _p_json

cfg_str()  { printf '%s' "$MERGED_CFG" | jq -r "$1 // empty" 2>/dev/null; }
cfg_json() { printf '%s' "$MERGED_CFG" | jq -c "$1 // empty" 2>/dev/null; }

# ── Read config (defaults live in <plugin-dir>/settings.json) ────────────────
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

# ── Theme ─────────────────────────────────────────────────────────────────────
# When a theme is set in any config file (project > user > settings), its
# colors take priority over all per-file color settings.
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

# ── Resolve colors ────────────────────────────────────────────────────────────
RGB_TEXT=$(hex_to_rgb   "$CFG_TEXT_HEX")
RGB_ACCENT=$(hex_to_rgb "$CFG_ACCENT_HEX")
RGB_WARN=$(hex_to_rgb   "$CFG_WARN_HEX")
RGB_CRIT=$(hex_to_rgb   "$CFG_CRIT_HEX")

FG_TEXT=$(make_fg "$RGB_TEXT")
FG_ACCENT=$(make_fg "$RGB_ACCENT")
FG_WARN=$(make_fg "$RGB_WARN")
FG_CRIT=$(make_fg "$RGB_CRIT")

# Resolve a named color reference or hex string back to its hex value.
resolve_color_hex() {
  case "$1" in
    text)         printf '%s' "$CFG_TEXT_HEX"   ;;
    accent)       printf '%s' "$CFG_ACCENT_HEX" ;;
    warn|warning) printf '%s' "$CFG_WARN_HEX"   ;;
    crit|danger)  printf '%s' "$CFG_CRIT_HEX"   ;;
    *)            printf '%s' "$1" ;;
  esac
}

# Resolve a named/hex color spec to an ANSI fg escape
resolve_color() {
  case "$1" in
    text)            printf '%s' "$FG_TEXT"   ;;
    accent)          printf '%s' "$FG_ACCENT" ;;
    warn|warning)    printf '%s' "$FG_WARN"   ;;
    crit|danger)     printf '%s' "$FG_CRIT"   ;;
    \#*)             make_fg "$(hex_to_rgb "$1")" ;;
    *)               printf '%s' "$FG_TEXT"   ;;
  esac
}

# ── Background expansion ─────────────────────────────────────────────────────
# Expands colors.background (a hex string or an array of K keyframes) into a
# JSON array of exactly N hex stops via piecewise linear RGB interpolation.
# Keyframes are evenly distributed at positions 0, 1/(K-1), ..., 1.
expand_bg() {
  local cfg="$1" n_out="${2:-8}"
  local bg_type
  bg_type=$(printf '%s' "$cfg" | jq -r 'type' 2>/dev/null)

  case "$bg_type" in
    string)
      local hex; hex=$(printf '%s' "$cfg" | jq -r '.')
      printf '%s' "$hex" | awk -v n="$n_out" '{ h=$0; printf "["; for(i=0;i<n;i++){if(i)printf ","; printf "\"" h "\""} printf "]" }'
      ;;
    array)
      printf '%s' "$cfg" | jq -r '.[]' | awk -v n_out="$n_out" '
        function h2d(h,   i,c,v) {
          v = 0
          for (i = 1; i <= length(h); i++) {
            c = substr(h, i, 1)
            if      (c ~ /[0-9]/) v = v*16 + c+0
            else if (c ~ /[a-f]/) v = v*16 + index("abcdef",c)+9
            else if (c ~ /[A-F]/) v = v*16 + index("ABCDEF",c)+9
          }
          return v
        }
        { colors[NR-1] = $0 }
        END {
          k = NR
          if (k == 0) { printf "["; for(i=0;i<n_out;i++){if(i)printf ","; printf "\"#0F0F0F\""}; printf "]"; exit }
          if (k == 1) { printf "["; for(i=0;i<n_out;i++){if(i)printf ","; printf "\"" colors[0] "\""} ; printf "]"; exit }
          printf "["
          for (i = 0; i < n_out; i++) {
            if (i) printf ","
            t   = (n_out > 1) ? i / (n_out - 1.0) : 0
            pos = t * (k - 1)
            seg = int(pos); if (seg >= k-1) seg = k-2
            frac = pos - seg
            c1 = substr(colors[seg],   2)
            c2 = substr(colors[seg+1], 2)
            r = int(h2d(substr(c1,1,2)) + (h2d(substr(c2,1,2)) - h2d(substr(c1,1,2))) * frac + 0.5)
            g = int(h2d(substr(c1,3,2)) + (h2d(substr(c2,3,2)) - h2d(substr(c1,3,2))) * frac + 0.5)
            b = int(h2d(substr(c1,5,2)) + (h2d(substr(c2,5,2)) - h2d(substr(c1,5,2))) * frac + 0.5)
            printf "\"#%02X%02X%02X\"", r, g, b
          }
          printf "]"
        }
      '
      ;;
    *)
      printf '["#0F0F0F","#0F0F0F","#0F0F0F","#0F0F0F","#0F0F0F","#0F0F0F","#0F0F0F","#0F0F0F"]'
      ;;
  esac
}

# ── Background: C_R[0..7] C_G[0..7] C_B[0..7] ───────────────────────────────
CFG_BG_EXP=$(expand_bg "$CFG_BG" 8)
declare -a C_R C_G C_B
for _i in $(seq 0 7); do
  _hex=$(printf '%s' "$CFG_BG_EXP" | jq -r ".[$_i]" 2>/dev/null)
  [[ -z "$_hex" ]] && _hex='#0F0F0F'
  read -r "C_R[$_i]" "C_G[$_i]" "C_B[$_i]" <<< "$(hex_to_rgb "$_hex")"
done
unset _i _hex

# ── Icons ─────────────────────────────────────────────────────────────────────
get_icon() {
  local name="$1" override
  override=$(printf '%s' "$CFG_ICON_OVR" | jq -r --arg n "$name" '.[$n] // empty' 2>/dev/null)
  # tokens_in/tokens_out fall back to the shared 'tokens' override key
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

IC_MODEL=$(get_icon model)         IC_EFFORT=$(get_icon effort)       IC_CONTEXT=$(get_icon context)
IC_DIRECTORY=$(get_icon directory) IC_GIT_BRANCH=$(get_icon git_branch)
IC_TOKENS_IN=$(get_icon tokens_in) IC_TOKENS_OUT=$(get_icon tokens_out)
IC_USAGE_5H=$(get_icon usage_5h)   IC_USAGE_7D=$(get_icon usage_7d)
IC_COST=$(get_icon cost)           IC_DANGER=$(get_icon danger)

# Resolve segments.separator — reuses decode_icon for hex codepoint support.
[[ -n "$CFG_SEP_RAW" ]] && SEP=$(decode_icon "$CFG_SEP_RAW")

# ── Gauge ─────────────────────────────────────────────────────────────────────
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

# ── Threshold resolver ────────────────────────────────────────────────────────
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

# ── Segment engine ────────────────────────────────────────────────────────────
# seg stores content only. flush expands the gradient to exactly N stops at
# render time, so the first and last keyframe colors always land on the first
# and last segment regardless of how many segments are present.
declare -a _sc
seg() { _sc+=("$1"); }
flush() {
  local gradient_json="$1"
  local n=${#_sc[@]}
  (( n == 0 )) && return
  local expanded i hex r g b
  expanded=$(expand_bg "$gradient_json" "$n")
  declare -a fr fg fb
  for ((i=0; i<n; i++)); do
    hex=$(printf '%s' "$expanded" | jq -r ".[$i]" 2>/dev/null)
    [[ -z "$hex" ]] && hex='#0F0F0F'
    read -r fr[$i] fg[$i] fb[$i] <<< "$(hex_to_rgb "$hex")"
  done
  for ((i=0; i<n; i++)); do
    r=${fr[$i]} g=${fg[$i]} b=${fb[$i]}
    printf '%s' "$(bg3 "$r" "$g" "$b") ${B}${_sc[$i]}$(bg3 "$r" "$g" "$b") "
    if (( i + 1 < n )); then
      printf '%s' "$(fg3 "$r" "$g" "$b")$(bg3 "${fr[$((i+1))]}" "${fg[$((i+1))]}" "${fb[$((i+1))]}")${SEP}"
    else
      printf '%s' "${R}$(fg3 "$r" "$g" "$b")${SEP}${R}"
    fi
  done
}

# ── Extract JSON input fields ─────────────────────────────────────────────────
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

# ── Segment builders ──────────────────────────────────────────────────────────
add_seg() { seg "$1"; }

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
  (( sum_cache_read > 0 )) && tok+="${FG_ACCENT}+$(fmt_n "$sum_cache_read")"
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
  [[ -n "$five_rem" ]] && lbl+=" ${FG_ACCENT}$(fmt_remaining "$five_rem")" || lbl+="${FG_ACCENT}/5h"
  add_seg "$lbl"
}

build_usage_7d() {
  [[ -z "$week_pct" ]] && return
  local week_int; week_int=$(printf '%.0f' "$week_pct")
  threshold_resolve "$CFG_USAGE_THR" "$week_int"
  local lbl="${FG_ACCENT}${IC_USAGE_7D} ${THR_COLOR_ANSI}${week_int}%"
  [[ -n "$week_rem" ]] && lbl+=" ${FG_ACCENT}$(fmt_remaining "$week_rem")" || lbl+="${FG_ACCENT}/7d"
  add_seg "$lbl"
}

build_cost() {
  (( sum_in + sum_out + sum_cache_read + sum_cache_create <= 0 )) && return
  local price_in price_out price_cache_read price_cache_write
  case "$model" in
    *Opus*)
      price_in=15; price_out=75; price_cache_read=1.5; price_cache_write=18.75 ;;
    *Haiku*)
      price_in=0.80; price_out=4; price_cache_read=0.08; price_cache_write=1.0 ;;
    *)
      price_in=3; price_out=15; price_cache_read=0.30; price_cache_write=3.75 ;;
  esac
  local cost_fmt
  cost_fmt=$(awk \
    -v in_tok="$sum_in"  -v out_tok="$sum_out" \
    -v cr="$sum_cache_read" -v cw="$sum_cache_create" \
    -v pi="$price_in"    -v po="$price_out" \
    -v pcr="$price_cache_read" -v pcw="$price_cache_write" \
    'BEGIN {
      c = (in_tok*pi + out_tok*po + cr*pcr + cw*pcw) / 1000000
      if (c < 0.005) printf "< $0.01"
      else           printf "$%.2f", c
    }')
  add_seg "${FG_ACCENT}${IC_COST} ${FG_TEXT}${cost_fmt}"
}

# ── Render items in configured order ─────────────────────────────────────────
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

# ── Project-aware bar auto-detection ─────────────────────────────────────────
# Bar scripts are prepended automatically when their signal files are found in
# the project root, unless the bar is already listed in the bars config.
# The list of bars and their detection signals is defined in auto_bars (in
# settings.json), so it can be extended or reordered at any config level.
_auto_bars_enabled=$(printf '%s' "$MERGED_CFG" | jq -r 'if .auto_bars.enabled == false then "false" else "true" end' 2>/dev/null)
if [[ "$_auto_bars_enabled" != "false" && -n "$cdir" ]]; then
  [[ -z "$CFG_BARS" || "$CFG_BARS" == "null" ]] && CFG_BARS='[]'

  _auto_bars_cfg=$(cfg_json '.auto_bars.scripts')
  [[ -z "$_auto_bars_cfg" || "$_auto_bars_cfg" == "null" ]] && _auto_bars_cfg='[]'

  # auto_bars.disabled accumulates across all config levels (union) so that a
  # project can add its own exclusions without re-listing the user's exclusions.
  _d_s=$(jq -c '.auto_bars.disabled // empty' "$SETTINGS_CFG" 2>/dev/null)
  _d_u=''; [[ -f "$USER_CFG" ]]  && _d_u=$(jq -c '.auto_bars.disabled // empty' "$USER_CFG"  2>/dev/null)
  _d_p=''; [[ -n "$PROJ_CFG" ]] && _d_p=$(jq -c '.auto_bars.disabled // empty' "$PROJ_CFG" 2>/dev/null)
  _disabled=$(jq -n \
    --argjson s "${_d_s:-[]}" --argjson u "${_d_u:-[]}" --argjson p "${_d_p:-[]}" \
    '($s + $u + $p) | unique' 2>/dev/null || printf '[]')
  unset _d_s _d_u _d_p

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

  _auto='[]'
  _entry_count=$(printf '%s' "$_auto_bars_cfg" | jq 'length' 2>/dev/null || echo 0)

  for (( _ei=0; _ei<_entry_count; _ei++ )); do
    _bar_name=$(printf '%s' "$_auto_bars_cfg" | jq -r ".[$_ei].script // empty" 2>/dev/null)
    [[ -z "$_bar_name" ]] && continue
    _is_explicit "$_bar_name" && continue
    _is_disabled "$_bar_name" && continue

    _matched=false
    while IFS= read -r _sig; do
      [[ -z "$_sig" ]] && continue
      if [[ -e "$cdir/$_sig" ]]; then _matched=true; break; fi
    done < <(printf '%s' "$_auto_bars_cfg" | jq -r ".[$_ei].signals[]? // empty" 2>/dev/null)

    if "$_matched"; then
      _bar_entry=$(printf '%s' "$_auto_bars_cfg" | jq -c ".[$_ei] | del(.signals)")
      [[ "$_inherit_colors" == "true" ]] && \
        _bar_entry=$(printf '%s' "$_bar_entry" | jq -c '.colors = "inherit"')
      _auto=$(printf '%s' "$_auto" | jq --argjson e "$_bar_entry" '. + [$e]')
    fi
  done

  if [[ "$_auto" != "[]" ]]; then
    CFG_BARS=$(printf '%s' "$_auto" | jq --argjson cfg "$CFG_BARS" '. + $cfg')
  fi

  unset -f _is_explicit _is_disabled
  unset _auto _auto_bars_cfg _entry_count _ei _bar_name _matched _sig _disabled _inherit_colors
fi
unset _auto_bars_enabled

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
        if [[ "$_rm" =~ ^[0-9]+$ && "$_rm" -gt 0 ]]; then
          export BOTTOMLINE_BAR_REFRESH_MINUTES="$_rm"
        else
          unset BOTTOMLINE_BAR_REFRESH_MINUTES
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
