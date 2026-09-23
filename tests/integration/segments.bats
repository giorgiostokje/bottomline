#!/usr/bin/env bats
# Integration tests for individual segment rendering.
# Each test runs the full script with a minimal config to isolate one segment.

bats_require_minimum_version 1.5.0
load '../helpers'

# The incremental usage cache (lib/usage.sh) lives under the fake HOME so it is
# isolated per test and removed with it.
setup()    { setup_fake_home; export BOTTOMLINE_CACHE_DIR="$FAKE_HOME/cache"; mkdir -p "$BOTTOMLINE_CACHE_DIR"; }
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

@test "tokens_in: cache_create tokens included in main count" {
  make_transcript 1000 0 0 500
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [[ "$BL_OUTPUT" == *"1.5k"* ]]
}

# Claude Code repeats a message's usage on every content-block line; only the
# last line per message.id counts.
@test "tokens_in: repeated lines for one message.id are counted once" {
  make_session
  { usage_line msg_a 1000 5 0 0; usage_line msg_a 1000 200 0 0; usage_line msg_a 1000 300 0 0; } >> "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in,tokens_out)"
  [[ "$BL_OUTPUT" == *"1.0k"* ]]
  [[ "$BL_OUTPUT" != *"3.0k"* ]]
  [[ "$BL_OUTPUT" == *"300"* ]]
}

@test "tokens_in/out: subagent transcripts are included in totals" {
  make_session
  usage_line msg_main 1000 100 >> "$TRANSCRIPT_PATH"
  usage_line msg_sub1 2000 200 >> "$SUBAGENTS_DIR/agent-a1.jsonl"
  usage_line msg_sub2 3000 300 >> "$SUBAGENTS_DIR/agent-a2.jsonl"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in,tokens_out)"
  [[ "$BL_OUTPUT" == *"6.0k"* ]]
  [[ "$BL_OUTPUT" == *"600"* ]]
}

@test "context: subagent usage does not count toward main context window" {
  make_session
  usage_line msg_main 1000 10 >> "$TRANSCRIPT_PATH"
  usage_line msg_sub 150000 10 >> "$SUBAGENTS_DIR/agent-a1.jsonl"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only context)"
  [[ "$BL_OUTPUT" == *"1k/200k"* ]]
}

# ---------------------------------------------------------------------------
# context from the payload / incremental transcript reading
# ---------------------------------------------------------------------------

@test "context: payload total_input_tokens wins over the transcript" {
  make_session
  usage_line msg_a 90000 10 >> "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\",\"context_window\":{\"total_input_tokens\":42000,\"context_window_size\":200000}}" "$(_only context)"
  [[ "$BL_OUTPUT" == *"42k/200k"* ]]
}

@test "context: payload value renders without a transcript" {
  bl_run '{"context_window":{"total_input_tokens":42000,"context_window_size":1000000}}' "$(_only context)"
  [[ "$BL_OUTPUT" == *"42k/1000k"* ]]
}

@test "usage: transcript is not read when no active segment needs it" {
  make_session
  usage_line msg_a 1000 10 >> "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\",\"context_window\":{\"total_input_tokens\":1000},\"cost\":{\"total_cost_usd\":1}}" "$(_only model,context,cost)"
  [ -z "$(ls -A "$BOTTOMLINE_CACHE_DIR")" ]
}

@test "usage: transcript is read and cached when tokens_in is active" {
  make_session
  usage_line msg_a 1000 10 >> "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [[ "$BL_OUTPUT" == *"1.0k"* ]]
  [ -f "$BOTTOMLINE_CACHE_DIR/bl_usage_session.tsv" ]
}

