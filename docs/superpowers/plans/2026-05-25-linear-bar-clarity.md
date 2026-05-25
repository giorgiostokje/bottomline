# Linear Bar Clarity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `label`, `team_id`, and `team` identity segments to the Linear bar, add short text labels to all count-only segments, and fix fixture/doc cycle names from "Sprint 42" to "Cycle 42".

**Architecture:** All changes stay within four files. The bar script gains three new segment cases and updated count-segment render strings. The fixture gains a team name field and a renamed cycle. Tests are written first (TDD) for every new segment and label. Docs are updated last.

**Tech Stack:** Bash, bats (test runner), jq, Linear GraphQL API, HTML (docs mock).

---

## Files

| File | Change |
|---|---|
| `bars/linear.sh` | Add `IC_LINEAR` icon; add `label`/`team_id`/`team` cases; append text labels to count segments; add `name` to GQL query; add `_team_name` extraction; update `_default_segs` |
| `tests/integration/bars/fixtures/linear_success.json` | Add `"name"` to team node; rename cycle `"Sprint 42"` → `"Cycle 42"` |
| `tests/integration/bars/linear.bats` | Update `"Sprint 42"` assertions to `"Cycle 42"`; add 10 new tests |
| `docs/bars-reference.html` | Add rows for `label`/`team_id`/`team` in segments table; update count segment descriptions; update terminal mock |

---

### Task 1: Update fixture and "Sprint 42" references

**Files:**
- Modify: `tests/integration/bars/fixtures/linear_success.json`
- Modify: `tests/integration/bars/linear.bats`

- [ ] **Step 1: Rewrite the fixture**

Replace the entire contents of `tests/integration/bars/fixtures/linear_success.json` with:

```json
{
  "data": {
    "teams": {
      "nodes": [
        {
          "name": "Bottomline Engineering",
          "activeCycle": {
            "id": "cycle-abc",
            "name": "Cycle 42",
            "completedIssueCountHistory": [12, 14, 15],
            "issueCountHistory": [22, 23, 23],
            "endsAt": "2030-12-31T00:00:00.000Z"
          }
        }
      ]
    },
    "viewer": {
      "id": "viewer-abc",
      "assignedIssues": {
        "nodes": [
          { "state": { "type": "started", "name": "In Progress" }, "priority": 2, "dueDate": null, "cycle": { "id": "cycle-abc" }, "relations": { "nodes": [] } },
          { "state": { "type": "started", "name": "In Progress" }, "priority": 3, "dueDate": null, "cycle": { "id": "cycle-abc" }, "relations": { "nodes": [] } },
          { "state": { "type": "started", "name": "In Progress" }, "priority": 3, "dueDate": null, "cycle": { "id": "cycle-abc" }, "relations": { "nodes": [] } },
          { "state": { "type": "started", "name": "In Progress" }, "priority": 3, "dueDate": null, "cycle": { "id": "cycle-abc" }, "relations": { "nodes": [] } },
          { "state": { "type": "started", "name": "In Progress" }, "priority": 3, "dueDate": null, "cycle": { "id": "cycle-abc" }, "relations": { "nodes": [] } },
          { "state": { "type": "started", "name": "In Progress" }, "priority": 3, "dueDate": null, "cycle": { "id": "cycle-abc" }, "relations": { "nodes": [] } },
          { "state": { "type": "started", "name": "In Progress" }, "priority": 3, "dueDate": null, "cycle": { "id": "cycle-abc" }, "relations": { "nodes": [] } },
          { "state": { "type": "started", "name": "In Review"   }, "priority": 1, "dueDate": null, "cycle": { "id": "cycle-abc" }, "relations": { "nodes": [] } },
          { "state": { "type": "started", "name": "In Review"   }, "priority": 1, "dueDate": null, "cycle": { "id": "cycle-abc" }, "relations": { "nodes": [] } },
          { "state": { "type": "started", "name": "In Review"   }, "priority": 1, "dueDate": null, "cycle": { "id": "cycle-abc" }, "relations": { "nodes": [] } },
          { "state": { "type": "backlog",  "name": "Backlog"     }, "priority": 4, "dueDate": "2020-01-01", "cycle": null, "relations": { "nodes": [{ "type": "blocked_by", "relatedIssue": { "state": { "type": "started" } } }] } }
        ]
      }
    },
    "notificationsUnreadCount": 5
  }
}
```

- [ ] **Step 2: Update "Sprint 42" references in `linear.bats`**

