#!/usr/bin/env bash
# Bottomline bar: Python ecosystem bar
# Renders for projects with pyproject.toml, requirements.txt, Pipfile, or setup.py.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
if [[ "$_bl_ttl" -gt 0 ]]; then
  _bl_cache=$(bl_cache_path "python" "$_bl_ttl" "$PROJ")
  [[ -f "$_bl_cache" ]] && cat "$_bl_cache" && exit 0
fi

has_pyproject=false has_requirements=false has_pipfile=false has_setup=false
[[ -f "$PROJ/pyproject.toml" ]]   && has_pyproject=true
[[ -f "$PROJ/requirements.txt" ]] && has_requirements=true
[[ -f "$PROJ/Pipfile" ]]          && has_pipfile=true
[[ -f "$PROJ/setup.py" ]]         && has_setup=true
$has_pyproject || $has_requirements || $has_pipfile || $has_setup || exit 0

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
    IC_TEST=$'\xef\x81\x80'      # U+F040  nf-fa-pencil
    IC_QUEUE=$'\xef\x83\xa2'     # U+F0E2  nf-fa-history
    IC_DB=$'\xef\x87\x80'        # U+F1C0  nf-fa-database
    IC_LINT=$'\xef\x80\x8c'      # U+F00C  nf-fa-check
    IC_TYPE=$'\xef\x80\xae'      # U+F02E  nf-fa-bookmark
    ;;
  emoji)
    IC_PYTHON='🐍'
    IC_DJANGO='🌿'
    IC_FLASK='🍶'
    IC_FASTAPI='⚡'
    IC_POETRY='📦'
    IC_PIPENV='📦'
    IC_TEST='🧪' IC_QUEUE='📨' IC_DB='🗄' IC_LINT='✓' IC_TYPE='🔎'
    ;;
  *)
    IC_PYTHON='' IC_DJANGO='' IC_FLASK='' IC_FASTAPI='' IC_POETRY='' IC_PIPENV=''
    IC_TEST='' IC_QUEUE='' IC_DB='' IC_LINT='' IC_TYPE=''
    ;;
esac

# ── Python version detection (priority: .python-version → pyproject.toml → .tool-versions) ──
py_version=''
if [[ -f "$PROJ/.python-version" ]]; then
  py_version=$(awk '/^[0-9]/{print; exit}' "$PROJ/.python-version" 2>/dev/null)
elif [[ -f "$PROJ/pyproject.toml" ]]; then
  py_version=$(awk -F'"' '/requires-python/{print $2; exit}' "$PROJ/pyproject.toml" 2>/dev/null | sed 's/[^0-9.]//g')
fi
if [[ -z "$py_version" && -f "$PROJ/.tool-versions" ]]; then
  py_version=$(awk '/^python /{print $2; exit}' "$PROJ/.tool-versions" 2>/dev/null)
fi

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

# ── Detect testing + tooling ──────────────────────────────────────────────────
# Single combined source for lockfile-driven deps: poetry.lock | pdm.lock | uv.lock | requirements.txt | pyproject.toml
_deps_file=''
for _df in poetry.lock pdm.lock uv.lock requirements.txt pyproject.toml; do
  [[ -f "$PROJ/$_df" ]] && _deps_file="$PROJ/$_df" && break
done

has_pytest=false
has_celery=false
has_sqlalchemy=false
has_ruff=false
has_mypy=false

if [[ -n "$_deps_file" ]]; then
  grep -Eqi '(^|[^a-z])pytest([^a-z]|$)' "$_deps_file" 2>/dev/null && has_pytest=true
  grep -Eqi '(^|[^a-z])celery([^a-z]|$)' "$_deps_file" 2>/dev/null && has_celery=true
  grep -Eqi '(^|[^a-z])sqlalchemy([^a-z]|$)' "$_deps_file" 2>/dev/null && has_sqlalchemy=true
  grep -Eqi '(^|[^a-z])ruff([^a-z]|$)' "$_deps_file" 2>/dev/null && has_ruff=true
  grep -Eqi '(^|[^a-z])mypy([^a-z]|$)' "$_deps_file" 2>/dev/null && has_mypy=true
fi

# Config-file fallbacks
! $has_pytest && [[ -f "$PROJ/pytest.ini" ]] && has_pytest=true
[[ -f "$PROJ/ruff.toml" || -f "$PROJ/.ruff.toml" ]] && has_ruff=true
[[ -f "$PROJ/mypy.ini" || -f "$PROJ/.mypy.ini" ]] && has_mypy=true

# SQLAlchemy is suppressed when Django is present (Django ORM is the primary)
[[ -n "${django_version:-}" ]] && has_sqlalchemy=false
unset _df _deps_file

# ── Version detection for testing + tooling ───────────────────────────────────
pytest_version=''
celery_version=''
sqlalchemy_version=''
ruff_version=''
mypy_version=''
$has_pytest     && pytest_version=$(pkg_version "pytest")
$has_celery     && celery_version=$(pkg_version "celery")
$has_sqlalchemy && sqlalchemy_version=$(pkg_version "sqlalchemy")
$has_ruff       && ruff_version=$(pkg_version "ruff")
$has_mypy       && mypy_version=$(pkg_version "mypy")

_bl_out=$(
  # ── Python runtime ────────────────────────────────────────────────────────────
  python_seg="${FG_ACCENT}${IC_PYTHON} ${FG_TEXT}Python"
  [[ -n "$py_version" ]] && python_seg+=" ${FG_ACCENT}v${py_version}"
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

  # Slot 5: Testing
  if $has_pytest; then
    pt_seg="${FG_ACCENT}${IC_TEST} ${FG_TEXT}pytest"
    [[ -n "$pytest_version" ]] && pt_seg+=" ${FG_ACCENT}v${pytest_version}"
    add_seg "$pt_seg"
  fi

  # Slot 6: Tooling (order: ruff → mypy → Celery → SQLAlchemy)
  if $has_ruff; then
    r_seg="${FG_ACCENT}${IC_LINT} ${FG_TEXT}ruff"
    [[ -n "$ruff_version" ]] && r_seg+=" ${FG_ACCENT}v${ruff_version}"
    add_seg "$r_seg"
  fi
  if $has_mypy; then
    m_seg="${FG_ACCENT}${IC_TYPE} ${FG_TEXT}mypy"
    [[ -n "$mypy_version" ]] && m_seg+=" ${FG_ACCENT}v${mypy_version}"
    add_seg "$m_seg"
  fi
  if $has_celery; then
    c_seg="${FG_ACCENT}${IC_QUEUE} ${FG_TEXT}Celery"
    [[ -n "$celery_version" ]] && c_seg+=" ${FG_ACCENT}v${celery_version}"
    add_seg "$c_seg"
  fi
  if $has_sqlalchemy; then
    s_seg="${FG_ACCENT}${IC_DB} ${FG_TEXT}SQLAlchemy"
    [[ -n "$sqlalchemy_version" ]] && s_seg+=" ${FG_ACCENT}v${sqlalchemy_version}"
    add_seg "$s_seg"
  fi

  (( ${#_sc[@]} == 0 )) && exit 0
  flush "$_bar_gradient"
)
if [[ "$_bl_ttl" -gt 0 ]]; then
  bl_cache_write "$_bl_cache" "$_bl_out"
fi
printf '%s' "$_bl_out"
