# Linear Bar Clarity — Design Spec

**Date:** 2026-05-25
**Status:** Approved

## Problem

The Linear bar has two distinct usability problems:

1. **Bar identity:** No visual marker identifies it as the Linear bar. When multiple bars stack, it's ambiguous — especially when there is no active cycle.
2. **Segment meaning:** Count-only segments (`in_progress`, `review`, `assigned`, opt-ins) show only an icon + number. Without knowing what each icon represents, the numbers are meaningless.

## Solution Overview

- Add three new named segments: `label`, `team_id`, `team`
- Add short text labels to all count-only segments
- Update the default segment list to include `label` and `team_id`
- Update fixture, test, and doc examples from "Sprint 42" → "Cycle 42" (Linear's actual terminology)

---

## Section 1: New Segments

Three new segments handled in the `case` dispatch in `bars/linear.sh`:

| Segment | Source | Renders |
|---|---|---|
| `label` | static | `◈ Linear` — nerd-font icon in nerd mode; `◈` in emoji/none modes. Always renders; no data dependency. |
| `team_id` | `$_team` config param | accent-coloured team key, e.g. `ENG`, `BML` |
| `team` | API — `teams.nodes[0].name` | team display name, e.g. `Bottomline Engineering`. Silently skips if API returns no name. |

### Icon for `label`

- **nerd mode:** `nf-mdi-rhombus` U+F7A2 (`\xef\x9e\xa2`) — matches Linear's diamond logo
- **emoji mode:** `◈`
- **none mode:** `◈`

### `team_id` rendering

No icon — the key is compact and self-identifying. Rendered in accent colour only (e.g. `ENG`).

### Default segment list

```
Before: ["cycle", "in_progress", "review", "assigned"]
After:  ["label", "team_id", "cycle", "in_progress", "review", "assigned"]
```

`team` is opt-in (not in the default list), consistent with `priority`, `overdue`, `blocked`, etc.

---

## Section 2: Text Labels on Count Segments

All segments that currently render only icon + number get a short text label appended, using Linear's own terminology:

| Segment | Before | After |
|---|---|---|
| `in_progress` | `⏳ 7` | `⏳ 7 wip` |
| `review` | `👁 3` | `👁 3 review` |
| `assigned` | `📋 11` | `📋 11 open` |
| `priority` | `❗ 4` | `❗ 4 urgent` |
| `overdue` | `📅 1` | `📅 1 overdue` |
| `due_soon` | `📅 2` | `📅 2 due soon` |
| `blocked` | `🚫 1` | `🚫 1 blocked` |
| `mentions` | `@ 5` | `@ 5 unread` |
| `cycle_days` | `⌛ 5d left` | unchanged — already has text |
| `cycle` | `🔄 Cycle 42 · 15/23` | unchanged — already self-describing |

---

## Section 3: API and Data Extraction Changes

### GraphQL query change

Add `name` to the team node:

```graphql
teams(filter: { key: { eq: $team } }) {
  nodes {
    name          # new
    activeCycle {
      id name endsAt
      completedIssueCountHistory
      issueCountHistory
    }
  }
}
```

### New extraction variable

```bash
_team_name=$(printf '%s' "$_response" | jq -r '.data.teams.nodes[0].name // empty')
```

`team_id` requires no new extraction — already available as `$_team`.

### Fixture update (`tests/integration/bars/fixtures/linear_success.json`)

- Add `"name": "Bottomline Engineering"` to `teams.nodes[0]`
- Change `activeCycle.name` from `"Sprint 42"` to `"Cycle 42"`

---

## Section 4: Test Changes

### Existing tests updated

- All assertions on `"Sprint 42"` → `"Cycle 42"`

### New tests in `tests/integration/bars/linear.bats`

| Test | Assertion |
|---|---|
| `label segment renders 'Linear'` | `BAR_OUTPUT` contains `Linear` |
| `team_id segment renders team key` | `BAR_OUTPUT` contains `ENG` |
| `team segment renders team display name` | `BAR_OUTPUT` contains `Bottomline Engineering` |
| `in_progress segment includes 'wip' label` | `BAR_OUTPUT` contains `wip` |
| `review segment includes 'review' label` | `BAR_OUTPUT` contains `review` |
| `assigned segment includes 'open' label` | `BAR_OUTPUT` contains `open` |
| `blocked segment includes 'blocked' label` | `BAR_OUTPUT` contains `blocked` |
| `priority segment includes 'urgent' label` | `BAR_OUTPUT` contains `urgent` |
| `overdue segment includes 'overdue' label` | `BAR_OUTPUT` contains `overdue` |
| `mentions segment includes 'unread' label` | `BAR_OUTPUT` contains `unread` |

Segment-list filtering and reordering tests are unaffected.

---

## Section 5: Docs Changes (`docs/bars-reference.html`)

### Segments table

- Add rows for `label`, `team_id`, `team` above the `cycle` row
- Update the "Default?" column to reflect the new default list
- Update descriptions for all count segments to mention the text label

### Terminal mock

- Add `label` segment ("◈ Linear") and `team_id` segment ("ENG") at the start of the rendered bar
- Update cycle mock from "Sprint 42" → "Cycle 42"
- Add text labels (`wip`, `review`, `open`) to count segment mocks

---

## Files Changed

| File | Change |
|---|---|
| `bars/linear.sh` | Add `label`/`team_id`/`team` cases; add text labels to count segments; add `name` to GQL query; add `_team_name` extraction; update `_default_segs` |
| `tests/integration/bars/fixtures/linear_success.json` | Add team `name`; rename cycle from "Sprint 42" to "Cycle 42" |
| `tests/integration/bars/linear.bats` | Update "Sprint 42" assertions; add new segment tests |
| `docs/bars-reference.html` | Update segments table; update terminal mock |
