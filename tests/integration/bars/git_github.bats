#!/usr/bin/env bats
# Integration tests: GitHub segments in the git bar.

bats_require_minimum_version 1.5.0
load '../../helpers'

# _mock_bin is prepended to PATH so our fake gh shadows any system gh.
setup() {
  setup_fake_proj

  git -C "$FAKE_PROJ" init -b main 2>/dev/null \
    || { git -C "$FAKE_PROJ" init && git -C "$FAKE_PROJ" checkout -b main 2>/dev/null; }
  git -C "$FAKE_PROJ" config user.email "test@example.com"
  git -C "$FAKE_PROJ" config user.name "TestUser"
  printf 'hello\n' > "$FAKE_PROJ/README.md"
  git -C "$FAKE_PROJ" add .
  git -C "$FAKE_PROJ" commit -m "initial" 2>/dev/null
  git -C "$FAKE_PROJ" remote add origin "https://github.com/owner/repo.git"

  export _mock_bin="$(mktemp -d)"
  export PATH="$_mock_bin:$PATH"
}

teardown() {
  rm -rf "$_mock_bin"
  teardown_fake_proj
}

# Write a fake gh script that reads JSON from env vars.
# Usage: _make_gh '<run-list-json>' '<pr-view-json>'
_make_gh() {
  export GH_MOCK_RUN_JSON="$1"
  export GH_MOCK_PR_JSON="$2"
  cat > "$_mock_bin/gh" << 'MOCK'
#!/usr/bin/env bash
case "$1 $2" in
  "run list") printf '%s' "$GH_MOCK_RUN_JSON" ;;
  "pr view")  printf '%s' "$GH_MOCK_PR_JSON"  ;;
esac
MOCK
  chmod +x "$_mock_bin/gh"
}

# ── Gating ────────────────────────────────────────────────────────────────────

@test "git: no GitHub segments when remote is not github.com" {
  git -C "$FAKE_PROJ" remote set-url origin "https://gitlab.com/owner/repo.git"
  _make_gh '[{"status":"completed","conclusion":"success"}]' \
           '{"state":"OPEN","number":1,"isDraft":false,"reviewDecision":null}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"passed"* ]]
  [[ "$BAR_OUTPUT" != *"PR #"* ]]
}

@test "git: no GitHub segments when gh returns an error" {
  cat > "$_mock_bin/gh" << 'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
  chmod +x "$_mock_bin/gh"
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"passed"* ]]
  [[ "$BAR_OUTPUT" != *"PR #"* ]]
}

@test "git: no GitHub segments when in detached HEAD" {
  git -C "$FAKE_PROJ" checkout --detach HEAD 2>/dev/null
  _make_gh '[{"status":"completed","conclusion":"success"}]' \
           '{"state":"OPEN","number":1,"isDraft":false,"reviewDecision":null}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"passed"* ]]
  [[ "$BAR_OUTPUT" != *"PR #"* ]]
}

# ── CI status ─────────────────────────────────────────────────────────────────

@test "git: CI success shows 'passed'" {
  _make_gh '[{"status":"completed","conclusion":"success"}]' '{}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"passed"* ]]
}

@test "git: CI failure shows 'failed'" {
  _make_gh '[{"status":"completed","conclusion":"failure"}]' '{}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"failed"* ]]
}

@test "git: CI timed_out shows 'timed out'" {
  _make_gh '[{"status":"completed","conclusion":"timed_out"}]' '{}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"timed out"* ]]
}

@test "git: CI in_progress shows 'running'" {
  _make_gh '[{"status":"in_progress","conclusion":null}]' '{}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"running"* ]]
}

@test "git: CI queued shows 'queued'" {
  _make_gh '[{"status":"queued","conclusion":null}]' '{}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"queued"* ]]
}

@test "git: CI cancelled produces no CI segment" {
  _make_gh '[{"status":"completed","conclusion":"cancelled"}]' '{}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"cancelled"* ]]
}

@test "git: no CI segment when run list is empty" {
  _make_gh '[]' '{}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"passed"* ]]
  [[ "$BAR_OUTPUT" != *"failed"* ]]
  [[ "$BAR_OUTPUT" != *"running"* ]]
  [[ "$BAR_OUTPUT" != *"queued"* ]]
}

# ── PR state ──────────────────────────────────────────────────────────────────

@test "git: open PR with no reviews shows PR number" {
  _make_gh '[]' '{"state":"OPEN","number":42,"isDraft":false,"reviewDecision":null}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"PR #42"* ]]
}

@test "git: draft PR shows 'draft'" {
  _make_gh '[]' '{"state":"OPEN","number":7,"isDraft":true,"reviewDecision":null}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"PR #7"* ]]
  [[ "$BAR_OUTPUT" == *"draft"* ]]
}

@test "git: approved PR shows PR number and check mark" {
  _make_gh '[]' '{"state":"OPEN","number":12,"isDraft":false,"reviewDecision":"APPROVED"}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"PR #12 · ✓"* ]]
}

@test "git: changes-requested PR shows 'changes'" {
  _make_gh '[]' '{"state":"OPEN","number":99,"isDraft":false,"reviewDecision":"CHANGES_REQUESTED"}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"PR #99"* ]]
  [[ "$BAR_OUTPUT" == *"changes"* ]]
}

@test "git: closed PR produces no PR segment" {
  _make_gh '[]' '{"state":"CLOSED","number":5,"isDraft":false,"reviewDecision":null}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"PR #5"* ]]
}

@test "git: merged PR produces no PR segment" {
  _make_gh '[]' '{"state":"MERGED","number":3,"isDraft":false,"reviewDecision":null}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"PR #3"* ]]
}

@test "git: empty gh pr view output produces no PR segment" {
  _make_gh '[]' ''
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" != *"PR #"* ]]
}

# ── Combined ──────────────────────────────────────────────────────────────────

@test "git: CI and PR segments both appear" {
  _make_gh '[{"status":"completed","conclusion":"success"}]' \
           '{"state":"OPEN","number":42,"isDraft":false,"reviewDecision":"APPROVED"}'
  bar_run git "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"passed"* ]]
  [[ "$BAR_OUTPUT" == *"PR #42"* ]]
}
