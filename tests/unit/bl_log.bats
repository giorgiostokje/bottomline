#!/usr/bin/env bats
# Unit tests for bl_log (lib/helpers.sh)

bats_require_minimum_version 1.5.0
load '../helpers'

setup() {
  FAKE_CACHE=$(mktemp -d)
  export BOTTOMLINE_CACHE_DIR="$FAKE_CACHE"
  LOG_FILE="$FAKE_CACHE/bottomline.log"
  export BOTTOMLINE_TEXT_HEX='#e2d5c3'
  export BOTTOMLINE_ACCENT_HEX='#da7756'
  export BOTTOMLINE_WARN_HEX='#f4a261'
  export BOTTOMLINE_DANGER_HEX='#e05a4e'
  export BOTTOMLINE_RESET='' BOTTOMLINE_BOLD=''
  export BOTTOMLINE_SEP='|'
  export BOTTOMLINE_ICON_TYPE=none
  source "$BOTTOMLINE_ROOT/lib/helpers.sh"
}

teardown() {
  rm -rf "$FAKE_CACHE"
}

@test "bl_log: off level writes nothing" {
  BOTTOMLINE_LOG_LEVEL=off
  bl_log error mybar "something failed"
  [ ! -f "$LOG_FILE" ]
}

@test "bl_log: unset level writes nothing" {
  unset BOTTOMLINE_LOG_LEVEL
  bl_log error mybar "something failed"
  [ ! -f "$LOG_FILE" ]
}

@test "bl_log: error level writes error entries" {
  BOTTOMLINE_LOG_LEVEL=error
  bl_log error mybar "curl failed"
  grep -q '\[error\]' "$LOG_FILE"
  grep -q '\[mybar\]' "$LOG_FILE"
  grep -q 'curl failed' "$LOG_FILE"
}

@test "bl_log: error level suppresses warn entries" {
  BOTTOMLINE_LOG_LEVEL=error
  bl_log warn mybar "soft warning"
  [ ! -f "$LOG_FILE" ]
}

@test "bl_log: error level suppresses debug entries" {
  BOTTOMLINE_LOG_LEVEL=error
  bl_log debug mybar "verbose detail"
  [ ! -f "$LOG_FILE" ]
}

@test "bl_log: warn level writes warn entries" {
  BOTTOMLINE_LOG_LEVEL=warn
  bl_log warn mybar "using fallback"
  grep -q '\[warn \]' "$LOG_FILE"
}

@test "bl_log: warn level writes error entries" {
  BOTTOMLINE_LOG_LEVEL=warn
  bl_log error mybar "hard failure"
  grep -q '\[error\]' "$LOG_FILE"
}

@test "bl_log: warn level suppresses debug entries" {
  BOTTOMLINE_LOG_LEVEL=warn
  bl_log debug mybar "verbose detail"
  [ ! -f "$LOG_FILE" ]
}

@test "bl_log: debug level writes all levels" {
  BOTTOMLINE_LOG_LEVEL=debug
  bl_log error mybar "error msg"
  bl_log warn  mybar "warn msg"
  bl_log debug mybar "debug msg"
  [ "$(wc -l < "$LOG_FILE")" -eq 3 ]
}

@test "bl_log: timestamp is UTC (ends with Z)" {
  BOTTOMLINE_LOG_LEVEL=debug
  bl_log debug mybar "check time"
  grep -qE '^\[20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\]' "$LOG_FILE"
}

@test "bl_log: entry format contains level, script, and message" {
  BOTTOMLINE_LOG_LEVEL=debug
  bl_log debug myscript "hello world"
  grep -q '\[debug\] \[myscript\] hello world' "$LOG_FILE"
}

@test "bl_log: appends to existing log" {
  BOTTOMLINE_LOG_LEVEL=debug
  bl_log debug s "first"
  bl_log debug s "second"
  [ "$(wc -l < "$LOG_FILE")" -eq 2 ]
}

@test "bl_log: unknown level writes nothing" {
  BOTTOMLINE_LOG_LEVEL=verbose
  bl_log verbose mybar "something"
  [ ! -f "$LOG_FILE" ]
}
