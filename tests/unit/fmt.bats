#!/usr/bin/env bats
# Unit tests for fmt_n, fmt_k, fmt_remaining (lib/functions.sh)

bats_require_minimum_version 1.5.0
load '../helpers'

# Source just the pure functions — no side effects.
source "$BOTTOMLINE_ROOT/lib/functions.sh"

# ---------------------------------------------------------------------------
# fmt_n — human-readable large numbers
# ---------------------------------------------------------------------------

@test "fmt_n: 0 returns 0" {
  run fmt_n 0
  [ "$output" = "0" ]
}

@test "fmt_n: 999 stays as integer" {
  run fmt_n 999
  [ "$output" = "999" ]
}

@test "fmt_n: 1000 becomes 1.0k" {
  run fmt_n 1000
  [ "$output" = "1.0k" ]
}

@test "fmt_n: 1500 becomes 1.5k" {
  run fmt_n 1500
  [ "$output" = "1.5k" ]
}

@test "fmt_n: 999999 becomes 999.9k" {
  run fmt_n 999999
  [ "$output" = "999.9k" ]
}

@test "fmt_n: 1000000 becomes 1.0M" {
  run fmt_n 1000000
  [ "$output" = "1.0M" ]
}

@test "fmt_n: 2500000 becomes 2.5M" {
  run fmt_n 2500000
  [ "$output" = "2.5M" ]
}

# ---------------------------------------------------------------------------
# fmt_k — round to nearest k (used for context window display)
# ---------------------------------------------------------------------------

@test "fmt_k: 0 returns 0k" {
  run fmt_k 0
  [ "$output" = "0k" ]
}

@test "fmt_k: 499 rounds down to 0k" {
  run fmt_k 499
  [ "$output" = "0k" ]
}

@test "fmt_k: 500 rounds up to 1k" {
  run fmt_k 500
  [ "$output" = "1k" ]
}

@test "fmt_k: 1500 becomes 2k" {
  run fmt_k 1500
  [ "$output" = "2k" ]
}

@test "fmt_k: 200000 becomes 200k" {
  run fmt_k 200000
  [ "$output" = "200k" ]
}

# ---------------------------------------------------------------------------
# fmt_remaining — human-readable countdown
# ---------------------------------------------------------------------------

@test "fmt_remaining: 0 seconds produces empty output" {
  run fmt_remaining 0
  [ "$output" = "" ]
}

@test "fmt_remaining: negative seconds produces empty output" {
  run fmt_remaining -1
  [ "$output" = "" ]
}

@test "fmt_remaining: 59 seconds is 0m" {
  run fmt_remaining 59
  [ "$output" = "0m" ]
}

@test "fmt_remaining: 60 seconds is 1m" {
  run fmt_remaining 60
  [ "$output" = "1m" ]
}

@test "fmt_remaining: 3599 seconds is 59m" {
  run fmt_remaining 3599
  [ "$output" = "59m" ]
}

@test "fmt_remaining: 3600 seconds is 1h0m" {
  run fmt_remaining 3600
  [ "$output" = "1h0m" ]
}

@test "fmt_remaining: 7320 seconds is 2h2m" {
  run fmt_remaining 7320
  [ "$output" = "2h2m" ]
}

@test "fmt_remaining: 86400 seconds (1 day) is 1d0h" {
  run fmt_remaining 86400
  [ "$output" = "1d0h" ]
}

@test "fmt_remaining: 90000 seconds is 1d1h" {
  run fmt_remaining 90000
  [ "$output" = "1d1h" ]
}
