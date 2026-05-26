---
name: bottomline:create-bar
description: Creates a new Bottomline bar script — an additional line rendered below the main status line that displays custom project-specific information. Use when the user wants to add a second (or third) status line, surface project data like language version or build status, or build a reusable built-in bar for the Bottomline plugin.
---

# Bottomline: Create a Bar

Use this skill when writing a new bar script — whether project-specific or a
new built-in bar for the plugin.

## What is a Bar?

A bar is a second (or third, fourth…) line rendered below the main status line.
Each bar is a standalone Bash script that writes ANSI-coloured
segments to stdout via the shared `add_seg`/`flush` helpers.

## Bar Script Template

```bash
#!/usr/bin/env bash
# Bottomline bar: <description>

# Guard: exit silently when this bar doesn't apply.
PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0
# Add more guards as needed, e.g.:
# [[ ! -f "$PROJ/go.mod" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

# bl_bar_init handles: cache check, palette fallback, gradient resolution.
# For built-in bars with a brand palette, pass fallback colours and signal files.
# For simple custom bars, you can omit the colour args and use BOTTOMLINE_GRADIENT directly.
bl_bar_init mybar "#e2d5c3" "#da7756" '["#2e1f14","#160f0a"]'

# ── Icons ─────────────────────────────────────────────────────────────────────
bl_icon_set IC_EXAMPLE $'\xef\x80\x80' '🔥'   # replace with your Nerd Font codepoint

# ── Your segments ─────────────────────────────────────────────────────────────
# bl_seg icon label [version] [state] — standard icon/label/version segments
# bl_data_seg icon primary [qualifier] [state] [bullet] — two-element segments
# add_seg directly — only when the format can't fit the helpers above
my_value="hello"
[[ -n "$my_value" ]] && bl_seg "$IC_EXAMPLE" "$my_value"

# ── Flush ─────────────────────────────────────────────────────────────────────
bl_bar_finish "$_bar_gradient"
```

**Simple version (no brand palette, no caching):**

If your bar doesn't need a brand palette and is fast enough to run on every refresh:

```bash
#!/usr/bin/env bash
PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

source "$BOTTOMLINE_LIB/helpers.sh"

bl_icon_set IC_EXAMPLE $'\xef\x80\x80' '🔥'
[[ -n "$my_value" ]] && bl_seg "$IC_EXAMPLE" "$my_value"

bl_bar_finish "$BOTTOMLINE_GRADIENT"
```

## Available Variables (from helpers.sh)

After `source "$BOTTOMLINE_LIB/helpers.sh"` these are ready to use:

| Variable | Description |
|---|---|
| `FG_TEXT` | ANSI escape for the text colour |
| `FG_ACCENT` | ANSI escape for the accent colour |
| `FG_WARN` | ANSI escape for the warning colour |
| `FG_CRIT` | ANSI escape for the danger colour |
| `R` | ANSI reset |
| `B` | ANSI bold |
| `SEP` | Separator glyph |

## Logging

When your bar runs external commands or makes network requests, use `bl_log` (available after `source helpers.sh`) to record outcomes. Logs are written only when the user has set `BOTTOMLINE_LOG_LEVEL` — they're a no-op otherwise.

```bash
# Three levels, in ascending severity:
bl_log debug mybar "curl exit=${_curl_exit}"          # every call outcome — always add these
bl_log warn  mybar "no response, using stale cache"   # recoverable — bar still renders
bl_log error mybar "no response and no fallback"      # unrecoverable — bar exits early
```

**Rule:** add a `warn` or `error` log whenever you fall back or abort — this is how users diagnose missing segments without needing to modify the script. For `debug` logs, follow the convention by command type:

| Command type | When to log `debug` |
|---|---|
| Version / binary invocation | Failure only — `(( _exit != 0 )) && bl_log debug …` |
| cURL / network request | Always — log exit code and response length unconditionally |

## Segment helpers

Use `bl_seg` and `bl_data_seg` (from helpers.sh) instead of constructing `add_seg` strings manually:

