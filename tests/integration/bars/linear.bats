#!/usr/bin/env bats
# Integration tests for bars/linear.sh

bats_require_minimum_version 1.5.0
load '../../helpers'

# _mock_bin is prepended to PATH so our fake curl shadows any real curl.
setup() {
  _mock_bin=$(mktemp -d)
  export PATH="$_mock_bin:$PATH"
}

teardown() {
  rm -rf "$_mock_bin"
}

# Write a fake curl that outputs a fixture file.
_mock_curl_fixture() {
  local fixture="$1"
  cat > "$_mock_bin/curl" << SCRIPT
#!/usr/bin/env bash
cat "$BATS_TEST_DIRNAME/fixtures/${fixture}"
SCRIPT
  chmod +x "$_mock_bin/curl"
}

# Write a fake curl that fails (non-zero exit, no output).
_mock_curl_fail() {
  cat > "$_mock_bin/curl" << 'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT
  chmod +x "$_mock_bin/curl"
}

# ── Error handling ─────────────────────────────────────────────────────────────

@test "linear: missing api_key produces no output" {
  bar_run linear "" 0 '{"team":"ENG"}'
  [[ -z "$BAR_OUTPUT" ]]
}

@test "linear: missing team produces no output" {
  bar_run linear "" 0 '{"api_key":"lin_test"}'
  [[ -z "$BAR_OUTPUT" ]]
}

@test "linear: missing both params produces no output" {
  bar_run linear "" 0 '{}'
  [[ -z "$BAR_OUTPUT" ]]
}

@test "linear: auth error from API renders auth failed segment" {
  _mock_curl_fixture "linear_auth_error.json"
  bar_run linear "" 0 '{"api_key":"bad_key","team":"ENG"}'
  [[ "$BAR_OUTPUT" == *"API error"* ]]
}

@test "linear: network failure renders offline segment" {
  _mock_curl_fail
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}'
  [[ "$BAR_OUTPUT" == *"offline"* ]]
}

# ── Default segments ───────────────────────────────────────────────────────────

@test "linear: renders cycle name and completed/total" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}'
  [[ "$BAR_OUTPUT" == *"Cycle 42"* ]]
  [[ "$BAR_OUTPUT" == *"15/23"* ]]
}

@test "linear: renders in_progress count (7)" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}'
  [[ "$BAR_OUTPUT" == *"7 wip"* ]]
}

@test "linear: renders review count (3)" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}'
  [[ "$BAR_OUTPUT" == *"3 review"* ]]
}

@test "linear: renders assigned count (11)" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}'
  [[ "$BAR_OUTPUT" == *"11 open"* ]]
}

@test "linear: label segment renders 'Linear' and team key" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["label"]'
  [[ "$BAR_OUTPUT" == *"Linear"* ]]
  [[ "$BAR_OUTPUT" == *"ENG"* ]]
}

@test "linear: team segment renders team display name" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["team"]'
  [[ "$BAR_OUTPUT" == *"Bottomline Engineering"* ]]
}

@test "linear: team segment produces no output when API returns no team name" {
  _mock_curl_fixture "linear_no_team_name.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["team"]'
  [[ -z "$BAR_OUTPUT" ]]
}

@test "linear: BOTTOMLINE_BAR_SEGMENTS filters to listed segments only" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["cycle","assigned"]'
  [[ "$BAR_OUTPUT" == *"Cycle 42"* ]]
  [[ "$BAR_OUTPUT" == *"11"* ]]
  [[ "$BAR_OUTPUT" != *" 7 "* ]]
  [[ "$BAR_OUTPUT" != *" 7|"* ]]
}

@test "linear: BOTTOMLINE_BAR_SEGMENTS reorders segments" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["assigned","cycle"]'
  local pos_assigned pos_cycle
  pos_assigned=$(printf '%s' "$BAR_OUTPUT" | grep -bo "11" | head -1 | cut -d: -f1)
  pos_cycle=$(printf '%s' "$BAR_OUTPUT" | grep -bo "Cycle" | head -1 | cut -d: -f1)
  [[ -n "$pos_assigned" && -n "$pos_cycle" ]]
  (( pos_assigned < pos_cycle ))
}

# ── Caching ────────────────────────────────────────────────────────────────────

@test "linear: writes cache file on successful response" {
  local proj; proj=$(mktemp -d)
  _mock_curl_fixture "linear_success.json"
  bar_run linear "$proj" 60 '{"api_key":"lin_test","team":"ENG"}'
  local count
  count=$(find -L "$proj/.bl_cache" -maxdepth 1 -name "bl_linear_*.txt" 2>/dev/null | wc -l | tr -d ' ')
  rm -rf "$proj"
  (( count >= 1 ))
}