@test "usage: appended lines are added to cached totals" {
  make_session
  usage_line msg_a 1000 100 >> "$TRANSCRIPT_PATH"
  usage_line msg_s 500 50 >> "$SUBAGENTS_DIR/agent-a1.jsonl"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in,tokens_out)"
  [[ "$BL_OUTPUT" == *"1.5k"* && "$BL_OUTPUT" == *"150"* ]]

  usage_line msg_b 2000 200 >> "$TRANSCRIPT_PATH"
  usage_line msg_t 700 70 >> "$SUBAGENTS_DIR/agent-a2.jsonl"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in,tokens_out)"
  [[ "$BL_OUTPUT" == *"4.2k"* && "$BL_OUTPUT" == *"420"* ]]
}

@test "usage: a message's usage split across refreshes is counted once" {
  make_session
  usage_line msg_a 1000 5 >> "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in,tokens_out)"
  { usage_line msg_a 1000 200; usage_line msg_a 1000 300; } >> "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in,tokens_out)"
  [[ "$BL_OUTPUT" == *"1.0k"* && "$BL_OUTPUT" != *"2.0k"* && "$BL_OUTPUT" != *"3.0k"* ]]
  [[ "$BL_OUTPUT" == *"300"* && "$BL_OUTPUT" != *"505"* ]]
}

@test "usage: a half-written final line is picked up once complete" {
  make_session
  usage_line msg_a 1000 100 >> "$TRANSCRIPT_PATH"
  local line; line=$(usage_line msg_b 2000 200)
  printf '%s' "${line:0:40}" >> "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [[ "$BL_OUTPUT" == *"1.0k"* ]]

  printf '%s\n' "${line:40}" >> "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [[ "$BL_OUTPUT" == *"3.0k"* ]]
}

@test "usage: invalid UTF-8 in the transcript does not break incremental reads" {
  make_session
  usage_line msg_a 1000 100 >> "$TRANSCRIPT_PATH"
  printf '{"type":"user","message":{"content":"\xff\xfe bytes"}}\n' >> "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  usage_line msg_b 2000 200 >> "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [[ "$BL_OUTPUT" == *"3.0k"* ]]
  local off size
  off=$(cut -d $'\x1f' -f3 "$BOTTOMLINE_CACHE_DIR/bl_usage_session.tsv")
  size=$(wc -c < "$TRANSCRIPT_PATH" | tr -d ' ')
  [ "$off" -eq "$size" ]
}

@test "usage: a rewritten (shorter) transcript is re-read from the start" {
  make_session
  { usage_line msg_a 1000 100; usage_line msg_b 2000 200; } >> "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [[ "$BL_OUTPUT" == *"3.0k"* ]]
  usage_line msg_c 500 5 > "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [[ "$BL_OUTPUT" == *"500"* && "$BL_OUTPUT" != *"3.5k"* ]]
}

@test "usage: a damaged cache is discarded and rebuilt" {
  make_session
  usage_line msg_a 1000 100 >> "$TRANSCRIPT_PATH"
  local key size
  key=$(stat -c '%d:%i' "$TRANSCRIPT_PATH" 2>/dev/null || stat -f '%d:%i' "$TRANSCRIPT_PATH")
  size=$(wc -c < "$TRANSCRIPT_PATH" | tr -d ' ')
  # Matching path, inode and offset, but a state that is not JSON
  printf '%s\x1f%s\x1f%s\x1f{not json\n' "$TRANSCRIPT_PATH" "$key" "$size" \
    > "$BOTTOMLINE_CACHE_DIR/bl_usage_session.tsv"
  usage_line msg_b 2000 200 >> "$TRANSCRIPT_PATH"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [ ! -f "$BOTTOMLINE_CACHE_DIR/bl_usage_session.tsv" ]
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [[ "$BL_OUTPUT" == *"3.0k"* ]]
  [ -f "$BOTTOMLINE_CACHE_DIR/bl_usage_session.tsv" ]
}