```bash
# Standard segment: icon + label + optional version
bl_seg "$IC_EXAMPLE" "My Tool" "$version"

# With state (recolors accent part, appends trailing icon):
bl_seg "$IC_EXAMPLE" "My Tool" "$version" warn   # ⚠ appended
bl_seg "$IC_EXAMPLE" "My Tool" "$version" crit   # 🛑 appended

# Two-element segment with bullet separator:
bl_data_seg "$IC_EXAMPLE" "Primary" "qualifier" "" "1"  # → icon Primary · qualifier

# Two-element segment with state:
bl_data_seg "$IC_EXAMPLE" "App" "offline" warn "1"   # → icon App · offline ⚠
```

Using `add_seg` directly is fine when the format genuinely can't fit these helpers.

## Available Env Vars (from bottomline.sh)

These are exported by `bottomline.sh` before your script runs:

| Env var | Description |
|---|---|
| `BOTTOMLINE_PROJECT_DIR` | Absolute path of the current project |
| `BOTTOMLINE_GRADIENT` | Background gradient JSON (pass to `flush`) |
| `BOTTOMLINE_LIB` | Path to the `lib/` directory |
| `BOTTOMLINE_TEXT_HEX` | Text colour as `#rrggbb` |
| `BOTTOMLINE_ACCENT_HEX` | Accent colour as `#rrggbb` |
| `BOTTOMLINE_WARN_HEX` | Warning colour as `#rrggbb` |
| `BOTTOMLINE_DANGER_HEX` | Danger colour as `#rrggbb` |
| `BOTTOMLINE_BG_R/G/B` | RGB components of the first background stop |
| `BOTTOMLINE_SEP` | Separator glyph (also in `$SEP` after sourcing helpers) |
| `BOTTOMLINE_BOLD` | Bold escape (also in `$B`) |
| `BOTTOMLINE_RESET` | Reset escape (also in `$R`) |
| `BOTTOMLINE_ICON_TYPE` | `nerd`, `emoji`, or `none` |
| `BOTTOMLINE_IC_DANGER` | Pre-resolved icon for the `danger` named icon |
| `BOTTOMLINE_BAR_REFRESH_MINUTES` | Set when the bar entry declares `"refresh_minutes": N` in config. Unset when not configured — apply a sensible default in the script. |

## Caching Network Calls

If your bar fetches external data (an API, a remote service), cache the result
so it only runs once per interval rather than on every status line refresh.

Use `BOTTOMLINE_BAR_REFRESH_MINUTES` (with a script-level default) to compute a
bucket integer — the cache filename changes automatically when the bucket rolls over:

```bash
_refresh_mins="${BOTTOMLINE_BAR_REFRESH_MINUTES:-60}"
_bucket=$(( $(date +%s) / (_refresh_mins * 60) ))
_cache_file="/tmp/bl_mybar_${_bucket}.txt"

value=''
[[ -f "$_cache_file" ]] && value=$(cat "$_cache_file")

if [[ -z "$value" ]]; then
  value=$(curl -sf --max-time 3 'https://example.com/api' 2>/dev/null)
  _curl_exit=$?
  bl_log debug mybar "curl exit=${_curl_exit}"
  if [[ -n "$value" ]]; then
    printf '%s' "$value" > "$_cache_file"
    find /tmp -maxdepth 1 -name 'bl_mybar_*.txt' \
      ! -name "bl_mybar_${_bucket}.txt" -delete 2>/dev/null
  else
    bl_log warn mybar "no response (curl exit=${_curl_exit})"
  fi
fi
```

Users control the interval via `refresh_minutes` in their `bottomline.json`:

```json
{ "bars": [{ "script": "mybar", "refresh_minutes": 30 }] }
```

The `find` cleanup removes stale buckets from `/tmp` on each successful fetch;
`/tmp` is also cleared on reboot, so no manual maintenance is needed.

## Placement

**Project-specific bar** (only runs for this project):
- Save to: `<project>/.claude/bottomline/bars/<name>.sh`
- Reference by name (no path) in `<project>/.claude/bottomline.json`:
  ```json
  { "bars": [{ "script": "mybar" }] }
  ```

**Plugin built-in bar** (available across all projects):
- Save to: `<plugin-dir>/bars/<name>.sh` (e.g. `$HOME/.claude/plugins/marketplaces/bottomline/bars/<name>.sh` for marketplace installs, or `$HOME/.claude/bottomline/bars/<name>.sh` for manual clones).
- To contribute it to the plugin itself, submit a PR to the GitHub repo.
- Optionally register for auto-detection by adding an entry to `auto_bars.scripts` in `settings.json` (plugin file — not a user config).
  ```json
  "auto_bars": {
    "scripts": [
      { "script": "mybar", "signals": ["signal-file.ext", "alt-signal"] }
    ]
  }
  ```
  Signal files are checked relative to the project root; the bar is prepended
  automatically when any signal file is found there.

