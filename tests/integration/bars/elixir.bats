#!/usr/bin/env bats
# Integration tests for the elixir bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "elixir: exits silently when no mix.exs" {
  bar_run elixir "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "elixir: renders Elixir version from mix.exs" {
  cat > "$FAKE_PROJ/mix.exs" <<'EOF'
defmodule MyApp.MixProject do
  use Mix.Project
  def project do
    [app: :my_app, version: "0.1.0", elixir: "~> 1.14"]
  end
end
EOF
  bar_run elixir "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Elixir"* ]]
  [[ "$BAR_OUTPUT" == *"1.14"* ]]
}

@test "elixir: renders Phoenix from mix.lock" {
  printf 'defmodule M do\n  def project, do: [elixir: "~> 1.14"]\nend\n' \
    > "$FAKE_PROJ/mix.exs"
  printf '%s\n' \
    '%{"phoenix": {:hex, :phoenix, "1.7.10", "abc", [:mix], [], "hexpm", "def"}}' \
    > "$FAKE_PROJ/mix.lock"
  bar_run elixir "$FAKE_PROJ"
  # Version extraction uses a gawk-only 3-arg match() — may be empty on macOS BSD awk.
  [[ "$BAR_OUTPUT" == *"Phoenix"* ]]
}

@test "elixir: no Phoenix segment when mix.lock absent" {
  printf 'defmodule M do\n  def project, do: [elixir: "~> 1.14"]\nend\n' \
    > "$FAKE_PROJ/mix.exs"
  bar_run elixir "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"Phoenix"* ]]
}

@test "elixir: renders LiveView when in mix.lock" {
  printf 'defmodule X.MixProject do\n  def project, do: []\nend\n' > "$FAKE_PROJ/mix.exs"
  printf '%%{\n  "phoenix_live_view": {:hex, :phoenix_live_view, "1.0.0", "abc", [:mix], [], "hexpm", "def"},\n}\n' \
    > "$FAKE_PROJ/mix.lock"
  bar_run elixir "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"LiveView"* ]]
}

@test "elixir: renders Ecto when ecto_sql in mix.lock" {
  printf 'defmodule X.MixProject do\nend\n' > "$FAKE_PROJ/mix.exs"
  printf '%%{\n  "ecto_sql": {:hex, :ecto_sql, "3.11.0", "abc", [:mix], [], "hexpm", "def"},\n}\n' \
    > "$FAKE_PROJ/mix.lock"
  bar_run elixir "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Ecto"* ]]
}

@test "elixir: renders Oban when in mix.lock" {
  printf 'defmodule X.MixProject do\nend\n' > "$FAKE_PROJ/mix.exs"
  printf '%%{\n  "oban": {:hex, :oban, "2.17.0", "abc", [:mix], [], "hexpm", "def"},\n}\n' \
    > "$FAKE_PROJ/mix.lock"
  bar_run elixir "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Oban"* ]]
}

@test "elixir: renders ExUnit when test/ exists" {
  printf 'defmodule X.MixProject do\nend\n' > "$FAKE_PROJ/mix.exs"
  mkdir -p "$FAKE_PROJ/test"
  bar_run elixir "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"ExUnit"* ]]
}

@test "elixir: renders Credo when in mix.lock" {
  printf 'defmodule X.MixProject do\nend\n' > "$FAKE_PROJ/mix.exs"
  printf '%%{\n  "credo": {:hex, :credo, "1.7.0", "abc", [:mix], [], "hexpm", "def"},\n}\n' \
    > "$FAKE_PROJ/mix.lock"
  bar_run elixir "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Credo"* ]]
}

@test "elixir: renders Dialyxir when in mix.lock" {
  printf 'defmodule X.MixProject do\nend\n' > "$FAKE_PROJ/mix.exs"
  printf '%%{\n  "dialyxir": {:hex, :dialyxir, "1.4.0", "abc", [:mix], [], "hexpm", "def"},\n}\n' \
    > "$FAKE_PROJ/mix.lock"
  bar_run elixir "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Dialyxir"* ]]
}
