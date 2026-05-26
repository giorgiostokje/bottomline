---
name: add-bar
description: Step-by-step checklist for adding a new built-in bar script to the Bottomline plugin. Use when contributing a new language or tool bar to bars/ — covers the script, auto-detection registration, and tests.
---

# Add a Built-in Bar

A built-in bar lives in `bars/` and is available to all users. Adding one requires three things: the script itself, an auto-detection entry in `settings.json`, and integration tests.

---

## 1. Write `bars/<name>.sh`

Follow this structure exactly. The `BOTTOMLINE_BAR_COLORS` guard is mandatory for built-in bars — it lets users override the language palette via config.

```bash
#!/usr/bin/env bash
# Bottomline bar: <description>

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

# bl_bar_init handles: cache check, palette fallback, gradient resolution.
# Pass signal files as trailing args for mtime-based cache invalidation.
bl_bar_init <bar_name> "<text_hex>" "<accent_hex>" '["<bg_start>","<bg_end>"]' \
  "$PROJ/<signal-file>"

[[ ! -f "$PROJ/<signal-file>" ]] && exit 0   # hard guard: AFTER bl_bar_init

# ── Icons ─────────────────────────────────────────────────────────────────────
bl_icon_set IC_LANG  $'\x..\x..\x..' '<emoji>'   # U+XXXX  nf-* description
bl_icon_set IC_PM    $'\x..\x..\x..' '<emoji>'
bl_icon_set IC_TEST  $'\x..\x..\x..' '<emoji>'
bl_icon_set IC_LINT  $'\x..\x..\x..' '<emoji>'

# ── Gather data ───────────────────────────────────────────────────────────────
# ... read files, run commands, build segment strings ...

# ── Segments (canonical slot order for language/ecosystem bars) ────────────────
# Use bl_seg for standard icon/label/[version] segments (recommended).
# Use bl_data_seg for two-element segments with optional bullet separator.
# Use add_seg directly only when the format cannot fit these helpers.
#
# Slot order: Runtime → Package manager → Framework → Add-ons → Testing → Tooling

# Slot 1: Runtime
# [[ -n "$lang_version" ]] && bl_seg "$IC_LANG" "<Name>" "$lang_version"

# Slot 2: Package manager (when not implicit)
# [[ -n "$pm_name" ]] && bl_seg "$IC_PM" "$pm_name"

# Slot 3: Framework
# [[ -n "$framework_version" ]] && bl_seg "$IC_FRAMEWORK" "<Framework>" "$framework_version"

# Slot 4: Framework add-ons
# [[ -n "$addon_version" ]] && bl_seg "$IC_ADDON" "<Addon>" "$addon_version"

# Slot 5: Testing (REQUIRED — see CLAUDE.md)
# [[ -n "$test_framework" ]] && bl_seg "$IC_TEST" "$test_framework"

# Slot 6: Tooling (REQUIRED — sub-order: static analysis → service pkgs → ORM/DB → styling → other)
# [[ -n "$linter_version" ]] && bl_seg "$IC_LINT" "<Linter>" "$linter_version"

bl_bar_finish "$_bar_gradient"
```

Key rules:
- Exit silently (`exit 0`) when the bar doesn't apply — never produce output for an irrelevant project.
- `bl_bar_init` handles caching, palette resolution, and gradient setup. Pass signal files as trailing args for mtime-based cache invalidation.
- `bl_bar_finish` checks for empty `_sc` (no-op) and handles cache writing. Pass `"$_bar_gradient"` (set by `bl_bar_init`).

### Logging command failures and network requests

Use `bl_log` (available after `source helpers.sh`) for every external command that can fail and every network request. Logs are no-ops unless the user sets `BOTTOMLINE_LOG_LEVEL`.

**External command (version detection, binary call):**

```bash
_tool_version=$(tool --version 2>/dev/null)
_tool_exit=$?
(( _tool_exit != 0 )) && bl_log debug <name> "tool --version exit=${_tool_exit}"
```

**cURL / network request:**

```bash
_response=$(curl -s -X POST "https://api.example.com/..." \
  --max-time 10 --data "$_body" 2>/dev/null)
_curl_exit=$?
bl_log debug <name> "curl exit=${_curl_exit} response_len=${#_response}"

if [[ -z "$_response" ]]; then
  bl_log error <name> "no response (curl exit=${_curl_exit})"
  # show an offline/error segment or exit 0
  exit 0
fi
```