@test "usage: a subagent transcript that disappears drops out of the totals" {
  make_session
  usage_line msg_a 1000 100 >> "$TRANSCRIPT_PATH"
  usage_line msg_s 500 50 >> "$SUBAGENTS_DIR/agent-a1.jsonl"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [[ "$BL_OUTPUT" == *"1.5k"* ]]
  rm "$SUBAGENTS_DIR/agent-a1.jsonl"
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
  [[ "$BL_OUTPUT" == *"1.0k"* && "$BL_OUTPUT" != *"1.5k"* ]]
}

@test "tokens_out: shows only output tokens, no cache suffix" {
  make_transcript 0 200 0 300
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_out)"
  [[ "$BL_OUTPUT" == *"200"* && "$BL_OUTPUT" != *"+300"* ]]
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

# ---------------------------------------------------------------------------
# cost — prices verified against https://platform.claude.com/docs/en/about-claude/pricing
# ---------------------------------------------------------------------------

# Run the cost segment with a given model display_name and transcript.
_cost_run() {
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\",\"model\":{\"display_name\":\"$1\"}}" "$(_only cost)"
}

@test "cost: Opus 4.8 input priced at \$5/MTok" {
  make_transcript 1000000 0
  _cost_run "Opus 4.8"
  [[ "$BL_OUTPUT" == *'$5.00'* ]]
}

@test "cost: Opus 4.8 output priced at \$25/MTok" {
  make_transcript 0 1000000
  _cost_run "Opus 4.8"
  [[ "$BL_OUTPUT" == *'$25.00'* ]]
}

@test "cost: Opus 4.8 cache read priced at \$0.50/MTok" {
  make_transcript 0 0 1000000 0
  _cost_run "Opus 4.8"
  [[ "$BL_OUTPUT" == *'$0.50'* ]]
}

@test "cost: Opus 4.8 cache write priced at \$6.25/MTok (5m)" {
  make_transcript 0 0 0 1000000
  _cost_run "Opus 4.8"
  [[ "$BL_OUTPUT" == *'$6.25'* ]]
}

@test "cost: Opus 4.1 uses legacy \$15/MTok input pricing" {
  make_transcript 1000000 0
  _cost_run "Opus 4.1"
  [[ "$BL_OUTPUT" == *'$15.00'* ]]
}

@test "cost: model id form 'claude-opus-4-8' parses version (current pricing)" {
  make_transcript 1000000 0
  _cost_run "claude-opus-4-8"
  [[ "$BL_OUTPUT" == *'$5.00'* ]]
}

@test "cost: Haiku 4.5 input priced at \$1/MTok" {
  make_transcript 1000000 0
  _cost_run "Haiku 4.5"
  [[ "$BL_OUTPUT" == *'$1.00'* ]]
}

@test "cost: Haiku 3.5 uses retired \$0.80/MTok input pricing" {
  make_transcript 1000000 0
  _cost_run "claude-3-5-haiku-20241022"
  [[ "$BL_OUTPUT" == *'$0.80'* ]]
}

@test "cost: Sonnet 4.6 input priced at \$3/MTok" {
  make_transcript 1000000 0
  _cost_run "Sonnet 4.6"
  [[ "$BL_OUTPUT" == *'$3.00'* ]]
}

@test "cost: Opus 5 input priced at \$5/MTok" {
  make_transcript 1000000 0
  _cost_run "claude-opus-5"
  [[ "$BL_OUTPUT" == *'$5.00'* ]]
}

@test "cost: Opus 5.5 input priced at \$4/MTok" {
  make_transcript 1000000 0
  _cost_run "Opus 5.5"
  [[ "$BL_OUTPUT" == *'$4.00'* ]]
}

@test "cost: Sonnet 5 input priced at \$2/MTok" {
  make_transcript 1000000 0
  _cost_run "claude-sonnet-5"
  [[ "$BL_OUTPUT" == *'$2.00'* ]]
}

@test "cost: Fable 5.1 input priced at \$10/MTok" {
  make_transcript 1000000 0
  _cost_run "Fable 5.1"
  [[ "$BL_OUTPUT" == *'$10.00'* ]]
}

