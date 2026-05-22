#!/usr/bin/env bats
# Unit tests for bl_cache_path and bl_cache_write (lib/helpers.sh)

bats_require_minimum_version 1.5.0
load '../helpers'

setup() {
  source "$BOTTOMLINE_ROOT/lib/helpers.sh"
}

@test "bl_cache_path: returns path matching /tmp/bl_<name>_<hash>_<bucket>.txt" {
  result=$(bl_cache_path "go" 5 "/some/project")
  [[ "$result" =~ ^/tmp/bl_go_[0-9a-f]{8}_[0-9]+\.txt$ ]]
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
  local hash; hash=$(printf '%s' "/some/project" | md5 | cut -c1-8)
  local stale="/tmp/bl_go_${hash}_1.txt"
  printf 'stale' > "$stale"
  local cache_file; cache_file=$(bl_cache_path "go" 5 "/some/project")
  bl_cache_write "$cache_file" "fresh"
  [ ! -f "$stale" ]
  rm -f "$cache_file"
}
