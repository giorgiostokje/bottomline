#!/usr/bin/env bash
# Bottomline bar: Python ecosystem bar
# Renders for projects with pyproject.toml, requirements.txt, Pipfile, or setup.py.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

has_pyproject=false has_requirements=false has_pipfile=false has_setup=false
[[ -f "$PROJ/pyproject.toml" ]]   && has_pyproject=true
[[ -f "$PROJ/requirements.txt" ]] && has_requirements=true
[[ -f "$PROJ/Pipfile" ]]          && has_pipfile=true
[[ -f "$PROJ/setup.py" ]]         && has_setup=true
$has_pyproject || $has_requirements || $has_pipfile || $has_setup || exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#c8dff0")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#ffd740")")
  _bar_gradient='["#0c1e30","#183352"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_PYTHON=$'\xee\x98\x86'   # U+E606  nf-seti-python
    IC_DJANGO=$'\xef\x81\xac'   # U+F06C  nf-fa-leaf  (Django's green leaf logo)
    IC_FLASK=$'\xef\x83\x83'    # U+F0C3  nf-fa-flask
    IC_FASTAPI=$'\xef\x83\xa7'  # U+F0E7  nf-fa-bolt
    IC_POETRY=$'\xef\x83\x90'   # U+F0D0  nf-fa-diamond
    IC_PIPENV=$'\xef\x84\xa1'   # U+F121  nf-fa-code
    ;;
  emoji)
    IC_PYTHON='🐍'
    IC_DJANGO='🌿'
    IC_FLASK='🍶'
    IC_FASTAPI='⚡'
    IC_POETRY='📦'
    IC_PIPENV='📦'
    ;;
  *)
    IC_PYTHON='' IC_DJANGO='' IC_FLASK='' IC_FASTAPI='' IC_POETRY='' IC_PIPENV=''
    ;;
esac


# ── Detect package manager / tool ─────────────────────────────────────────────
tool_label=''
tool_icon=''

if $has_pyproject; then
  if grep -q '^\[tool\.poetry\]' "$PROJ/pyproject.toml" 2>/dev/null; then
    tool_label='Poetry'; tool_icon="$IC_POETRY"
  elif grep -q '^\[tool\.pdm\]' "$PROJ/pyproject.toml" 2>/dev/null; then
    tool_label='PDM'; tool_icon="$IC_POETRY"
  elif grep -q '^\[tool\.hatch\]' "$PROJ/pyproject.toml" 2>/dev/null; then
    tool_label='Hatch'; tool_icon="$IC_POETRY"
  fi
elif $has_pipfile; then
  tool_label='Pipenv'; tool_icon="$IC_PIPENV"
fi

# ── Detect framework and version ──────────────────────────────────────────────
# Returns version from poetry.lock, Pipfile.lock, or requirements.txt.
pkg_version() {
  local pkg="$1"
  local lock ver

  lock="$PROJ/poetry.lock"
  if [[ -f "$lock" ]]; then
    ver=$(awk -v p="$pkg" '
      /^\[\[package\]\]/ { name=""; ver="" }
      /^name = / { gsub(/"/, ""); name=substr($0, 9) }
      /^version = / { gsub(/"/, ""); ver=substr($0, 12) }
      name==p && ver!="" { print ver; exit }
    ' "$lock" 2>/dev/null)
    [[ -n "$ver" ]] && printf '%s' "$ver" && return
  fi

  lock="$PROJ/Pipfile.lock"
  if [[ -f "$lock" ]]; then
    ver=$(jq -r --arg p "$pkg" '.default[$p].version // empty' "$lock" 2>/dev/null | sed 's/^==//')
    [[ -n "$ver" ]] && printf '%s' "$ver" && return
  fi

  lock="$PROJ/requirements.txt"
  if [[ -f "$lock" ]]; then
    ver=$(grep -iE "^${pkg}[>=<!~\[]" "$lock" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
    [[ -n "$ver" ]] && printf '%s' "$ver" && return
  fi
}

has_django=false has_flask=false has_fastapi=false
django_version='' flask_version='' fastapi_version=''

# Scan all dependency sources for known frameworks.
_all_deps=''
$has_pyproject && _all_deps+=$(cat "$PROJ/pyproject.toml" 2>/dev/null)
$has_requirements && _all_deps+=$(cat "$PROJ/requirements.txt" 2>/dev/null)
$has_pipfile && _all_deps+=$(cat "$PROJ/Pipfile" 2>/dev/null)

if printf '%s' "$_all_deps" | grep -qiE 'django'; then
  has_django=true; django_version=$(pkg_version "django")
elif printf '%s' "$_all_deps" | grep -qiE 'fastapi'; then
  has_fastapi=true; fastapi_version=$(pkg_version "fastapi")
elif printf '%s' "$_all_deps" | grep -qiE 'flask'; then
  has_flask=true; flask_version=$(pkg_version "flask")
fi


# ── Python runtime ────────────────────────────────────────────────────────────
python_seg="${FG_ACCENT}${IC_PYTHON} ${FG_TEXT}Python"
[[ -n "$tool_label" ]] && python_seg+=" ${FG_ACCENT}[${FG_TEXT}${tool_icon}${tool_label}${FG_ACCENT}]"
add_seg "$python_seg"

# ── Framework ─────────────────────────────────────────────────────────────────
if $has_django; then
  fw_seg="${FG_ACCENT}${IC_DJANGO} ${FG_TEXT}Django"
  [[ -n "$django_version" ]] && fw_seg+=" ${FG_ACCENT}v${django_version}"
  add_seg "$fw_seg"
elif $has_fastapi; then
  fw_seg="${FG_ACCENT}${IC_FASTAPI} ${FG_TEXT}FastAPI"
  [[ -n "$fastapi_version" ]] && fw_seg+=" ${FG_ACCENT}v${fastapi_version}"
  add_seg "$fw_seg"
elif $has_flask; then
  fw_seg="${FG_ACCENT}${IC_FLASK} ${FG_TEXT}Flask"
  [[ -n "$flask_version" ]] && fw_seg+=" ${FG_ACCENT}v${flask_version}"
  add_seg "$fw_seg"
fi

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