@test "cost: Fable output priced at \$50/MTok" {
  make_transcript 0 1000000
  _cost_run "claude-fable-5"
  [[ "$BL_OUTPUT" == *'$50.00'* ]]
}

@test "cost: dated model id is not mistaken for a minor version" {
  make_transcript 1000000 0
  _cost_run "claude-opus-5-20260401"
  [[ "$BL_OUTPUT" == *'$5.00'* ]]
}

@test "cost: unknown model falls back to Sonnet pricing" {
  make_transcript 1000000 0
  _cost_run "some-future-model"
  [[ "$BL_OUTPUT" == *'$3.00'* ]]
}

@test "cost: web search billed at \$10 per 1000 requests" {
  make_transcript 0 0 0 0 1000
  _cost_run "Sonnet 4.6"
  [[ "$BL_OUTPUT" == *'$10.00'* ]]
}

@test "cost: web search adds to token cost" {
  make_transcript 1000000 0 0 0 100   # $3.00 tokens + $1.00 (100 searches)
  _cost_run "Sonnet 4.6"
  [[ "$BL_OUTPUT" == *'$4.00'* ]]
}

@test "cost: sub-cent total renders as < \$0.01" {
  make_transcript 100 0
  _cost_run "Opus 4.8"
  [[ "$BL_OUTPUT" == *'< $0.01'* ]]
}

@test "cost: hidden when no tokens and no web searches" {
  make_transcript 0 0 0 0 0
  _cost_run "Opus 4.8"
  stripped=$(printf '%s' "$BL_OUTPUT" | tr -d ' \n')
  [ -z "$stripped" ]
}

# ---------------------------------------------------------------------------
# cost — Claude Code's own total (.cost.total_cost_usd) takes precedence
# ---------------------------------------------------------------------------

@test "cost: uses cost.total_cost_usd from the payload when present" {
  make_transcript 1000000 0   # would estimate \$5.00 on Opus
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\",\"model\":{\"display_name\":\"Opus 4.8\"},\"cost\":{\"total_cost_usd\":12.345}}" "$(_only cost)"
  [[ "$BL_OUTPUT" == *'$12.35'* ]] || [[ "$BL_OUTPUT" == *'$12.34'* ]]
  [[ "$BL_OUTPUT" != *'$5.00'* ]]
}

@test "cost: payload total renders without a transcript" {
  bl_run '{"cost":{"total_cost_usd":0.42}}' "$(_only cost)"
  [[ "$BL_OUTPUT" == *'$0.42'* ]]
}

@test "cost: payload sub-cent total renders as < \$0.01" {
  bl_run '{"cost":{"total_cost_usd":0.001}}' "$(_only cost)"
  [[ "$BL_OUTPUT" == *'< $0.01'* ]]
}

@test "cost: hidden when payload total is zero" {
  bl_run '{"cost":{"total_cost_usd":0}}' "$(_only cost)"
  stripped=$(printf '%s' "$BL_OUTPUT" | tr -d ' \n')
  [ -z "$stripped" ]
}

# ---------------------------------------------------------------------------
# prompt_cache
# ---------------------------------------------------------------------------

# _pc_json JSON-FRAGMENT — payload with a prompt_cache object built from the fragment
_pc_json() { printf '{"prompt_cache":{"caching_observed":true,%s}}' "$1"; }

@test "prompt_cache: warm shows time until expiry" {
  local exp=$(( $(date +%s) + 725 ))
  bl_run "$(_pc_json "\"warm\":true,\"ttl\":\"1h\",\"expires_at\":$exp")" "$(_only prompt_cache)"
  [[ "$BL_OUTPUT" == *"warm 12m"* ]]
  # Well inside the TTL: accent, not warning
  [[ "$BL_OUTPUT_RAW" != *$'\e[38;2;244;162;97m'* ]]
}