Three occurrences to change:

1. The `renders cycle name` test — change `"Sprint 42"` to `"Cycle 42"`:
   ```bash
   # Before
   [[ "$BAR_OUTPUT" == *"Sprint 42"* ]]
   # After
   [[ "$BAR_OUTPUT" == *"Cycle 42"* ]]
   ```

2. The segment filter test — same change:
   ```bash
   # Before
   [[ "$BAR_OUTPUT" == *"Sprint 42"* ]]
   # After
   [[ "$BAR_OUTPUT" == *"Cycle 42"* ]]
   ```

3. The segment reordering test — update the grep pattern:
   ```bash
   # Before
   pos_cycle=$(printf '%s' "$BAR_OUTPUT" | grep -bo "Sprint" | head -1 | cut -d: -f1)
   # After
   pos_cycle=$(printf '%s' "$BAR_OUTPUT" | grep -bo "Cycle" | head -1 | cut -d: -f1)
   ```

- [ ] **Step 3: Run all tests**

```bash
bats tests/integration/bars/linear.bats
```

Expected: all existing tests pass — the fixture rename is transparent to existing logic.

- [ ] **Step 4: Commit**

```bash
git add tests/integration/bars/fixtures/linear_success.json tests/integration/bars/linear.bats
git commit -m "fix(linear): rename fixture cycle 'Sprint 42' → 'Cycle 42'; add team name"
```

---

### Task 2: Add `label` and `team_id` segments (TDD)

**Files:**
- Modify: `tests/integration/bars/linear.bats`
- Modify: `bars/linear.sh`

- [ ] **Step 1: Write two failing tests**

Add the following two tests inside the `# ── Default segments` section of `linear.bats`, after the existing default-segment tests:

```bash
@test "linear: label segment renders 'Linear'" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["label"]'
  [[ "$BAR_OUTPUT" == *"Linear"* ]]
}

@test "linear: team_id segment renders team key" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["team_id"]'
  [[ "$BAR_OUTPUT" == *"ENG"* ]]
}
```

- [ ] **Step 2: Run to confirm both tests fail**

```bash
bats tests/integration/bars/linear.bats
```

Expected: the two new tests FAIL (unknown segment names produce no output).

- [ ] **Step 3: Add `IC_LINEAR` icon constant to `bars/linear.sh`**

In the icon `case` block (lines 26–50), add `IC_LINEAR` as the first entry in each branch:

```bash
case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_LINEAR=$'\xef\x9e\xa2'     # U+F7A2  nf-mdi-rhombus (Linear diamond logo)
    IC_CYCLE=$'\xef\x8c\x81'      # U+F301  nf-mdi-sync
    IC_PROGRESS=$'\xef\x87\x99'   # U+F1D9  nf-fa-circle_o_notch
    IC_REVIEW=$'\xef\x81\xae'     # U+F06E  nf-fa-eye
    IC_ASSIGNED=$'\xef\x82\xae'   # U+F0AE  nf-fa-tasks
    IC_PRIORITY=$'\xef\x81\xaa'   # U+F06A  nf-fa-exclamation_circle
    IC_OVERDUE=$'\xef\x81\xb3'    # U+F073  nf-fa-calendar
    IC_DUE=$'\xef\x81\xb3'        # U+F073  nf-fa-calendar
    IC_DAYS=$'\xef\x89\x92'       # U+F252  nf-fa-hourglass_half
    IC_BLOCKED=$'\xef\x81\x9e'    # U+F05E  nf-fa-ban
    IC_MENTIONS=$'\xef\x87\xba'   # U+F1FA  nf-fa-at
    IC_WARN=$'\xef\x81\xb1'       # U+F071  nf-fa-warning
    ;;
  emoji)
    IC_LINEAR='◈'
    IC_CYCLE='🔄'; IC_PROGRESS='⏳'; IC_REVIEW='👁'
    IC_ASSIGNED='📋'; IC_PRIORITY='❗'; IC_OVERDUE='📅'; IC_DUE='📅'
    IC_DAYS='⌛'; IC_BLOCKED='🚫'; IC_MENTIONS='@'; IC_WARN='⚠️'
    ;;
  *)
    IC_LINEAR='◈'
    IC_CYCLE=''; IC_PROGRESS=''; IC_REVIEW=''
    IC_ASSIGNED=''; IC_PRIORITY='!'; IC_OVERDUE=''; IC_DUE=''
    IC_DAYS=''; IC_BLOCKED=''; IC_MENTIONS='@'; IC_WARN='!'
    ;;
esac
```

