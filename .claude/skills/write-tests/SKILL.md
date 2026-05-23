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

**Bars that cache network responses** — `bar_run` does not set `BOTTOMLINE_BAR_REFRESH_MINUTES`, so bars default to their script-level fallback (e.g. 60 minutes for `random-facts`). The cache file is keyed on a time bucket, so tests that run the bar twice within the same bucket will return the cached value. To control this in tests, override the env var with a minimal interval and use a predictable project dir as the bucket seed, or just let the bar hit its offline fallback path:

```bash
@test "random-facts: renders offline fact when network unavailable" {
  # Force a fresh bucket (interval=1s) and use a tmp dir so no stale cache exists
  BAR_OUTPUT_RAW=$(
    BOTTOMLINE_PROJECT_DIR="$FAKE_PROJ" \
    BOTTOMLINE_LIB="$BOTTOMLINE_ROOT/lib" \
    BOTTOMLINE_ICON_TYPE=none \
    BOTTOMLINE_GRADIENT='"#1a1a1a"' \
    BOTTOMLINE_BAR_COLORS= \
    BOTTOMLINE_BG_R=26 BOTTOMLINE_BG_G=26 BOTTOMLINE_BG_B=26 \
    BOTTOMLINE_SEP='|' BOTTOMLINE_BOLD='' BOTTOMLINE_RESET='' \
    BOTTOMLINE_TEXT_HEX='#e2d5c3' BOTTOMLINE_ACCENT_HEX='#da7756' \
    BOTTOMLINE_WARN_HEX='#f4a261' BOTTOMLINE_DANGER_HEX='#e05a4e' \
    BOTTOMLINE_BAR_REFRESH_MINUTES=1 \
    bash "$BOTTOMLINE_ROOT/bars/random-facts.sh"
  )
  BAR_OUTPUT=$(printf '%s' "$BAR_OUTPUT_RAW" | strip_ansi)
  [[ "$BAR_OUTPUT" == *"(offline)"* || -n "$BAR_OUTPUT" ]]
}
```

`bar_run` passes `BOTTOMLINE_BAR_REFRESH_MINUTES=0` by default, disabling caching. Use plain `bar_run BAR PROJ` for all standard bar tests — no cache files are created and results are always fresh.

To test cache hit/miss behaviour, pass a positive TTL as the third argument: `bar_run go "$FAKE_PROJ" 60`. See `tests/integration/cache.bats` for the full pattern, including teardown cleanup of `/tmp/bl_*` files.

---

## Testing ecosystem-detection segments

Every language bar exposes two new mandatory segment categories: testing frameworks (slot 5) and static analysis tools (slot 6). Tests must cover three behaviours for each:

**1. Dependency / config-driven detection** — write the signal file with realistic content, assert the segment renders:

```bash
@test "<bar>: renders <linter> when present in lockfile" {
  printf '<lockfile-content>\n' > "$FAKE_PROJ/<lockfile>"
  bar_run <bar> "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"<Linter>"* ]]
}
```

**2. Binary-on-PATH detection** — stub the binary on a temporary `PATH`:

```bash
@test "<bar>: renders <tool> when binary on PATH" {
  printf '#!/bin/sh\necho "<tool> 1.2.3"\n' > "$FAKE_PROJ/<tool>"
  chmod +x "$FAKE_PROJ/<tool>"
  PATH="$FAKE_PROJ:$PATH" bar_run <bar> "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"<tool>"* ]]
}
```

**3. Layering suppression** — for stacks where one testing framework wraps another, assert the base is hidden when the layer is present:

```bash
@test "<bar>: Pest suppresses PHPUnit when both present" {
  printf '%s\n' '{"packages":[{"name":"phpunit/phpunit","version":"v11.0.0"},{"name":"pestphp/pest","version":"v3.0.0"}],"packages-dev":[]}' \
    > "$FAKE_PROJ/composer.lock"
  printf '{"name":"test/app"}\n' > "$FAKE_PROJ/composer.json"
  bar_run php "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"Pest"* ]]
  [[ "$BAR_OUTPUT" != *"PHPUnit"* ]]
}
```

Layering suppression tests are MANDATORY for: php (Pest/PHPUnit), dart (flutter_test/test), swift (Quick/XCTest), go (Ginkgo/testify), java (JUnit5/JUnit4).

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
