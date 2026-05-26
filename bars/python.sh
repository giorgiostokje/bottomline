#!/usr/bin/env bash
# Bottomline bar: Python ecosystem bar
# Renders for projects with pyproject.toml, requirements.txt, Pipfile, or setup.py.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init python "#c8dff0" "#ffd740" '["#0c1e30","#183352"]' \
  "$PROJ/pyproject.toml" "$PROJ/requirements.txt" \
  "$PROJ/Pipfile" "$PROJ/Pipfile.lock" "$PROJ/poetry.lock" \
  "$PROJ/uv.lock"

has_pyproject=false has_requirements=false has_pipfile=false has_setup=false
[[ -f "$PROJ/pyproject.toml" ]]   && has_pyproject=true
[[ -f "$PROJ/requirements.txt" ]] && has_requirements=true
[[ -f "$PROJ/Pipfile" ]]          && has_pipfile=true
[[ -f "$PROJ/setup.py" ]]         && has_setup=true
$has_pyproject || $has_requirements || $has_pipfile || $has_setup || exit 0

bl_icon_set IC_PYTHON  $'\xee\x98\x86' '🐍'  # U+E606  nf-seti-python
bl_icon_set IC_DJANGO  $'\xef\x81\xac' '🌿'  # U+F06C  nf-fa-leaf  (Django's green leaf logo)
bl_icon_set IC_FLASK   $'\xef\x83\x83' '🍶'  # U+F0C3  nf-fa-flask
bl_icon_set IC_FASTAPI $'\xef\x83\xa7' '⚡'  # U+F0E7  nf-fa-bolt
bl_icon_set IC_POETRY  $'\xef\x83\x90' '📦'  # U+F0D0  nf-fa-diamond
bl_icon_set IC_PIPENV  $'\xef\x84\xa1' '📦'  # U+F121  nf-fa-code
bl_icon_set IC_TEST    $'\xef\x81\x80' '🧪'  # U+F040  nf-fa-pencil
bl_icon_set IC_QUEUE   $'\xef\x83\xa2' '📨'  # U+F0E2  nf-fa-history
bl_icon_set IC_DB      $'\xef\x87\x80' '🗄'  # U+F1C0  nf-fa-database
bl_icon_set IC_LINT    $'\xef\x80\x8c' '✓'   # U+F00C  nf-fa-check
bl_icon_set IC_TYPE    $'\xef\x80\xae' '🔎'  # U+F02E  nf-fa-bookmark
bl_icon_set IC_WEB     $'\xef\x83\xac' '🌐'  # U+F0EC  nf-fa-globe

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

if [[ -f "$PROJ/uv.lock" ]] || { $has_pyproject && grep -q '^\[tool\.uv\]' "$PROJ/pyproject.toml" 2>/dev/null; }; then
  tool_label='uv'; tool_icon="$IC_POETRY"