@test "linear: returns cached output on second call (curl not invoked)" {
  local proj; proj=$(mktemp -d)
  _mock_curl_fixture "linear_success.json"
  bar_run linear "$proj" 60 '{"api_key":"lin_test","team":"ENG"}'
  local first_output="$BAR_OUTPUT"
  # Replace mock curl with one that outputs nothing — cache should be used
  cat > "$_mock_bin/curl" << 'SCRIPT'
#!/usr/bin/env bash
printf ''
SCRIPT
  chmod +x "$_mock_bin/curl"
  bar_run linear "$proj" 60 '{"api_key":"lin_test","team":"ENG"}'
  rm -rf "$proj"
  [[ "$BAR_OUTPUT" == "$first_output" ]]
}

@test "linear: shows stale cache on network failure instead of offline segment" {
  local proj; proj=$(mktemp -d)
  # Prime cache
  _mock_curl_fixture "linear_success.json"
  bar_run linear "$proj" 60 '{"api_key":"lin_test","team":"ENG"}'
  local cached_output="$BAR_OUTPUT"
  # Now fail the network — TTL=0 forces cache bypass so we test stale fallback
  _mock_curl_fail
  bar_run linear "$proj" 0 '{"api_key":"lin_test","team":"ENG"}'
  rm -rf "$proj"
  # Stale cache content shown instead of "offline"
  [[ "$BAR_OUTPUT" == "$cached_output" ]]
  [[ "$BAR_OUTPUT" != *"offline"* ]]
}

@test "linear: shows offline segment when network fails and no stale cache exists" {
  _mock_curl_fail
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}'
  [[ "$BAR_OUTPUT" == *"offline"* ]]
}

# ── Opt-in segments ────────────────────────────────────────────────────────────

@test "linear: priority segment shows count of urgent/high issues (4)" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' \
    '["priority"]'
  [[ "$BAR_OUTPUT" == *"4 urgent"* ]]
}

@test "linear: overdue segment shows count of past-due issues (1)" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' \
    '["overdue"]'
  [[ "$BAR_OUTPUT" == *"1 overdue"* ]]
}

@test "linear: due_soon segment shows nothing when no issues due soon" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' \
    '["due_soon"]'
  # Fixture has one issue with dueDate "2020-01-01" (overdue, not due soon)
  # No issue is due in the next 3 days — output should be empty
  [[ -z "$BAR_OUTPUT" ]]
}

@test "linear: cycle_days segment shows days remaining in cycle" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' \
    '["cycle_days"]'
  # Fixture endsAt is 2030-12-31 — far future, many days remaining
  [[ "$BAR_OUTPUT" == *"left"* ]]
}

@test "linear: blocked segment shows count of blocked issues (1)" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' \
    '["blocked"]'
  [[ "$BAR_OUTPUT" == *"1 blocked"* ]]
}

@test "linear: mentions segment shows unread notification count (5)" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' \
    '["mentions"]'
  [[ "$BAR_OUTPUT" == *"5 unread"* ]]
}

@test "linear: unknown segment names in BOTTOMLINE_BAR_SEGMENTS are silently skipped" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' \
    '["cycle","unknown_segment_xyz","assigned"]'
  [[ "$BAR_OUTPUT" == *"Cycle 42"* ]]
  [[ "$BAR_OUTPUT" == *"11"* ]]
  [[ "$BAR_OUTPUT" != *"unknown_segment_xyz"* ]]
}

# ── Segment labels ─────────────────────────────────────────────────────────────

@test "linear: in_progress segment includes 'wip' label" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["in_progress"]'
  [[ "$BAR_OUTPUT" == *"wip"* ]]
}

@test "linear: review segment includes 'review' label" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["review"]'
  [[ "$BAR_OUTPUT" == *"review"* ]]
}

@test "linear: assigned segment includes 'open' label" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["assigned"]'
  [[ "$BAR_OUTPUT" == *"open"* ]]
}

@test "linear: priority segment includes 'urgent' label" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["priority"]'
  [[ "$BAR_OUTPUT" == *"urgent"* ]]
}

@test "linear: overdue segment includes 'overdue' label" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["overdue"]'
  [[ "$BAR_OUTPUT" == *"overdue"* ]]
}

@test "linear: due_soon segment includes 'due soon' label" {
  _mock_curl_fixture "linear_due_soon.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG","due_soon_days":99999}' '["due_soon"]'
  [[ "$BAR_OUTPUT" == *"due soon"* ]]
}

@test "linear: blocked segment includes 'blocked' label" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["blocked"]'
  [[ "$BAR_OUTPUT" == *"blocked"* ]]
}

@test "linear: mentions segment includes 'unread' label" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["mentions"]'
  [[ "$BAR_OUTPUT" == *"unread"* ]]
}
