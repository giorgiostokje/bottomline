#!/usr/bin/env bats
# Integration tests for bar caching (bl_cache_path + bl_cache_write).
# Uses the go bar as the primary test vehicle (simple, reliable signal file).

bats_require_minimum_version 1.5.0
load '../helpers'

setup() {
  setup_fake_proj
  printf 'module example.com/app\n\ngo 1.22\n' > "$FAKE_PROJ/go.mod"
}

teardown() {
  teardown_fake_proj
  local hash; hash=$(printf '%s' "$FAKE_PROJ" | (md5sum 2>/dev/null || md5) | cut -c1-8)
  find -L /tmp -maxdepth 1 \( -name "bl_go_${hash}_*.txt" -o -name "bl_python_${hash}_*.txt" \) \
    -delete 2>/dev/null || true
}

# ── Cache miss ────────────────────────────────────────────────────────────────

@test "cache miss: go bar creates a cache file on first run" {
  bar_run go "$FAKE_PROJ" 60
  local hash; hash=$(printf '%s' "$FAKE_PROJ" | (md5sum 2>/dev/null || md5) | cut -c1-8)
  local count; count=$(find -L /tmp -maxdepth 1 -name "bl_go_${hash}_*.txt" 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -ge 1 ]
}

@test "cache miss: go bar cache file contains rendered output" {
  bar_run go "$FAKE_PROJ" 60
  local hash; hash=$(printf '%s' "$FAKE_PROJ" | (md5sum 2>/dev/null || md5) | cut -c1-8)
  local cache_file; cache_file=$(find -L /tmp -maxdepth 1 -name "bl_go_${hash}_*.txt" 2>/dev/null | head -1)
  [ -n "$cache_file" ]
  [[ "$(strip_ansi < "$cache_file")" == *"Go"* ]]
}

# ── Cache hit ─────────────────────────────────────────────────────────────────

@test "cache hit: go bar serves cached output after signal file is removed" {
  bar_run go "$FAKE_PROJ" 60   # populates cache
  rm "$FAKE_PROJ/go.mod"       # without cache, next run would exit silently
  bar_run go "$FAKE_PROJ" 60   # must serve from cache
  [[ "$BAR_OUTPUT" == *"Go"* ]]
}

@test "cache hit: go bar output is identical on cache hit" {
  bar_run go "$FAKE_PROJ" 60
  local first_output="$BAR_OUTPUT"
  bar_run go "$FAKE_PROJ" 60
  [ "$BAR_OUTPUT" = "$first_output" ]
}

# ── TTL=0 bypass ──────────────────────────────────────────────────────────────

@test "TTL=0: go bar writes no cache file" {
  bar_run go "$FAKE_PROJ" 0
  local hash; hash=$(printf '%s' "$FAKE_PROJ" | (md5sum 2>/dev/null || md5) | cut -c1-8)
  local count; count=$(find -L /tmp -maxdepth 1 -name "bl_go_${hash}_*.txt" 2>/dev/null | wc -l | tr -d ' ')
  [ "$count" -eq 0 ]
}

@test "TTL=0: removing signal file causes empty output (no stale cache served)" {
  bar_run go "$FAKE_PROJ" 0
  rm "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ" 0
  local stripped; stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}