@test "prompt_cache: last fifth of the TTL is shown in warning colour" {
  local exp=$(( $(date +%s) + 40 ))
  bl_run "$(_pc_json "\"warm\":true,\"ttl\":\"5m\",\"expires_at\":$exp")" "$(_only prompt_cache)"
  [[ "$BL_OUTPUT" == *"warm <1m"* ]]
  [[ "$BL_OUTPUT_RAW" == *$'\e[38;2;244;162;97m<1m'* ]]
}

@test "prompt_cache: expired prefix renders cold even if the payload says warm" {
  local exp=$(( $(date +%s) - 10 ))
  bl_run "$(_pc_json "\"warm\":true,\"ttl\":\"5m\",\"expires_at\":$exp,\"recache_tokens_if_cold\":45000")" "$(_only prompt_cache)"
  [[ "$BL_OUTPUT" == *"cold ↻45k"* ]]
  [[ "$BL_OUTPUT" != *"warm"* ]]
  [[ "$BL_OUTPUT_RAW" == *$'\e[38;2;244;162;97mcold'* ]]
}

@test "prompt_cache: cold without a recache estimate shows no qualifier" {
  bl_run "$(_pc_json '"warm":false,"expires_at":null,"recache_tokens_if_cold":null')" "$(_only prompt_cache)"
  [[ "$BL_OUTPUT" == *"cold"* && "$BL_OUTPUT" != *"↻"* ]]
}

@test "prompt_cache: warm without expires_at shows no countdown" {
  bl_run "$(_pc_json '"warm":true')" "$(_only prompt_cache)"
  [[ "$BL_OUTPUT" == *"warm"* ]]
  [[ "$BL_OUTPUT" != *"m"*"m"* ]]
}

@test "prompt_cache: hidden when caching was never observed" {
  bl_run '{"prompt_cache":{"caching_observed":false,"warm":false}}' "$(_only prompt_cache)"
  stripped=$(printf '%s' "$BL_OUTPUT" | tr -d ' \n')
  [ -z "$stripped" ]
}

@test "prompt_cache: hidden when the payload has no prompt_cache" {
  bl_run '{}' "$(_only prompt_cache)"
  stripped=$(printf '%s' "$BL_OUTPUT" | tr -d ' \n')
  [ -z "$stripped" ]
}

# ---------------------------------------------------------------------------
# shipped defaults
# ---------------------------------------------------------------------------

@test "defaults: prompt_cache shows, token counters do not, transcript is not read" {
  make_session
  usage_line msg_a 1500 800 >> "$TRANSCRIPT_PATH"
  local exp=$(( $(date +%s) + 600 ))
  bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\",\"context_window\":{\"total_input_tokens\":1500},\"cost\":{\"total_cost_usd\":0.42},\"prompt_cache\":{\"caching_observed\":true,\"warm\":true,\"ttl\":\"1h\",\"expires_at\":$exp}}"
  [[ "$BL_OUTPUT" == *"warm 10m"* || "$BL_OUTPUT" == *"warm 9m"* ]]
  [[ "$BL_OUTPUT" != *"1.5k"* && "$BL_OUTPUT" != *"800"* ]]
  [[ "$BL_OUTPUT" == *'$0.42'* ]]
  # Everything the defaults need is in the payload (as with current Claude Code)
  [ -z "$(ls -A "$BOTTOMLINE_CACHE_DIR")" ]
}

@test "defaults: fallback list matches settings.json segments.enabled" {
  local shipped fallback
  shipped=$(jq -r '.segments.enabled[]' "$BOTTOMLINE_ROOT/settings.json")
  fallback=$(
    source "$BOTTOMLINE_ROOT/lib/segments.sh"
    CFG_ITEMS='' CFG_HIDDEN=''
    bl_resolve_active_segments
    printf '%s' "$ACTIVE_SEGS"
  )
  [ "$shipped" = "$fallback" ]
}