- [ ] **Step 4: Update `_default_segs`**

Find the line that begins with `_default_segs=` (currently `'["cycle","in_progress","review","assigned"]'`) and change it to:

```bash
_default_segs='["label","team_id","cycle","in_progress","review","assigned"]'
```

- [ ] **Step 5: Add `label` and `team_id` cases to the render dispatch**

In the `case "$_seg_name" in` block, insert the two new cases immediately before the existing `cycle)` case:

```bash
    label)
      add_seg "${FG_ACCENT}${IC_LINEAR}${IC_LINEAR:+ }${FG_TEXT}Linear"
      ;;
    team_id)
      add_seg "${FG_ACCENT}${_team}"
      ;;
```

- [ ] **Step 6: Run all tests**

```bash
bats tests/integration/bars/linear.bats
```

Expected: all tests pass including the two new ones.

- [ ] **Step 7: Commit**

```bash
git add bars/linear.sh tests/integration/bars/linear.bats
git commit -m "feat(linear): add label and team_id segments"
```

---

### Task 3: Add `team` segment (TDD)

**Files:**
- Modify: `tests/integration/bars/linear.bats`
- Modify: `bars/linear.sh`

- [ ] **Step 1: Write a failing test**

Add the following test in the `# ── Default segments` section, after the two tests added in Task 2:

```bash
@test "linear: team segment renders team display name" {
  _mock_curl_fixture "linear_success.json"
  bar_run linear "" 0 '{"api_key":"lin_test","team":"ENG"}' '["team"]'
  [[ "$BAR_OUTPUT" == *"Bottomline Engineering"* ]]
}
```

- [ ] **Step 2: Run to confirm the test fails**

```bash
bats tests/integration/bars/linear.bats
```

Expected: the new test FAIL (unknown segment `team` produces no output).

- [ ] **Step 3: Add `name` to the GraphQL query in `bars/linear.sh`**

Find the `_gql` heredoc. Add `name` as the first field inside `teams.nodes { ... }`:

```bash
_gql='query BottomlineLinear($team: String!) {
  teams(filter: { key: { eq: $team } }) {
    nodes {
      name
      activeCycle {
        id name endsAt
        completedIssueCountHistory
        issueCountHistory
      }
    }
  }
  viewer {
    id
    assignedIssues(
      filter: { state: { type: { nin: ["completed","cancelled"] } } }
    ) {
      nodes {
        state { type name }
        priority
        dueDate
        cycle { id }
        relations { nodes { type relatedIssue { state { type } } } }
      }
    }
  }
  notificationsUnreadCount
}'
```

- [ ] **Step 4: Extract `_team_name` from the response**

In the `# ── Data extraction` section, immediately after the line that sets `_cycle_id`, add:

```bash
_team_name=$(printf '%s' "$_response" | jq -r '.data.teams.nodes[0].name // empty')
```

- [ ] **Step 5: Add `team` case to the render dispatch**

Insert immediately after the `team_id)` case added in Task 2:

```bash
    team)
      [[ -n "$_team_name" ]] && \
        add_seg "${FG_TEXT}${_team_name}"
      ;;
```

- [ ] **Step 6: Run all tests**

```bash
bats tests/integration/bars/linear.bats
```

Expected: all tests pass including the new one.

- [ ] **Step 7: Commit**

```bash
git add bars/linear.sh tests/integration/bars/linear.bats
git commit -m "feat(linear): add team segment (display name from API)"
```

---

### Task 4: Add text labels to count segments (TDD)

**Files:**
- Modify: `tests/integration/bars/linear.bats`
- Modify: `bars/linear.sh`

- [ ] **Step 1: Write seven failing label tests**

Add a new section at the bottom of `linear.bats`:

```bash
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
```

- [ ] **Step 2: Run to confirm the new tests fail**

```bash
bats tests/integration/bars/linear.bats
```

Expected: the 7 new label tests FAIL; all existing tests still pass.

- [ ] **Step 3: Update count segment renders in `bars/linear.sh`**

Find each case in the `case "$_seg_name" in` block and update the `add_seg` call to append the text label. Replace the six cases exactly as shown (only the `add_seg` string changes — the guard condition is unchanged):

