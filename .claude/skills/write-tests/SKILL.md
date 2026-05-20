---
name: write-tests
description: Guidance for writing bats unit and integration tests in this repo. Use when adding tests for a new feature, segment, bar, or bug fix.
---

# Writing Tests

All tests use [bats-core](https://github.com/bats-core/bats-core). Every file starts with:

```bash
#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load '../helpers'   # adjust path depth as needed
```

---

## Which kind of test?

| What you're testing | Test type | Helper to use |
|---|---|---|
| A function in `lib/functions.sh` | Unit | `source lib/functions.sh`, call directly |
| A segment in `bottomline.sh` | Integration | `bl_run` |
| A bar script in `bars/` | Integration | `bar_run` |

---

## Unit tests (`tests/unit/`)

Source the library file directly — no fake HOME needed:

```bash
source "$BOTTOMLINE_ROOT/lib/functions.sh"

@test "fmt_n: 1500 becomes 1.5k" {
  run fmt_n 1500
  [ "$output" = "1.5k" ]
}
```

Use `run <function> <args>` and assert on `$output` and `$status`.

---

## Integration tests — segments (`tests/integration/`)

Always wrap with `setup_fake_home` / `teardown_fake_home`:

```bash
setup()    { setup_fake_home; }
teardown() { teardown_fake_home; cleanup_transcript; }
```

Call `bl_run` to run the full script:

```bash
bl_run '<json>'                          # defaults only
bl_run '<json>' '<user_cfg_json>'        # with user config override
bl_run '<json>' '<user_cfg>' '<proj_cfg>' # all three layers
```

Use `$BL_OUTPUT` (ANSI stripped) for text assertions, `$BL_OUTPUT_RAW` for colour assertions.

**Isolating a single segment** — use the `_only` helper from `segments.bats`:

```bash
_only() {
  local segs="$1"
  printf '{"segments":{"enabled":[%s]}}' \
    "$(printf '%s' "$segs" | sed 's/[^,]*/"&"/g')"
}

@test "model: renders display_name" {
  bl_run '{"model":{"display_name":"sonnet"}}' "$(_only model)"
  [[ "$BL_OUTPUT" == *"sonnet"* ]]
}
```

**Token-count segments** — write a transcript file first:

```bash
make_transcript <in> <out> [<cache_read>] [<cache_create>]
# sets $TRANSCRIPT_PATH

bl_run "{\"transcript_path\":\"$TRANSCRIPT_PATH\"}" "$(_only tokens_in)"
```

Add `cleanup_transcript` to `teardown()`.

**Hidden-when-absent test** — strip whitespace and separators to confirm nothing rendered:

```bash
@test "model: hidden when absent from input" {
  bl_run '{}' "$(_only model)"
  stripped=$(printf '%s' "$BL_OUTPUT" | tr -d ' \n')
  [ -z "$stripped" ]
}
```

**Colour / ANSI assertions** — assert on `$BL_OUTPUT_RAW`. Use the exact RGB escape sequence:

```bash
@test "threshold: danger colour fires above 90%" {
  local user_cfg='{"segments":{"usage":{"90":{"color":"danger"}}}}'
  bl_run '{"rate_limits":{"five_hour":{"used_percentage":95}}}' "$user_cfg"
  # Default danger is #e05a4e = rgb(224,90,78)
  [[ "$BL_OUTPUT_RAW" == *$'\e[38;2;224;90;78m'* ]]
}
```

---

## Integration tests — bars (`tests/integration/bars/`)

Use `setup_fake_proj` / `teardown_fake_proj` (not `setup_fake_home`):

```bash
setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }
```

`$FAKE_PROJ` is an empty temp directory. Populate it with whatever the bar's guard checks:

```bash
@test "go: renders version from go.mod" {
  printf 'module example.com/app\n\ngo 1.22\n' > "$FAKE_PROJ/go.mod"
  bar_run go "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"1.22"* ]]
}
```

Use `$BAR_OUTPUT` (stripped) or `$BAR_OUTPUT_RAW` (ANSI).

**Silent-exit test** — verify the bar emits nothing when its signal file is absent:

```bash
@test "<name>: exits silently when no signal file" {
  bar_run <name> "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}
```

Note the `| tr -d ' \n|'` — `bar_run` uses `BOTTOMLINE_SEP='|'` so separators appear as literal pipes.

---

## Critical gotcha: `${var:-{}}` corrupts JSON

Never write `"${var:-{}}"` as a default-to-empty-object expression in any bats-loaded script. Bash parses `${1:-{}` as the full expansion (default = `{`), leaving a bare `}` that is concatenated onto the result. Any JSON argument with nested braces becomes invalid JSON silently.

**Wrong:**
```bash
local json="${1:-{}}"   # appends stray "}" to arguments containing "{"
```

**Correct:**
```bash
local json="$1"
if [[ -z "$json" ]]; then json='{}'; fi
```

This is already applied in `tests/helpers.bash` — follow the same pattern in any new helper functions.
