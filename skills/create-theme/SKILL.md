---
name: bottomline:create-theme
description: Use when the user wants to save a colour palette as a reusable theme file, design a theme inspired by a brand or aesthetic, or make a colour scheme that can be activated across projects with a single setting.
---

# Bottomline: Create a Theme

Use this skill when creating a new colour theme for Bottomline.

## Detect plugin path

Detect where Bottomline is installed (needed for the full-stack test and for `BOTTOMLINE_LIB`):

```bash
[[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "$CLAUDE_PLUGIN_ROOT/bottomline.sh" ]] \
  && echo "$CLAUDE_PLUGIN_ROOT" || echo "NOT_FOUND"
```

Store the output as `BL_DIR`. If the result is `NOT_FOUND`, use the base directory shown in this skill's invocation header as `BL_DIR`.

## Theme File Location

Save themes outside the plugin directory so they survive plugin updates.

| Scope | Path |
|---|---|
| Personal default | `~/.claude/bottomline/themes/<name>.json` |
| Project-scoped | `<project>/.claude/bottomline/themes/<name>.json` |

Bottomline checks these locations before the plugin's built-in `themes/`
directory, so the name resolves automatically — just set it in config:

```json
{ "appearance": { "theme": "<name>" } }
```

To point at any theme file directly, use an absolute or `~/`-prefixed path
as the theme value:

```json
{ "appearance": { "theme": "~/my-themes/ocean.json" } }
```

## Schema

```json
{
  "colors": {
    "text":       "#rrggbb",
    "accent":     "#rrggbb",
    "warning":    "#rrggbb",
    "danger":     "#rrggbb",
    "background": "#rrggbb"
  }
}
```

All keys are optional. Only the keys present in the theme file override the
active merged config — omitting a key leaves the user's own setting in place.

Themes control colours only. Icon type (`nerd`, `emoji`, `none`) is a personal
preference set by the user in their own config — do not include `icons` in a
theme file.

`background` accepts either:
- A single hex string: `"#1e1e2e"` — flat colour across all segments.
- An array of hex keyframes: `["#45475a","#11111b"]` — gradient interpolated
  left-to-right across segments. Any number of keyframes ≥1 is valid.

Theme colours take the highest priority — they override all per-file colour
settings regardless of which config level the `"appearance.theme"` key is set at.

## Starting Point

Ask the user how they want to create the theme:

- **Design from scratch** — derive colours from a description, brand, or palette (see the configure skill's "Deriving colours" guidance), then write the theme file and activate it.
- **Extract current colours** — pull the active `appearance.colors` from the highest-priority config that defines them (project > user), save as a named theme, then replace the inline `colors` block in that config file with an `"appearance.theme"` key pointing to the new file.

## Extracting the Current Colour Scheme

Read colours from the config files in priority order. Use the first file that has an `appearance.colors` block (project level first, then user level):

```bash
# Project level
jq '.appearance.colors // empty' "$(pwd)/.claude/bottomline.json" 2>/dev/null

# User level
jq '.appearance.colors // empty' "$HOME/.claude/bottomline.json" 2>/dev/null
```

Write the extracted colours to the theme file:

```bash
# Replace <name> with the chosen theme name
mkdir -p "$HOME/.claude/bottomline/themes"
jq '{colors: .appearance.colors}' "<source-config>" \
  > "$HOME/.claude/bottomline/themes/<name>.json"
```

(For a project-scoped theme, use `$(pwd)/.claude/bottomline/themes/` instead.)

Then replace the inline `colors` block in the source config with `appearance.theme` and remove `appearance.colors`:

```bash
tmp=$(mktemp) \
  && jq --arg t "<name>" '
       del(.appearance.colors)
       | .appearance.theme = $t
     ' "<source-config>" > "$tmp" \
  && mv "$tmp" "<source-config>"
```

Show the user the resulting theme file and updated config before applying. Confirm they are happy with the name and the extracted colours.

## Example: Catppuccin Mocha

```json
{
  "colors": {
    "text":       "#cdd6f4",
    "accent":     "#cba6f7",
    "warning":    "#f9e2af",
    "danger":     "#f38ba8",
    "background": ["#45475a", "#11111b"]
  }
}
```

## Activating a Theme

Set `appearance.theme` in any config level:

```json
{ "appearance": { "theme": "my-theme-name" } }
```

Project-level activation (`<project>/.claude/bottomline.json`) overrides the
user's default theme for that project.
