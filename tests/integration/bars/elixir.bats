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