elif $has_pyproject; then
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

  lock="$PROJ/uv.lock"
  if [[ -f "$lock" ]]; then
    ver=$(awk -v p="$pkg" '
      /^\[\[package\]\]/ { name=""; ver="" }
      /^name = / { gsub(/"/, ""); name=substr($0, 9) }
      /^version = / { gsub(/"/, ""); ver=substr($0, 12) }
      name==p && ver!="" { print ver; exit }
    ' "$lock" 2>/dev/null)
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

# ── Detect add-ons ────────────────────────────────────────────────────────────
has_pydantic=false
has_httpx=false

printf '%s' "$_all_deps" | grep -qiE '(^|[^a-z])pydantic([^a-z]|$)' && has_pydantic=true
printf '%s' "$_all_deps" | grep -qiE '(^|[^a-z])httpx([^a-z]|$)' && has_httpx=true

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
has_black=false
has_isort=false
has_alembic=false

if [[ -n "$_deps_file" ]]; then
  grep -Eqi '(^|[^a-z])pytest([^a-z]|$)' "$_deps_file" 2>/dev/null && has_pytest=true
  grep -Eqi '(^|[^a-z])celery([^a-z]|$)' "$_deps_file" 2>/dev/null && has_celery=true
  grep -Eqi '(^|[^a-z])sqlalchemy([^a-z]|$)' "$_deps_file" 2>/dev/null && has_sqlalchemy=true
  grep -Eqi '(^|[^a-z])ruff([^a-z]|$)' "$_deps_file" 2>/dev/null && has_ruff=true
  grep -Eqi '(^|[^a-z])mypy([^a-z]|$)' "$_deps_file" 2>/dev/null && has_mypy=true
  grep -Eqi '(^|[^a-z])black([^a-z]|$)' "$_deps_file" 2>/dev/null && has_black=true
  grep -Eqi '(^|[^a-z])isort([^a-z]|$)' "$_deps_file" 2>/dev/null && has_isort=true
  grep -Eqi '(^|[^a-z])alembic([^a-z]|$)' "$_deps_file" 2>/dev/null && has_alembic=true
fi

# Config-file fallbacks
! $has_pytest && [[ -f "$PROJ/pytest.ini" ]] && has_pytest=true
[[ -f "$PROJ/ruff.toml" || -f "$PROJ/.ruff.toml" ]] && has_ruff=true
[[ -f "$PROJ/mypy.ini" || -f "$PROJ/.mypy.ini" ]] && has_mypy=true
! $has_black && $has_pyproject && grep -q '^\[tool\.black\]' "$PROJ/pyproject.toml" 2>/dev/null && has_black=true
! $has_isort && $has_pyproject && grep -q '^\[tool\.isort\]' "$PROJ/pyproject.toml" 2>/dev/null && has_isort=true

# SQLAlchemy is suppressed when Django is present (Django ORM is the primary)
[[ -n "${django_version:-}" ]] && has_sqlalchemy=false
# isort is suppressed when ruff is present (ruff handles import sorting)
$has_ruff && has_isort=false
unset _df _deps_file

# ── Version detection for testing + tooling ───────────────────────────────────
pytest_version=''
celery_version=''
sqlalchemy_version=''
ruff_version=''
mypy_version=''
black_version=''
isort_version=''
alembic_version=''
$has_pytest     && pytest_version=$(pkg_version "pytest")
$has_celery     && celery_version=$(pkg_version "celery")
$has_sqlalchemy && sqlalchemy_version=$(pkg_version "sqlalchemy")
$has_ruff       && ruff_version=$(pkg_version "ruff")
$has_mypy       && mypy_version=$(pkg_version "mypy")
$has_black      && black_version=$(pkg_version "black")
$has_isort      && isort_version=$(pkg_version "isort")
$has_alembic    && alembic_version=$(pkg_version "alembic")

# ── Python runtime ────────────────────────────────────────────────────────────
python_seg="${FG_ACCENT}${IC_PYTHON} ${FG_TEXT}Python"
[[ -n "$py_version" ]] && python_seg+=" ${N}${FG_ACCENT}v${py_version}"
[[ -n "$tool_label" ]] && python_seg+=" ${FG_ACCENT}[${FG_TEXT}${tool_icon}${tool_label}${FG_ACCENT}]"
add_seg "$python_seg"

# ── Framework ─────────────────────────────────────────────────────────────────
$has_django  && bl_version_seg "$IC_DJANGO"  Django  "$django_version"
$has_fastapi && bl_version_seg "$IC_FASTAPI" FastAPI "$fastapi_version"
$has_flask   && bl_version_seg "$IC_FLASK"   Flask   "$flask_version"

# Slot 4: Add-ons
$has_pydantic && bl_seg "$IC_TYPE" Pydantic
$has_httpx    && bl_seg "$IC_WEB"  HTTPX

# Slot 5: Testing
$has_pytest && bl_version_seg "$IC_TEST" pytest "$pytest_version"

# Slot 6: Tooling (order: ruff → black → isort → mypy → Celery → SQLAlchemy → Alembic)
$has_ruff       && bl_version_seg "$IC_LINT" ruff        "$ruff_version"
$has_black      && bl_version_seg "$IC_LINT" black       "$black_version"
$has_isort      && bl_version_seg "$IC_LINT" isort       "$isort_version"
$has_mypy       && bl_version_seg "$IC_TYPE" mypy        "$mypy_version"
$has_celery     && bl_version_seg "$IC_QUEUE" Celery     "$celery_version"
$has_sqlalchemy && bl_version_seg "$IC_DB"   SQLAlchemy  "$sqlalchemy_version"
$has_alembic    && bl_version_seg "$IC_DB"   Alembic     "$alembic_version"

bl_bar_finish "$_bar_gradient"