```bash
    in_progress)
      (( _count_in_progress > 0 )) && \
        add_seg "${FG_ACCENT}${IC_PROGRESS}${IC_PROGRESS:+ }${FG_TEXT}${_count_in_progress} wip"
      ;;
    review)
      (( _count_review > 0 )) && \
        add_seg "${FG_ACCENT}${IC_REVIEW}${IC_REVIEW:+ }${FG_TEXT}${_count_review} review"
      ;;
    assigned)
      (( _count_assigned > 0 )) && \
        add_seg "${FG_ACCENT}${IC_ASSIGNED}${IC_ASSIGNED:+ }${FG_TEXT}${_count_assigned} open"
      ;;
    priority)
      (( _count_priority > 0 )) && \
        add_seg "${FG_WARN}${IC_PRIORITY}${IC_PRIORITY:+ }${FG_TEXT}${_count_priority} urgent"
      ;;
    overdue)
      (( _count_overdue > 0 )) && \
        add_seg "${FG_CRIT}${IC_OVERDUE}${IC_OVERDUE:+ }${FG_TEXT}${_count_overdue} overdue"
      ;;
    due_soon)
      (( _count_due_soon > 0 )) && \
        add_seg "${FG_WARN}${IC_DUE}${IC_DUE:+ }${FG_TEXT}${_count_due_soon} due soon"
      ;;
    cycle_days)
      [[ -n "$_cycle_id" && "$_cycle_days_left" -gt 0 ]] && \
        add_seg "${FG_ACCENT}${IC_DAYS}${IC_DAYS:+ }${FG_TEXT}${_cycle_days_left}d left"
      ;;
    blocked)
      (( _count_blocked > 0 )) && \
        add_seg "${FG_WARN}${IC_BLOCKED}${IC_BLOCKED:+ }${FG_TEXT}${_count_blocked} blocked"
      ;;
    mentions)
      (( _notif_count > 0 )) && \
        add_seg "${FG_ACCENT}${IC_MENTIONS}${IC_MENTIONS:+ }${FG_TEXT}${_notif_count} unread"
      ;;
```

(`cycle_days` is shown for completeness — it already has text and is unchanged.)

- [ ] **Step 4: Run all tests**

```bash
bats tests/integration/bars/linear.bats
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add bars/linear.sh tests/integration/bars/linear.bats
git commit -m "feat(linear): add text labels to count segments (wip, review, open, etc.)"
```

---

### Task 5: Update docs

**Files:**
- Modify: `docs/bars-reference.html`

No automated test — verify visually: `open docs/bars-reference.html` and scroll to the Linear section.

- [ ] **Step 1: Replace the segments `<tbody>` in the Linear table**

Find the `<tbody>` inside the Linear `<table>` (the block beginning with `<tr><td><code>cycle</code>...`) and replace it entirely with:

```html
  <tbody>
    <tr><td><code>label</code></td><td>Yes</td><td>Bar identity — "&#x25C8; Linear"</td><td>Always rendered; no data dependency.</td></tr>
    <tr><td><code>team_id</code></td><td>Yes</td><td>Team key from config (e.g. <code>ENG</code>)</td><td>No icon; accent colour only.</td></tr>
    <tr><td><code>team</code></td><td>No (opt-in)</td><td>Team display name from API (e.g. Bottomline Engineering)</td><td>Hidden when API returns no name.</td></tr>
    <tr><td><code>cycle</code></td><td>Yes</td><td>Cycle name · done/total</td><td>Hidden when no active cycle.</td></tr>
    <tr><td><code>in_progress</code></td><td>Yes</td><td>Count of in-progress issues in the active cycle, labelled "wip"</td><td>Hidden when count is zero. Falls back to all in-progress issues when no active cycle exists.</td></tr>
    <tr><td><code>review</code></td><td>Yes</td><td>Count of issues in review in the active cycle, labelled "review"</td><td>Hidden when count is zero. Falls back to all in-review issues when no active cycle exists.</td></tr>
    <tr><td><code>assigned</code></td><td>Yes</td><td>Total open issues assigned to you, labelled "open"</td><td>Hidden when count is zero.</td></tr>
    <tr><td><code>priority</code></td><td>No (opt-in)</td><td>Count of urgent/high-priority assigned issues, labelled "urgent"</td><td>Warning color. Hidden when count is zero.</td></tr>
    <tr><td><code>overdue</code></td><td>No (opt-in)</td><td>Count of overdue assigned issues, labelled "overdue"</td><td>Danger color. Hidden when count is zero.</td></tr>
    <tr><td><code>due_soon</code></td><td>No (opt-in)</td><td>Count of issues due within N days (default 3), labelled "due soon"</td><td>Warning color. Configure window via <code>params.due_soon_days</code>.</td></tr>
    <tr><td><code>cycle_days</code></td><td>No (opt-in)</td><td>Days remaining in the active cycle</td><td>Hidden when no active cycle or zero days left.</td></tr>
    <tr><td><code>blocked</code></td><td>No (opt-in)</td><td>Count of assigned issues blocked by an open issue, labelled "blocked"</td><td>Warning color. Hidden when count is zero.</td></tr>
    <tr><td><code>mentions</code></td><td>No (opt-in)</td><td>Count of unread notifications, labelled "unread"</td><td>Hidden when count is zero.</td></tr>
  </tbody>
```