## Bar Color Overrides

A bar entry in the `bars` config array can carry a `colors` block that overrides
the colors passed to the bar script, or the defaults used for inline segment bars.

**Script bar — full `colors` object** (any key may be omitted):
```json
{ "script": "mybar", "colors": { "text": "#hex", "accent": "#hex", "warning": "#hex", "danger": "#hex", "background": "#hex" } }
```

**Script bar — explicit inherit** (use merged config colors, same as omitting `colors`):
```json
{ "script": "mybar", "colors": "inherit" }
```

When `colors` is an object, the script receives overridden values for
`BOTTOMLINE_TEXT_HEX`, `BOTTOMLINE_ACCENT_HEX`, `BOTTOMLINE_WARN_HEX`,
`BOTTOMLINE_DANGER_HEX`, `BOTTOMLINE_BG_R/G/B`, and `BOTTOMLINE_GRADIENT`,
and `BOTTOMLINE_BAR_COLORS=1` is exported to suppress the bar's built-in palette.
When `colors` is `"inherit"`, `BOTTOMLINE_BAR_COLORS=1` is exported but env vars
are unchanged. When `colors` is absent, the env vars are unchanged and
`BOTTOMLINE_BAR_COLORS` is not set — bar scripts may apply a built-in palette.

**Inline segment bar — bar-level defaults** (individual segments can still
override at segment level with their own `colors` block):
```json
{ "segments": [...], "colors": { "text": "#hex", "accent": "#hex", "background": "#hex" } }
```

Color values accept named colors (`text`, `accent`, `warning`, `danger`) or
hex `#rrggbb`. Background accepts a single hex string.

**Built-in palette pattern** — for bars that have a language/brand identity,
use `bl_bar_init` which handles the `BOTTOMLINE_BAR_COLORS` sentinel internally:

```bash
source "$BOTTOMLINE_LIB/helpers.sh"

# bl_bar_init sets FG_TEXT, FG_ACCENT, _bar_gradient; checks cache; respects config overrides.
bl_bar_init <name> "#text_hex" "#accent_hex" '["#bg_start","#bg_end"]' "$PROJ/<signal-file>"
```

Use `bl_bar_finish "$_bar_gradient"` at the end instead of manual `flush`.

## Testing Your Bar

First detect where Bottomline is installed:

```bash
[[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "$CLAUDE_PLUGIN_ROOT/bottomline.sh" ]] \
  && echo "$CLAUDE_PLUGIN_ROOT" || echo "NOT_FOUND"
```

Store the output as `BL_DIR`. If the result is `NOT_FOUND`, use the base directory shown in this skill's invocation header as `BL_DIR`.

Then set the required env vars and run the script directly:

```bash
BOTTOMLINE_LIB="$BL_DIR/lib" \
BOTTOMLINE_TEXT_HEX="#e2d5c3" \
BOTTOMLINE_ACCENT_HEX="#da7756" \
BOTTOMLINE_WARN_HEX="#f4a261" \
BOTTOMLINE_DANGER_HEX="#e05a4e" \
BOTTOMLINE_BG_R=46 BOTTOMLINE_BG_G=31 BOTTOMLINE_BG_B=20 \
BOTTOMLINE_SEP=$'\xee\x82\xb4' \
BOTTOMLINE_BOLD=$'\e[1m' \
BOTTOMLINE_RESET=$'\e[0m' \
BOTTOMLINE_ICON_TYPE=nerd \
BOTTOMLINE_IC_DANGER=$'\xef\x81\x9e' \
BOTTOMLINE_PROJECT_DIR="$(pwd)" \
BOTTOMLINE_GRADIENT='["#2e1f14","#160f0a"]' \
bash "$BL_DIR/bars/mybar.sh"
```

Or test the full stack (replace the path with a directory matching your bar's
guard condition):

```bash
echo '{"workspace":{"current_dir":"/path/to/project"}}' \
  | bash "$BL_DIR/bottomline.sh"
```
