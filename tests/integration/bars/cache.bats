#!/usr/bin/env bats
# Integration tests for mtime-based cache fingerprinting.
# Uses the go bar as a representative subject.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "cache: bar serves cached output within TTL when files unchanged" {
  printf 'module example.com/app\n\ngo 1.22\n' > "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ" 60
  local first="$BAR_OUTPUT"
  bar_run go "$FAKE_PROJ" 60
  [ "$BAR_OUTPUT" = "$first" ]
}

@test "cache: bar invalidates when watched file content changes within TTL" {
  printf 'module example.com/app\n\ngo 1.22\n' > "$FAKE_PROJ/go.mod"
  touch -t 202001010000 "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ" 60
  [[ "$BAR_OUTPUT" == *"1.22"* ]]
  # Overwrite go.mod — new content and new mtime
  printf 'module example.com/app\n\ngo 1.23\n' > "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ" 60
  [[ "$BAR_OUTPUT" == *"1.23"* ]]
}

@test "cache: bar invalidates when watched file is created within TTL" {
  printf 'module example.com/app\n\ngo 1.22\n' > "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ" 60
  [[ "$BAR_OUTPUT" != *"workspace"* ]]
  touch "$FAKE_PROJ/go.work"
  bar_run go "$FAKE_PROJ" 60
  [[ "$BAR_OUTPUT" == *"workspace"* ]]
}

@test "cache: bar does not re-render when files unchanged within TTL" {
  printf 'module example.com/app\n\ngo 1.22\n' > "$FAKE_PROJ/go.mod"
  # First run: renders and writes cache
  bar_run go "$FAKE_PROJ" 60
  [[ "$BAR_OUTPUT" == *"1.22"* ]]
  # Locate the cache file using the same projhash bl_cache_path computes
  local projhash
  projhash=$(printf '%s' "$FAKE_PROJ" | (md5sum 2>/dev/null || md5) | cut -c1-8)
  local cache_file
  cache_file=$(find -L /tmp -maxdepth 1 -name "bl_go_${projhash}_*.txt" 2>/dev/null | head -1)
  [[ -n "$cache_file" ]]
  printf 'CACHED_SENTINEL' > "$cache_file"
  # Second run: should serve from cache
  bar_run go "$FAKE_PROJ" 60
  [[ "$BAR_OUTPUT" == *"CACHED_SENTINEL"* ]]
}
