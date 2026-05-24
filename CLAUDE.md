# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```sh
# Run all tests
bats --recursive tests/

# Unit tests only
bats tests/unit/

# Integration tests only
bats tests/integration/

# Single test file
bats tests/unit/fmt.bats

# Smoke-test the status line (should print one ANSI-coloured status line)
echo '{}' | bash bottomline.sh
```

## Architecture

Bottomline is a Claude Code status line plugin. `bottomline.sh` is invoked by Claude Code on each refresh; it reads the Claude Code JSON payload from stdin, loads config, renders ANSI output to stdout, and exits. No daemon, no state.

### Rendering pipeline

`bottomline.sh` does two things in sequence:

1. **Main status line** — calls `seg()` to accumulate segment strings, then `flush()` to emit them with gradient background colours. Each call to `flush` expands the background config (a hex string or keyframe array) to exactly N stops via piecewise linear RGB interpolation in awk, so gradient endpoints always align with the first and last segment regardless of how many segments are present.

2. **Bars** — after the main line, `bottomline.sh` iterates `CFG_BARS`. Each entry is rendered one of two ways:
   - **Script bar** (`"script"` key) — invoked in a subshell with `BOTTOMLINE_*` env vars. The script sources `lib/helpers.sh` and calls `seg()`/`flush()` itself.
   - **Inline segment bar** (`"segments"` key) — rendered entirely from JSON by the local `seg()`/`flush()` engine inside `bottomline.sh`; no subshell, no script file.
   Both paths must be considered when modifying bar rendering code.

Auto-bar detection (`auto_bars.scripts` in settings.json) inspects signal files in `$cdir` (e.g. `go.mod` → `go.sh`) and prepends matched bars to `CFG_BARS`. Disabled by default in settings.json; users opt in via `~/.claude/bottomline.json`.

### Config system

Three-layer deep-merge at startup:

```
settings.json (shipped defaults)
  ↑ user overrides: ~/.claude/bottomline.json
    ↑ project overrides: <project>/.claude/bottomline.json
