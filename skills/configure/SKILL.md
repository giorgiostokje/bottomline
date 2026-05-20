---
name: bottomline:configure
description: Configures the Bottomline statusline — segments, colours, icons, themes, separators, and thresholds — at user or project level. Use whenever the user wants to change how their statusline looks or behaves, apply a colour palette (including from a brand name, mood, or visual description), choose which segments to show, set a theme, or tweak any Bottomline setting. Always use this skill rather than editing config files directly.
---

# Bottomline: Configure

Use this skill when changing which segments are shown, adjusting colours or
icons, setting thresholds, applying a theme, or adding project-specific
overrides.

> **Path notation:** `$HOME` refers to the current user's home directory.
> On Linux/macOS this is `/home/<user>` or `/Users/<user>`; on Windows it is
> `%USERPROFILE%` (e.g. `C:\Users\YourName`). In Git Bash and WSL, `$HOME`
> expands automatically.

## Config File Locations

Three files are deep-merged at runtime (highest priority first):

1. `<project>/.claude/bottomline.json` — project overrides
2. `$HOME/.claude/bottomline.json` — user overrides
3. `$HOME/.claude/bottomline/settings.json` — shipped defaults (do not edit)

**Merge rules:** Objects are merged recursively — a partial object in a
higher-priority file fills in only the keys it defines. Arrays and scalars:
the highest-priority non-null value wins entirely.

Always make changes in `$HOME/.claude/bottomline.json` (user) or
`<project>/.claude/bottomline.json` (project). Never edit `settings.json`.

## Config Level

Ask the user whether changes should apply at the **user level** or **project level**:

- **User level** (`$HOME/.claude/bottomline.json`) — applies across all projects.
- **Project level** (`<project>/.claude/bottomline.json`) — applies only to the current project, overrides user-level settings.

Then ensure the chosen config file exists:

**User level:**
```bash
[[ ! -f "$HOME/.claude/bottomline.json" ]] \
  && printf '{}\n' > "$HOME/.claude/bottomline.json" \
  && echo "created" || echo "already exists"
```

**Project level** (run from the project root):
```bash
mkdir -p .claude \
  && [[ ! -f ".claude/bottomline.json" ]] \
  && printf '{}\n' > ".claude/bottomline.json" \
  && echo "created" || echo "already exists"
```

All edits in the steps below go into the chosen file.

## Starting Point

Ask the user how they would like to proceed:

- **Guide me through everything** — walk through each configuration area in order: icon type, colours/theme, segments, separator, thresholds, and bars. Present the current value for each, explain the options, and apply changes as you go.
- **I know what I want** — ask the user what they want to change and jump straight to the relevant section of the Key Reference below.

## Key Reference

### `appearance.colors`

| Key | Default | Description |
|---|---|---|
| `text` | `#e2d5c3` | Primary text colour |
| `accent` | `#da7756` | Icon and highlight colour |
| `warning` | `#f4a261` | Warning threshold colour |
| `danger` | `#e05a4e` | Critical threshold colour |
| `background` | gradient array | Hex string (flat) or array of hex keyframes (gradient) |

**Deriving colours from a brand or visual prompt**

When the user wants colours that match a project's brand or a visual idea, ask them to describe it — a brand name, a URL, a colour palette, a mood, or anything visual (e.g. "match our app's purple-and-teal palette", "something that feels like a sunset", "use Tailwind's indigo-500 as accent"). Derive a cohesive set of hex values for `text`, `accent`, `warning`, `danger`, and `background` from the description, present them to the user for approval, then apply them to the chosen config file.

### `appearance.icons`

| Key | Values | Description |
|---|---|---|
| `type` | `nerd` \| `emoji` \| `none` | Icon set to use |
| `overrides` | `{ "segment": "hex-codepoint or glyph" }` | Per-segment icon overrides |

Keys are segment names: `model`, `effort`, `context`, `directory`, `git_branch`,
`tokens_in`, `tokens_out` (both also respond to the shared `tokens` override key), `usage_5h`, `usage_7d`, `cost`.
`warn` and `danger` are cross-segment state indicators and are also overridable.

### `segments`

| Key | Description |
|---|---|
| `enabled` | Ordered array of segment names to render. Available: `model`, `effort`, `context`, `directory`, `git_branch`, `tokens_in`, `tokens_out`, `usage_5h`, `usage_7d`, `cost` |
| `disabled` | Array of segment names to suppress (union across all config levels) |
| `separator` | Hex codepoint (e.g. `"e0b4"`) or literal glyph for the powerline separator |
| `effort` | Per-level colour/icon: `{ "xhigh": { "color": "warning", "icon": { "nerd": "f071", "emoji": "26a0" } } }` |
| `context` | Token-count thresholds → colour/icon: `{ "200000": { "color": "warning" } }` |
| `git_branch` | Per-branch-name colour/icon: `{ "main": { "color": "danger" } }` |
| `usage` | Percentage thresholds → colour: `{ "90": { "color": "danger" }, "75": { "color": "warning" } }` |

### Top-level keys

| Key | Description |
|---|---|
| `appearance.theme` | Name of a file in `themes/` (e.g. `"catppuccin-mocha"`). Overrides all colour settings in the merged config. Does not affect icon type. |
| `bars` | Explicit bar list. Each entry is a script bar `{ "script": "name", "colors": {...} }` or an inline segment bar `{ "segments": [...], "colors": {...} }`. Appended after auto-detected bars. `colors` may be an object with any of `text`, `accent`, `warning`, `danger`, `background` (hex or named colour), or the string `"inherit"` to explicitly use the merged config colours and suppress the bar's built-in language palette. |
| `auto_bars.enabled` | Boolean. Defaults to `false` — auto-bar detection is off unless explicitly enabled. Set `true` to turn on detection for this config level. |
| `auto_bars.disabled` | Array of bar script names to exclude from auto-detection. Values are unioned across all config levels so a project can add exclusions without re-listing the user's. |
| `auto_bars.inherit_colors` | Boolean. When `true`, all auto-detected bars behave as if `colors: "inherit"` was set — they use the merged config colours instead of their built-in language palette. |

## Going Further

After applying configuration changes, let the user know about two extension points and offer to transition immediately if they are interested:

- **Custom theme** — create a named colour palette in `$HOME/.claude/bottomline/themes/`. Invoke `/bottomline:create-theme` to build one.
- **Custom bar** — add a second (or third…) line below the statusline for project-specific info. Invoke `/bottomline:create-bar` to build one.

If the user wants either, invoke the corresponding skill now.

## Example: user override file

`$HOME/.claude/bottomline.json`:
```json
{
  "appearance": {
    "icons": { "type": "emoji" },
    "colors": { "accent": "#7c3aed" }
  },
  "segments": {
    "enabled": ["model", "context", "git_branch", "usage_5h"],
    "separator": "e0b0"
  }
}
```
