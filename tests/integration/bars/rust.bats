#!/usr/bin/env bats
# Integration tests for the rust bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "rust: exits silently when no Cargo.toml" {
  bar_run rust "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "rust: renders Rust and edition from Cargo.toml" {
  printf '[package]\nname = "myapp"\nversion = "0.1.0"\nedition = "2021"\n' \
    > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Rust"* ]]
  [[ "$BAR_OUTPUT" == *"2021"* ]]
}

@test "rust: renders workspace flag when [workspace] present in Cargo.toml" {
  printf '[workspace]\nmembers = ["crate-a", "crate-b"]\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"workspace"* ]]
}

@test "rust: no workspace flag for a regular crate" {
  printf '[package]\nname = "myapp"\nversion = "0.1.0"\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"workspace"* ]]
}

@test "rust: renders actix-web when present in Cargo.toml" {
  printf '[package]\nname="x"\nedition="2021"\n\n[dependencies]\nactix-web = "4"\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Actix"* ]]
}

@test "rust: renders axum when present in Cargo.toml" {
  printf '[package]\nname="x"\nedition="2021"\n\n[dependencies]\naxum = "0.7"\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"axum"* ]]
}

@test "rust: renders tokio when present in Cargo.toml" {
  printf '[package]\nname="x"\nedition="2021"\n\n[dependencies]\ntokio = { version = "1", features = ["full"] }\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Tokio"* ]]
}

@test "rust: renders sqlx when present in Cargo.toml" {
  printf '[package]\nname="x"\nedition="2021"\n\n[dependencies]\nsqlx = "0.7"\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"sqlx"* ]]
}

@test "rust: renders nextest when binary on PATH" {
  printf '[package]\nname="x"\nedition="2021"\n' > "$FAKE_PROJ/Cargo.toml"
  printf '#!/bin/sh\necho ok\n' > "$FAKE_PROJ/cargo-nextest"
  chmod +x "$FAKE_PROJ/cargo-nextest"
  PATH="$FAKE_PROJ:$PATH" bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"nextest"* ]]
}

@test "rust: renders clippy when binary on PATH" {
  printf '[package]\nname="x"\nedition="2021"\n' > "$FAKE_PROJ/Cargo.toml"
  printf '#!/bin/sh\necho ok\n' > "$FAKE_PROJ/cargo-clippy"
  chmod +x "$FAKE_PROJ/cargo-clippy"
  PATH="$FAKE_PROJ:$PATH" bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Clippy"* ]]
}

@test "rust: renders Clap when present in Cargo.toml" {
  printf '[package]\nname="x"\nedition="2021"\n\n[dependencies]\nclap = "4"\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Clap"* ]]
}

@test "rust: Clap and web framework both render (not mutually exclusive)" {
  printf '[package]\nname="x"\nedition="2021"\n\n[dependencies]\naxum = "0.7"\nclap = "4"\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"axum"* ]]
  [[ "$BAR_OUTPUT" == *"Clap"* ]]
}

@test "rust: renders Tonic when present in Cargo.toml" {
  printf '[package]\nname="x"\nedition="2021"\n\n[dependencies]\ntonic = "0.12"\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Tonic"* ]]
}

@test "rust: renders SeaORM when present in Cargo.toml" {
  printf '[package]\nname="x"\nedition="2021"\n\n[dependencies]\nsea-orm = "1.0"\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"SeaORM"* ]]
}

@test "rust: multiple ORMs render simultaneously in order" {
  printf '[package]\nname="x"\nedition="2021"\n\n[dependencies]\nsea-orm = "1.0"\ndiesel = "2"\n' > "$FAKE_PROJ/Cargo.toml"
  bar_run rust "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"diesel"* ]]
  [[ "$BAR_OUTPUT" == *"SeaORM"* ]]
  d_pos=$(printf '%s' "$BAR_OUTPUT" | awk '{print index($0,"diesel")}')
  s_pos=$(printf '%s' "$BAR_OUTPUT" | awk '{print index($0,"SeaORM")}')
  (( d_pos < s_pos ))
}