```

Objects are merged recursively (partial overrides fill only the keys they define). Arrays and scalars: highest-priority non-null value wins entirely. Implemented as a single `jq -n` call with a recursive `dmerge/2` function in `bottomline.sh`.

**Exception — accumulating keys:** `segments.disabled` and `auto_bars.disabled` are *unioned* across all three config files rather than won by the highest-priority layer. This is implemented with explicit three-file reads outside `dmerge`. Any new config key that should accumulate (not override) needs the same treatment — wiring it through `dmerge` like everything else will silently break the expected behaviour.

Themes sit above per-file color keys: when `appearance.theme` is set, it overrides the four colour scalars and the background, regardless of which config layer set them.

### Library split

- **`lib/functions.sh`** — pure utilities with no global state: `fmt_n`, `fmt_k`, `fmt_remaining`, `decode_icon`. Sourced by `bottomline.sh` and loaded directly in unit tests (`source lib/functions.sh`).
- **`lib/helpers.sh`** — ANSI primitives (`bg3`, `fg3`, `hex_to_rgb`), `expand_bg`, a re-implementation of `seg()`/`flush()` for bar scripts, and the cache helpers `bl_cache_path`/`bl_cache_write`. Reads color values from `BOTTOMLINE_*` env vars. Sourced by bar scripts via `source "$BOTTOMLINE_LIB/helpers.sh"`.

### Test infrastructure

- `tests/helpers.bash` — shared bats helpers:
  - `bl_run JSON [user_cfg] [proj_cfg]` — runs `bottomline.sh` with an isolated fake `$HOME`; sets `$BL_OUTPUT` (ANSI stripped) and `$BL_OUTPUT_RAW`.
  - `bar_run BAR_NAME PROJ_DIR` — runs a bar script directly with controlled env vars; sets `$BAR_OUTPUT` and `$BAR_OUTPUT_RAW`.
  - `make_transcript in out [cache_read] [cache_create]` — writes a minimal JSON-lines transcript to `$TRANSCRIPT_PATH`.
- Unit tests source `lib/functions.sh` directly and call functions without invoking the main script.
- Integration tests always call `setup_fake_home` / `teardown_fake_home` so no test reads the real `~/.claude/bottomline.json`.

**Bats gotcha:** never write `"${var:-{}}"` in test helpers or bats-loaded scripts. Bash parses `${1:-{}` as the expansion (default = `{`) and appends the remaining `}` as a literal, corrupting JSON with nested braces. Use a plain `"$1"` with a separate empty check instead.

### Skills

End-user skills live in `skills/` and are exposed as `/bottomline:<name>` in Claude Code:

| Skill | Purpose |
|---|---|
| `setup` | Wire `statusLine` in settings.json, create user config, verify |
| `configure` | Guide segment, colour, theme, and icon configuration |
| `debug` | Diagnose a non-rendering status line |
| `create-bar` | Scaffold a new bar script |
| `create-theme` | Scaffold a new theme JSON file |

Development skills live in `.claude/skills/` and are invoked by Claude Code agents working on the codebase:

| Skill | Purpose |
|---|---|
| `add-segment` | Add a new built-in segment (multi-file checklist) |
| `add-bar` | Add a new built-in bar script with auto-detection and tests |
| `write-tests` | Write bats unit or integration tests for new features |

## Invariants

### Language bar segment ordering

Every language/ecosystem bar in `bars/` follows this canonical 6-slot order. Slots with nothing to show are silently skipped, but the *order* must never be deviated from:

| Slot | Category        | Examples                                          |
|------|-----------------|---------------------------------------------------|
| 1    | Runtime         | language name + version                           |
| 2    | Package manager | Maven, Poetry, pnpm, Cargo (implicit), npm        |
| 3    | Framework       | Rails, Django, Laravel, Spring Boot, Gin          |
| 4    | Add-ons         | Livewire, Octane, LiveView, Inertia, Ecto, Oban   |
| 5    | Testing         | RSpec, pytest, Jest, JUnit, bats, Pest, Ginkgo    |
| 6    | Tooling         | ShellCheck, golangci-lint, GORM, Tailwind CSS     |

**Required coverage:** every language bar must include at least one slot-5 (testing) and one slot-6 (static analysis) segment when the relevant tool is detected. Bars that physically cannot detect testing (e.g. `salesforce.sh`) document the reason in a comment.

**Tooling sub-order (slot 6):** within the tooling slot, items must appear in this order:

1. Static analysis (linters, type checkers, formatters) — e.g. golangci-lint, RuboCop, PHPStan, Clippy, SwiftLint
2. Business logic / service packages — e.g. Tokio, Sidekiq, Celery
3. ORM / database packages — e.g. GORM, SQLAlchemy, EF Core, Diesel
4. Styling packages — e.g. Tailwind CSS
5. Other items — e.g. Herd URL

**Detection signals**, in priority order: lockfile/manifest dep → config file → binary on `PATH`. Use whichever signal is reliable for the tool. All three are valid; many tools are detectable via more than one.

**Testing framework layering** — when a higher-level framework wraps a lower-level one, show only the higher-level framework:

| Stack  | Base                | Layer                | Rule                                       |
|--------|---------------------|----------------------|--------------------------------------------|
| PHP    | PHPUnit             | Pest                 | Pest detected → show Pest only             |
| Dart   | `test` package      | `flutter_test`       | Flutter app → show `flutter_test` only     |
| Swift  | XCTest              | Quick/Nimble         | Quick present → show Quick, suppress XCTest|
| Go     | go test (stdlib)    | Ginkgo               | Ginkgo present → show Ginkgo, suppress testify |
| Java   | JUnit 4             | JUnit 5              | Both present → show JUnit 5 only           |

**Static analysis / formatter layering** — same rule applies to analysis and formatting tools:

| Stack | Base         | Layer     | Rule                                        |
|-------|--------------|-----------|---------------------------------------------|
| PHP   | PHPStan      | Larastan  | Larastan detected → show Larastan only      |
| PHP   | PHP-CS-Fixer | Pint      | Pint detected → show Pint only              |

Frameworks that serve **different jobs** (unit vs E2E, linting vs formatting, test vs type-check) are *not* suppressed — show all present.

### Icon representation

Icons are stored two ways and must not be mixed up:

- **In `bottomline.sh`** — raw UTF-8 bytes assigned to `NF_*`/`EM_*` constants (e.g. `NF_MODEL=$'\xef\x8b\x9b'`). These are used directly in terminal output.
- **In config JSON** — 4–5 hex digit codepoints (e.g. `"e0b4"`). `decode_icon` in `lib/functions.sh` converts these to Unicode characters at runtime.

Never write raw byte literals into config JSON, and never write hex codepoint strings into `NF_*`/`EM_*` assignments.

`appearance.icons.overrides` values are an exception: they accept either a 4–6 hex digit codepoint *or* a literal glyph/emoji. `decode_icon` passes any string that isn't a pure hex sequence through unchanged, so both forms are valid there.

### `settings.json` is the right file for plugin defaults

The end-user skills say "never edit `settings.json`" — that's correct for users. For plugin development, `settings.json` **is** the file for new segment defaults, `auto_bars` registrations, and shipped threshold values. User and project config files are for overrides only.

### `auto_bars.scripts` ordering

Entries in `auto_bars.scripts` are ordered by **system integration depth**, languages first (deepest to shallowest), `git` last (VCS tool, not a language):

```
rust → go → shell → swift → elixir → dotnet → java → python → ruby → javascript → dart → php → salesforce → git
```

When adding a new bar, insert it at the position that best reflects where the language sits on that spectrum. `git` must always remain last.

### Bar change checklist

Any time a bar is **added** or its **segments change**, update every applicable item below. "Not applicable" is a valid answer, but must be a conscious decision — not an oversight.

| Artifact | When to update |
|---|---|
| `docs/bars-reference.html` | Always — add a new bar card or update the segments table and terminal mocks for an existing bar. |
| `CLAUDE.md` — `auto_bars.scripts` ordering | When adding a new bar — insert it at the correct depth position. |
| `settings.json` — `auto_bars.scripts` | When adding a new bar — register its signal file(s) and script name. |
| `.claude/skills/add-bar` (dev skill) | When the scaffolding process or auto-detection conventions change. |
| `skills/configure/SKILL.md` (end-user skill) | When bar names change or new bars need to appear in the explicit-bars candidate list. |
| `skills/create-bar/SKILL.md` (end-user skill) | When the template or naming conventions for new bars change. |

### `dmerge/2` is duplicated

The `dmerge/2` jq function is copy-pasted verbatim into both `bottomline.sh` (config loading) and `skills/debug/SKILL.md` (the merged-config inspection snippet). If the algorithm changes, update both.
