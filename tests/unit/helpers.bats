#!/usr/bin/env bats
# Unit tests for bl_cache_path and bl_cache_write (lib/helpers.sh)

bats_require_minimum_version 1.5.0
load '../helpers'

setup() {
  source "$BOTTOMLINE_ROOT/lib/helpers.sh"
}

@test "bl_cache_path: returns path matching 4-segment format" {
  result=$(bl_cache_path "go" 5 "/some/project")
  [[ "$result" =~ ^/tmp/bl_go_[0-9a-f]{8}_[0-9a-f]{8}_[0-9]+\.txt$ ]]
}

@test "bl_cache_path: same inputs within same bucket return identical path" {
  path1=$(bl_cache_path "go" 5 "/some/project")
  path2=$(bl_cache_path "go" 5 "/some/project")
  [ "$path1" = "$path2" ]
}

@test "bl_cache_path: different project dirs produce different paths" {
  path1=$(bl_cache_path "go" 5 "/project/a")
  path2=$(bl_cache_path "go" 5 "/project/b")
  [ "$path1" != "$path2" ]
}

@test "bl_cache_path: different bar names produce different paths" {
  path1=$(bl_cache_path "go"     5 "/some/project")
  path2=$(bl_cache_path "python" 5 "/some/project")
  [ "$path1" != "$path2" ]
}

@test "bl_cache_path: path changes when watched file mtime changes" {
  local f; f=$(mktemp)
  touch -t 202001010000 "$f"
  path1=$(bl_cache_path "go" 5 "/some/project" "$f")
  touch "$f"
  path2=$(bl_cache_path "go" 5 "/some/project" "$f")
  [ "$path1" != "$path2" ]
  rm -f "$f"
}

@test "bl_cache_path: path changes when watched file is created" {
  local f; f=$(mktemp); rm -f "$f"
  path1=$(bl_cache_path "go" 5 "/some/project" "$f")
  touch "$f"
  path2=$(bl_cache_path "go" 5 "/some/project" "$f")
  [ "$path1" != "$path2" ]
  rm -f "$f"
}

@test "bl_cache_path: same inputs and unchanged files return identical path" {
  local f; f=$(mktemp)
  path1=$(bl_cache_path "go" 5 "/some/project" "$f")
  path2=$(bl_cache_path "go" 5 "/some/project" "$f")
  [ "$path1" = "$path2" ]
  rm -f "$f"
}

@test "bl_cache_write: creates file with expected content" {
  local cache_file; cache_file=$(bl_cache_path "go" 5 "/test/project")
  rm -f "$cache_file"
  bl_cache_write "$cache_file" "hello world"
  [ -f "$cache_file" ]
  [ "$(cat "$cache_file")" = "hello world" ]
  rm -f "$cache_file"
}

@test "bl_cache_write: no-op when output is empty" {
  local cache_file; cache_file=$(bl_cache_path "go" 5 "/test/project")
  rm -f "$cache_file"
  bl_cache_write "$cache_file" ""
  [ ! -f "$cache_file" ]
}

@test "bl_cache_write: removes stale files for same bar and project" {
  local hash; hash=$(printf '%s' "/some/project" | (md5sum 2>/dev/null || md5) | cut -c1-8)
  local stale="/tmp/bl_go_${hash}_deadbeef_1.txt"
  printf 'stale' > "$stale"
  local cache_file; cache_file=$(bl_cache_path "go" 5 "/some/project")
  bl_cache_write "$cache_file" "fresh"
  [ ! -f "$stale" ]
  rm -f "$cache_file"
}

# ── bl_mtime_fingerprint ──────────────────────────────────────────────────────

@test "bl_mtime_fingerprint: returns 8-char hex string with no args" {
  result=$(bl_mtime_fingerprint)
  [[ "$result" =~ ^[0-9a-f]{8}$ ]]
}

@test "bl_mtime_fingerprint: stable across calls with no files" {
  r1=$(bl_mtime_fingerprint)
  r2=$(bl_mtime_fingerprint)
  [ "$r1" = "$r2" ]
}

@test "bl_mtime_fingerprint: stable when watched file is unchanged" {
  local f; f=$(mktemp)
  r1=$(bl_mtime_fingerprint "$f")
  r2=$(bl_mtime_fingerprint "$f")
  [ "$r1" = "$r2" ]
  rm -f "$f"
}

@test "bl_mtime_fingerprint: changes when file mtime changes" {
  local f; f=$(mktemp)
  touch -t 202001010000 "$f"
  r1=$(bl_mtime_fingerprint "$f")
  touch "$f"
  r2=$(bl_mtime_fingerprint "$f")
  [ "$r1" != "$r2" ]
  rm -f "$f"
}

@test "bl_mtime_fingerprint: changes when file is created" {
  local f; f=$(mktemp); rm -f "$f"
  r1=$(bl_mtime_fingerprint "$f")
  touch "$f"
  r2=$(bl_mtime_fingerprint "$f")
  [ "$r1" != "$r2" ]
  rm -f "$f"
}

@test "bl_mtime_fingerprint: changes when file is deleted" {
  local f; f=$(mktemp)
  r1=$(bl_mtime_fingerprint "$f")
  rm -f "$f"
  r2=$(bl_mtime_fingerprint "$f")
  [ "$r1" != "$r2" ]
}

@test "bl_mtime_fingerprint: absent files all contribute 0 so multiple absent paths hash equally" {
  r1=$(bl_mtime_fingerprint "/nonexistent/a.txt" "/nonexistent/b.txt")
  r2=$(bl_mtime_fingerprint "/nonexistent/c.txt" "/nonexistent/d.txt")
  # All absent paths contribute "0"; the fingerprint only reflects count+order of absent paths
  [ "$r1" = "$r2" ]
}
