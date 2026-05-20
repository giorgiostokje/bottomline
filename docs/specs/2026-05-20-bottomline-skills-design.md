# Bottomline Plugin Skills — Design Spec

**Date:** 2026-05-20

## Overview

Five skills that guide Claude when working with the Bottomline plugin. Each covers a single, non-overlapping task type. Skills live at `~/.claude/bottomline/skills/<slug>/SKILL.md` and are declared in `plugin.json`.

## Prerequisite Refactor

Before the `create-bar` skill is usable, the duplicated helper code shared across all bar scripts must be extracted into a single shared library.

**What to extract:** `bg3`, `fg3`, `make_fg`, `hex_to_rgb`, `link`, `expand_bg`, `seg`, `flush` — the functions duplicated verbatim across all bar scripts.

**Target location:** `~/.claude/bottomline/lib/helpers.sh`

**Discovery mechanism:** `bottomline.sh` exports `BOTTOMLINE_LIB="$HOME/.claude/bottomline/lib"` before invoking bar scripts. Bar scripts source the helpers with:

```bash
source "$BOTTOMLINE_LIB/helpers.sh"
```

**Migration:** All existing bar scripts (`bars/*.sh`) must have their local copies of these helpers removed and replaced with the single `source` line above.

## Skills

### `setup`

**Triggers:** Installing Bottomline for the first time, re-wiring the statusLine command, checking whether the plugin is working, uninstalling.

**Content:**
- Prerequisites: Bash ≥4, `jq` on PATH, a Nerd Font installed (or plan to use `emoji`/`none` icon type)
- Wiring: add a `statusLine` block to `~/.claude/settings.json`:
  ```json
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "refreshInterval": 60
  }
  ```
- Create `~/.claude/statusline.sh` as a stable shim:
  ```bash
  #!/usr/bin/env bash
  exec bash "$HOME/.claude/bottomline/bottomline.sh"
  ```
- Make shim executable: `chmod +x ~/.claude/statusline.sh`
- Manual test: `echo '{}' | bash ~/.claude/bottomline/bottomline.sh`
- Uninstall: remove the `statusLine` block from `settings.json` and delete the shim

### `configure`

**Triggers:** Changing which segments are shown or their order, adjusting colors, changing icons or separator glyph, setting thresholds, applying a theme, adding project-specific overrides.

**Content:**
- Config merge order (highest priority wins): `<project>/.claude/bottomline.json` → `~/.claude/bottomline.json` → `~/.claude/bottomline/settings.json`
- Objects are deep-merged; arrays and scalars take the highest-priority non-null value
- Key reference:
  - `appearance.colors` — `text`, `accent`, `warning`, `danger`, `background` (hex string or gradient array)
  - `appearance.icons.type` — `nerd`, `emoji`, or `none`
  - `appearance.icons.overrides` — per-icon overrides (hex codepoint or literal glyph)
  - `segments.enabled` — ordered array of segment names; controls what renders and in what order
  - `segments.disabled` — array of segment names to suppress even if listed in `enabled`
  - `segments.separator` — hex codepoint (e.g. `"e0b4"`) or literal glyph
  - `segments.effort`, `segments.context`, `segments.git_branch`, `segments.usage` — threshold/color/icon objects
  - `theme` — name of a file in `themes/` (e.g. `"catppuccin-mocha"`); overrides all color and icon settings
  - `project_aware` — boolean; set to `false` to disable auto-bar detection
  - `bars` — explicit bar list for the current config level
  - `disabled_auto_bars` — array of bar names to exclude from auto-detection (union across all config levels)
- Project-level overrides go in `<project>/.claude/bottomline.json`; user-level in `~/.claude/bottomline.json`

### `create-bar`

**Triggers:** Writing a new bar script, whether project-specific or a new built-in bar for the plugin.

**Content:**
- Source the shared helpers at the top of every bar script:
  ```bash
  source "$BOTTOMLINE_LIB/helpers.sh"
  ```