- [ ] **Step 2: Replace the terminal mock `<div class="statusline" ...>` block**

Find the `<div class="statusline" data-gradient='["#1a1a2e","#16162a"]'>` block in the Linear section and replace it entirely with:

```html
    <div class="statusline" data-gradient='["#1a1a2e","#16162a"]'>
      <div class="seg">
        <span class="seg-inner">
          <span style="color:#5E6AD2">&#xF7A2;</span>
          <span style="color:#e2e2f0">&nbsp;Linear</span>
        </span>
        <span class="seg-sep">&#xE0B4;</span>
      </div>
      <div class="seg">
        <span class="seg-inner">
          <span style="color:#5E6AD2">ENG</span>
        </span>
        <span class="seg-sep">&#xE0B4;</span>
      </div>
      <div class="seg">
        <span class="seg-inner">
          <span style="color:#5E6AD2">&#xF301;</span>
          <span style="color:#e2e2f0">&nbsp;Cycle 42&nbsp;</span>
          <span style="color:#5E6AD2">·</span>
          <span style="color:#e2e2f0">&nbsp;18/24</span>
        </span>
        <span class="seg-sep">&#xE0B4;</span>
      </div>
      <div class="seg">
        <span class="seg-inner">
          <span style="color:#5E6AD2">&#xF1D9;</span>
          <span style="color:#e2e2f0">&nbsp;3 wip</span>
        </span>
        <span class="seg-sep">&#xE0B4;</span>
      </div>
      <div class="seg">
        <span class="seg-inner">
          <span style="color:#5E6AD2">&#xF06E;</span>
          <span style="color:#e2e2f0">&nbsp;1 review</span>
        </span>
        <span class="seg-sep">&#xE0B4;</span>
      </div>
      <div class="seg">
        <span class="seg-inner">
          <span style="color:#5E6AD2">&#xF0AE;</span>
          <span style="color:#e2e2f0">&nbsp;7 open</span>
        </span>
        <span class="seg-sep">&#xE0B4;</span>
      </div>
    </div>
```

- [ ] **Step 3: Commit**

```bash
git add docs/bars-reference.html
git commit -m "docs(linear): update segments table and terminal mock for clarity update"
```

---

## Spec Coverage Check

| Spec requirement | Task |
|---|---|
| `label` segment renders "◈ Linear" | Task 2 |
| `team_id` segment renders configured team key | Task 2 |
| `team` segment renders API team display name | Task 3 |
| `IC_LINEAR` icon for all three icon modes | Task 2 Step 3 |
| `team_id` is accent-only, no icon | Task 2 Step 5 |
| `team` silently skips when API returns no name | Task 3 Step 5 |
| `name` added to GQL query | Task 3 Step 3 |
| `_team_name` extracted from response | Task 3 Step 4 |
| Default segments updated to include `label` and `team_id` | Task 2 Step 4 |
| `in_progress` shows "N wip" | Task 4 |
| `review` shows "N review" | Task 4 |
| `assigned` shows "N open" | Task 4 |
| `priority` shows "N urgent" | Task 4 |
| `overdue` shows "N overdue" | Task 4 |
| `due_soon` shows "N due soon" | Task 4 |
| `blocked` shows "N blocked" | Task 4 |
| `mentions` shows "N unread" | Task 4 |
| Fixture team name added | Task 1 Step 1 |
| Fixture cycle renamed "Cycle 42" | Task 1 Step 1 |
| Bats assertions updated for "Cycle 42" | Task 1 Step 2 |
| Docs segments table updated | Task 5 Step 1 |
| Docs terminal mock updated | Task 5 Step 2 |
