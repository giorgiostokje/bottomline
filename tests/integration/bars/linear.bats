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

@test "linear: missing api_key renders error segment" {
  bar_run linear "" 0 '{"team":"ENG"}'
  [[ "$BAR_OUTPUT" == *"missing api_key"* ]]
}

@test "linear: missing team renders error segment" {
  bar_run linear "" 0 '{"api_key":"lin_test"}'
  [[ "$BAR_OUTPUT" == *"missing team"* ]]
}

@test "linear: missing api_key takes priority over missing team" {
  bar_run linear "" 0 '{}'
  [[ "$BAR_OUTPUT" == *"missing api_key"* ]]
  [[ "$BAR_OUTPUT" != *"missing team"* ]]
}

@test "linear: auth error from API renders auth failed segment" {
  _mock_curl_fixture "linear_auth_error.json"
  bar_run linear "" 0 '{"api_key":"bad_key","team":"ENG"}'
  [[ "$BAR_OUTPUT" == *"auth failed"* ]]
}

@test "linear: network failure renders offline segment" {
  _mock_curl_fail
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}'
  [[ "$BAR_OUTPUT" == *"offline"* ]]
}
