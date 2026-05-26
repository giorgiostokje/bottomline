#!/usr/bin/env bats
# Integration tests for the python bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "python: exits silently when no signal files present" {
  bar_run python "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "python: renders Python when requirements.txt exists" {
  printf 'requests>=2.0\n' > "$FAKE_PROJ/requirements.txt"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Python"* ]]
}

@test "python: renders Poetry label when pyproject.toml has [tool.poetry]" {
  printf '[tool.poetry]\nname = "myapp"\nversion = "0.1.0"\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Poetry"* ]]
}

@test "python: renders Django when requirements.txt contains django" {
  printf 'Django>=4.2\n' > "$FAKE_PROJ/requirements.txt"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Django"* ]]
}

@test "python: renders Flask when requirements.txt contains flask" {
  printf 'flask>=3.0\n' > "$FAKE_PROJ/requirements.txt"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Flask"* ]]
}

@test "python: renders Python version from .python-version" {
  printf '[project]\nname = "x"\n' > "$FAKE_PROJ/pyproject.toml"
  printf '3.12.1\n' > "$FAKE_PROJ/.python-version"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"3.12"* ]]
}

@test "python: renders pytest when in pyproject.toml" {
  printf '[project]\nname = "x"\ndependencies = ["pytest"]\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"pytest"* ]]
}

@test "python: renders pytest when pytest.ini exists" {
  printf '[project]\nname = "x"\n' > "$FAKE_PROJ/pyproject.toml"
  printf '[pytest]\n' > "$FAKE_PROJ/pytest.ini"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"pytest"* ]]
}

@test "python: renders ruff when ruff.toml exists" {
  printf '[project]\nname = "x"\n' > "$FAKE_PROJ/pyproject.toml"
  printf 'line-length = 100\n' > "$FAKE_PROJ/ruff.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"ruff"* ]]
}

@test "python: renders mypy when mypy.ini exists" {
  printf '[project]\nname = "x"\n' > "$FAKE_PROJ/pyproject.toml"
  printf '[mypy]\nstrict = true\n' > "$FAKE_PROJ/mypy.ini"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"mypy"* ]]
}

@test "python: renders Celery when in dependencies" {
  printf '[project]\nname = "x"\ndependencies = ["celery"]\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Celery"* ]]
}

@test "python: renders uv label when uv.lock exists" {
  printf '[project]\nname = "x"\n' > "$FAKE_PROJ/pyproject.toml"
  touch "$FAKE_PROJ/uv.lock"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"uv"* ]]
}

@test "python: renders uv label when [tool.uv] in pyproject.toml" {
  printf '[project]\nname = "x"\n[tool.uv]\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"uv"* ]]
}

@test "python: uv takes priority over Poetry when uv.lock present" {
  printf '[tool.poetry]\nname = "myapp"\nversion = "0.1.0"\n' > "$FAKE_PROJ/pyproject.toml"
  touch "$FAKE_PROJ/uv.lock"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"uv"* ]]
  [[ "$BAR_OUTPUT" != *"Poetry"* ]]
}

@test "python: renders Pydantic when in dependencies" {
  printf '[project]\nname = "x"\ndependencies = ["pydantic"]\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Pydantic"* ]]
}

@test "python: renders HTTPX when in dependencies" {
  printf '[project]\nname = "x"\ndependencies = ["httpx"]\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"HTTPX"* ]]
}

@test "python: renders black when in dependencies" {
  printf '[project]\nname = "x"\ndependencies = ["black"]\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"black"* ]]
}

@test "python: renders black when [tool.black] in pyproject.toml" {
  printf '[project]\nname = "x"\n[tool.black]\nline-length = 100\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"black"* ]]
}

@test "python: renders isort when in dependencies without ruff" {
  printf '[project]\nname = "x"\ndependencies = ["isort"]\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"isort"* ]]
}

@test "python: suppresses isort when ruff is present" {
  printf '[project]\nname = "x"\ndependencies = ["isort", "ruff"]\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"isort"* ]]
  [[ "$BAR_OUTPUT" == *"ruff"* ]]
}

@test "python: renders Alembic when in dependencies" {
  printf '[project]\nname = "x"\ndependencies = ["alembic"]\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Alembic"* ]]
}

@test "python: renders isort when [tool.isort] in pyproject.toml without ruff" {
  printf '[project]\nname = "x"\n[tool.isort]\nprofile = "black"\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"isort"* ]]
}

@test "python: suppresses isort when ruff.toml present" {
  printf '[project]\nname = "x"\ndependencies = ["isort"]\n' > "$FAKE_PROJ/pyproject.toml"
  printf 'line-length = 100\n' > "$FAKE_PROJ/ruff.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"isort"* ]]
}

@test "python: Alembic appears after SQLAlchemy when both present" {
  printf '[project]\nname = "x"\ndependencies = ["sqlalchemy", "alembic"]\n' > "$FAKE_PROJ/pyproject.toml"
  bar_run python "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"SQLAlchemy"* ]]
  [[ "$BAR_OUTPUT" == *"Alembic"* ]]
  sa_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo "SQLAlchemy" | head -1 | cut -d: -f1)
  al_pos=$(printf '%s' "$BAR_OUTPUT" | grep -bo "Alembic" | head -1 | cut -d: -f1)
  [ "$al_pos" -gt "$sa_pos" ]
}