- Available environment variables (exported by `bottomline.sh`):
  - Colors: `BOTTOMLINE_TEXT_HEX`, `BOTTOMLINE_ACCENT_HEX`, `BOTTOMLINE_WARN_HEX`, `BOTTOMLINE_DANGER_HEX`
  - Background: `BOTTOMLINE_BG_R/G/B` (RGB components of the first background stop)
  - Rendering: `BOTTOMLINE_SEP`, `BOTTOMLINE_BOLD`, `BOTTOMLINE_RESET`
  - Icons: `BOTTOMLINE_ICON_TYPE`, `BOTTOMLINE_IC_FACT`
  - Context: `BOTTOMLINE_PROJECT_DIR`, `BOTTOMLINE_GRADIENT`
  - Library: `BOTTOMLINE_LIB`
- Build ANSI color variables from the hex env vars using helpers from `lib/helpers.sh`
- Add segments with `seg "content"`, flush at the end with `flush "$BOTTOMLINE_GRADIENT"`
- Exit with `exit 0` early (no output) when the bar doesn't apply to the current project
- Placement:
  - **Project-specific:** `<project>/.claude/bottomline/bars/<name>.sh` — referenced by name (no path) in the project's `bottomline.json`
  - **Plugin built-in:** `~/.claude/bottomline/bars/<name>.sh` — auto-detectable across all projects
- Auto-detection: register the bar in `settings.json` under `auto_bars` with signal files:
  ```json
  { "script": "mybar", "signals": ["signal-file.ext"] }
  ```
  Signal files are checked relative to the project root; the bar is prepended automatically when any signal matches.

### `create-theme`

**Triggers:** Creating a new color theme for Bottomline.

**Content:**
- Theme file location: `~/.claude/bottomline/themes/<name>.json`
- Schema:
  ```json
  {
    "colors": {
      "text":       "#hex",
      "accent":     "#hex",
      "warning":    "#hex",
      "danger":     "#hex",
      "background": "#hex or [\"#hex\", \"#hex\"]"
    },
    "icons": {
      "type": "nerd | emoji | none"
    }
  }
  ```
- All keys are optional; only the keys present in the theme file override the active config
- `background` accepts a single hex string (flat color) or an array of hex keyframes (gradient, interpolated across segments)
- Activate by setting `"theme": "<name>"` in any config level; theme colors override all per-file color and icon settings at that level and below

### `debug`

**Triggers:** No statusLine output, icon boxes/squares rendering instead of glyphs, a bar not appearing when expected, wrong colors, the statusLine command not firing at all.

**Diagnostic checklist:**
1. **Manual test** — `echo '{}' | bash ~/.claude/bottomline/bottomline.sh`. If this produces no output, the issue is in the script itself, not the wiring.
2. **Hook wiring** — confirm `settings.json` has a `statusLine.command` pointing to `~/.claude/statusline.sh` and the shim file exists and is executable (`ls -l ~/.claude/statusline.sh`).
3. **`jq` on PATH** — `which jq`. All config loading and JSON parsing silently fails without it.
4. **Icon boxes** — the terminal font doesn't include Nerd Font glyphs. Fix: install a Nerd Font, or set `appearance.icons.type` to `"emoji"` or `"none"` in `~/.claude/bottomline.json`.
5. **Config merge inspection** — run the merge manually to check what config is actually active:
   ```bash
   jq -n \
     --argjson s "$(jq '.' ~/.claude/bottomline/settings.json)" \
     --argjson u "$(jq '.' ~/.claude/bottomline.json 2>/dev/null || echo null)" \
     'if $u == null then $s else $s * $u end'
   ```
6. **Bar not appearing** — check `BOTTOMLINE_PROJECT_DIR` is set (test with real session data, not `echo '{}'`); verify the signal file exists in the project root; confirm the bar name is not in `disabled_auto_bars`.
7. **Bash version** — `bash --version`. Bottomline requires Bash ≥4 (macOS ships Bash 3 by default; install via Homebrew).
