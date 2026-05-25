#!/usr/bin/env bats
# Unit tests for gauge — name-based extraction from candidate files.
# gauge depends on FG_ACCENT (filled) and FG_TEXT (unfilled), set via lib/helpers.sh.

bats_require_minimum_version 1.5.0
load '../helpers'

_bl_extract() {
  local name="$1"; shift
  local f body
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    body=$(sed -n "/^${name}() {\$/,/^\}$/p" "$f")
    [[ -n "$body" ]] && eval "$body" && return 0
  done
  return 1
}

setup() {
  BOTTOMLINE_RESET=$'\e[0m' BOTTOMLINE_BOLD=$'\e[1m' BOTTOMLINE_SEP='|'
  BOTTOMLINE_TEXT_HEX='#cccccc' BOTTOMLINE_ACCENT_HEX='#ff0000'
  BOTTOMLINE_WARN_HEX='#ffff00' BOTTOMLINE_DANGER_HEX='#ff0000'
  source "$BOTTOMLINE_ROOT/lib/helpers.sh"
  _bl_extract gauge "$BOTTOMLINE_ROOT/lib/segments.sh" "$BOTTOMLINE_ROOT/bottomline.sh"
}

@test "gauge: used=0 produces all unfilled bars" {
  run gauge 0 100 10
  [ "$status" -eq 0 ]
  plain=$(printf '%s' "$output" | strip_ansi)
  [ "$plain" = '▱▱▱▱▱▱▱▱▱▱' ]
}

@test "gauge: used=total produces all filled bars" {
  run gauge 100 100 10
  [ "$status" -eq 0 ]
  plain=$(printf '%s' "$output" | strip_ansi)
  [ "$plain" = '▰▰▰▰▰▰▰▰▰▰' ]
}

@test "gauge: used>total clamps to full" {
  run gauge 200 100 10
  [ "$status" -eq 0 ]
  plain=$(printf '%s' "$output" | strip_ansi)
  [ "$plain" = '▰▰▰▰▰▰▰▰▰▰' ]
}

@test "gauge: used<1% of total clamps to 1 filled" {
  run gauge 1 10000 10
  [ "$status" -eq 0 ]
  plain=$(printf '%s' "$output" | strip_ansi)
  [ "$plain" = '▰▱▱▱▱▱▱▱▱▱' ]
}

@test "gauge: total=0 produces no output" {
  run gauge 5 0 10
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "gauge: total<0 produces no output" {
  run gauge 5 -1 10
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "gauge: default width is 10" {
  run gauge 50 100
  [ "$status" -eq 0 ]
  plain=$(printf '%s' "$output" | strip_ansi)
  [ "$plain" = '▰▰▰▰▰▱▱▱▱▱' ]
}

@test "gauge: explicit width overrides default" {
  run gauge 50 100 5
  [ "$status" -eq 0 ]
  plain=$(printf '%s' "$output" | strip_ansi)
  [ "$plain" = '▰▰▱▱▱' ]
}