Use `warn` when the bar degrades gracefully (e.g. falls back to stale cache); use `error` when it exits early with nothing to show.

| Command type | When to log `debug` |
|---|---|
| Version / binary invocation | Failure only — `(( _exit != 0 )) && bl_log debug …` |
| cURL / network request | Always — log exit code and response length unconditionally |


## Segment helpers (from helpers.sh)

Use these instead of constructing `add_seg` strings manually:

| Helper | Signature | Use for |
|--------|-----------|---------|
| `bl_seg` | `bl_seg icon label [version] [state]` | Language/tool segments with optional version |
| `bl_data_seg` | `bl_data_seg icon primary [qualifier] [state] [bullet]` | Two-element segments (e.g., status + count, app + team) |

`state` can be `"warn"` or `"crit"`: recolors the accent part and appends ⚠ or 🛑.
`bullet="1"` inserts `·` between primary and qualifier (use when the two parts are logically independent).

Using `add_seg` directly is fine when the segment format genuinely can't fit these helpers.

---

## 2. Register auto-detection in `settings.json`

Add an entry to `auto_bars.scripts`. List every signal file that indicates this language/tool is in use:

```json
"auto_bars": {
  "scripts": [
    ...
    { "script": "<name>", "signals": ["<signal-file>", "<alt-signal>"] }
  ]
}
```

Signal files are checked relative to the project root. The bar is prepended automatically when **any** listed signal file is found there.

**Placement in the list:** entries are ordered by system integration depth — languages first (deepest to shallowest: `c-cpp`, `rust`, `go`, `shell`, `swift`, `elixir`, `dotnet`, `java`, `kotlin`, `python`, `ruby`, `javascript`, `lua`, `dart`, `php`, `salesforce`), then `git` last (VCS tool, not a language). Insert the new entry at the position that best reflects where the language sits on that spectrum.

`auto_bars.enabled` defaults to `false` in `settings.json`. Users opt in. Do not change the default.

---

## 3. Write `tests/integration/bars/<name>.bats`

```bash
#!/usr/bin/env bats
# Integration tests for the <name> bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "<name>: exits silently when no signal file" {
  bar_run <name> "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "<name>: renders <key info> from <signal file>" {
  # Create the signal file with realistic content
  printf '<content>\n' > "$FAKE_PROJ/<signal-file>"
  bar_run <name> "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"<expected text>"* ]]
}
```

Cover at minimum:
- Silent exit when no signal file is present.
- Renders the primary value (version, name, etc.) when the signal file exists.
- Any conditional segments (workspace mode, tool presence, error state).

---

## Checklist

- [ ] `bars/<name>.sh` written using `bl_bar_init` / `bl_bar_finish` / `bl_icon_set`
- [ ] `bl_bar_init` called with bar name, fallback colours, gradient, and signal files
- [ ] Hard guard exits silently when signal file is absent
- [ ] Signal-file hard guard placed AFTER `bl_bar_init` (not before `source`)
- [ ] `bl_bar_finish "$_bar_gradient"` called at the end (handles empty check + cache write)
- [ ] Segments use `bl_seg` / `bl_data_seg` where format fits (recommended)
- [ ] Language/ecosystem bars: segments in canonical slot order (Runtime → PM → Framework → Add-ons → Testing → Tooling) — required for language bars
- [ ] At least one **testing segment** (slot 5) — see "Language bar segment ordering" in CLAUDE.md
- [ ] At least one **static analysis segment** (slot 6) — linter, type checker, or formatter
- [ ] Slot 6 items ordered: static analysis → service pkgs → ORM/DB → styling → other
- [ ] Testing framework **layering rules** applied (Pest > PHPUnit, JUnit5 > JUnit4, etc.)
- [ ] `bl_log debug` added after every external command that can fail (version checks, binary invocations)
- [ ] `bl_log debug` + `bl_log warn/error` added for every curl/network request
- [ ] Detection uses the correct signal type — dep / config file / binary
- [ ] Entry added to `auto_bars.scripts` in `settings.json`
- [ ] `tests/integration/bars/<name>.bats` written
- [ ] Silent-exit test passes
- [ ] Functional tests cover primary output, testing segment, and static analysis segment
- [ ] Layering suppression test included where the stack has layered frameworks
