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

source "$BOTTOMLINE_LIB/helpers.sh"

# ── Icons ─────────────────────────────────────────────────────────────────────
case "$BOTTOMLINE_ICON_TYPE" in
  nerd)  IC_EXAMPLE=$'\xef\x80\x80' ;;   # replace with your Nerd Font codepoint
  emoji) IC_EXAMPLE='🔥' ;;
  *)     IC_EXAMPLE='' ;;
esac

# ── Your segments ─────────────────────────────────────────────────────────────
my_value="hello"
[[ -n "$my_value" ]] \
  && add_seg "${FG_ACCENT}${IC_EXAMPLE} ${FG_TEXT}${my_value}"

# ── Flush ─────────────────────────────────────────────────────────────────────
(( ${#_sc[@]} == 0 )) && exit 0
flush "$BOTTOMLINE_GRADIENT"
```

**Optional caching:** if your bar does something expensive (reads many files, calls external tools), use `bl_cache_path` / `bl_cache_write` to cache the rendered output:

```bash
_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
if [[ "$_bl_ttl" -gt 0 ]]; then
  _bl_cache=$(bl_cache_path "mybar" "$_bl_ttl" "$PROJ")
  [[ -f "$_bl_cache" ]] && cat "$_bl_cache" && exit 0
fi

_bl_out=$(
  add_seg "..."
  (( ${#_sc[@]} == 0 )) && exit 0
  flush "$_bar_gradient"
)
[[ "$_bl_ttl" -gt 0 ]] && bl_cache_write "$_bl_cache" "$_bl_out"
printf '%s' "$_bl_out"
```

Control the TTL with `refresh_minutes` in the bar's config entry.

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
  if [[ -n "$value" ]]; then
    printf '%s' "$value" > "$_cache_file"
    find /tmp -maxdepth 1 -name 'bl_mybar_*.txt' \
      ! -name "bl_mybar_${_bucket}.txt" -delete 2>/dev/null
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
apply a palette after `source helpers.sh` but respect the `BOTTOMLINE_BAR_COLORS`
sentinel so config overrides always win:

```bash
source "$BOTTOMLINE_LIB/helpers.sh"

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#text_hex")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#accent_hex")")
  _bar_gradient='["#bg_start","#bg_end"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi
```

Use `flush "$_bar_gradient"` at the end instead of `flush "$BOTTOMLINE_GRADIENT"`.

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
