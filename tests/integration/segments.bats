#!/usr/bin/env bats
# Integration tests for individual segment rendering.
# Each test runs the full script with a minimal config to isolate one segment.

bats_require_minimum_version 1.5.0
load '../helpers'

setup()    { setup_fake_home; }
teardown() { teardown_fake_home; cleanup_transcript; }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# User config that enables only the listed segments (comma-separated names)
_only() {
  local segs="$1"
  printf '{"segments":{"enabled":[%s]}}' \
    "$(printf '%s' "$segs" | sed 's/[^,]*/"&"/g')"
}

# ---------------------------------------------------------------------------
# model
# ---------------------------------------------------------------------------

@test "model: renders display_name" {
  bl_run '{"model":{"display_name":"claude-sonnet-4-5"}}' "$(_only model)"
  [[ "$BL_OUTPUT" == *"claude-sonnet-4-5"* ]]
}

@test "model: hidden when model is absent from input" {
  bl_run '{}' "$(_only model)"
  [[ "$BL_OUTPUT" == "" || "$BL_OUTPUT" == *$'\n'* && ! "$BL_OUTPUT" == *"claude"* ]]
  # No visible text content means the segment was suppressed.
  stripped=$(printf '%s' "$BL_OUTPUT" | tr -d ' \n')
  [ -z "$stripped" ]
}

# ---------------------------------------------------------------------------
# effort
# ---------------------------------------------------------------------------

@test "effort: renders level string" {
  bl_run '{"effort":{"level":"medium"}}' "$(_only effort)"
  [[ "$BL_OUTPUT" == *"medium"* ]]
}

@test "effort: hidden when effort is absent from input" {
  bl_run '{}' "$(_only effort)"
  stripped=$(printf '%s' "$BL_OUTPUT" | tr -d ' \n')
  [ -z "$stripped" ]
}

# ---------------------------------------------------------------------------
# tokens_in / tokens_out
# ---------------------------------------------------------------------------

@test "tokens_in: renders input token count from transcript" {
  make_transcript 1500 0
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [[ "$BL_OUTPUT" == *"1.5k"* ]]
}

@test "tokens_in: hidden when transcript has zero tokens" {
  make_transcript 0 0
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  stripped=$(printf '%s' "$BL_OUTPUT" | tr -d ' \n')
  [ -z "$stripped" ]
}

@test "tokens_out: renders output token count from transcript" {
  make_transcript 0 800
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_out)"
  [[ "$BL_OUTPUT" == *"800"* ]]
}

@test "tokens_in: cache_read tokens appear as +N suffix" {
  make_transcript 1000 0 500 0
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [[ "$BL_OUTPUT" == *"1.0k"* && "$BL_OUTPUT" == *"+500"* ]]
}

@test "tokens_out: cache_create tokens appear as +N suffix" {
  make_transcript 0 200 0 300
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_out)"
  [[ "$BL_OUTPUT" == *"200"* && "$BL_OUTPUT" == *"+300"* ]]
}

# ---------------------------------------------------------------------------
# usage_5h
# ---------------------------------------------------------------------------

@test "usage_5h: renders percentage" {
  bl_run '{"rate_limits":{"five_hour":{"used_percentage":42}}}' "$(_only usage_5h)"
  [[ "$BL_OUTPUT" == *"42%"* ]]
}

@test "usage_5h: hidden when rate_limits absent" {
  bl_run '{}' "$(_only usage_5h)"
  stripped=$(printf '%s' "$BL_OUTPUT" | tr -d ' \n')
  [ -z "$stripped" ]
}

# ---------------------------------------------------------------------------
# segments.disabled suppresses a segment
# ---------------------------------------------------------------------------

@test "segments.disabled removes a listed segment" {
  local user_cfg='{"segments":{"enabled":["model","effort"],"disabled":["effort"]}}'
  bl_run '{"model":{"display_name":"test-model"},"effort":{"level":"low"}}' "$user_cfg"
  [[ "$BL_OUTPUT" == *"test-model"* ]]
  [[ "$BL_OUTPUT" != *"low"* ]]
}

# ---------------------------------------------------------------------------
# tokens icon override: shared 'tokens' key falls back for tokens_in/tokens_out
# ---------------------------------------------------------------------------

@test "tokens icon override: shared 'tokens' key applies to tokens_in" {
  local user_cfg
  user_cfg=$(printf '%s' "$(_only tokens_in)" \
    | jq '.appearance.icons.overrides.tokens = "26a0"')   # ⚠ U+26A0
  make_transcript 1000 0
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$user_cfg"
  [[ "$BL_OUTPUT" == *"⚠"* ]]
}

@test "tokens icon override: specific tokens_in key takes precedence over shared" {
  local user_cfg
  user_cfg=$(printf '%s' "$(_only tokens_in)" \
    | jq '.appearance.icons.overrides.tokens = "26a0" | .appearance.icons.overrides.tokens_in = "1f525"')
  make_transcript 1000 0
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$user_cfg"
  [[ "$BL_OUTPUT" == *"🔥"* ]]
  [[ "$BL_OUTPUT" != *"⚠"* ]]
}
