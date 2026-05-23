# Bottomline

[![Tests](https://github.com/giorgiostokje/bottomline/actions/workflows/tests.yml/badge.svg)](https://github.com/giorgiostokje/bottomline/actions/workflows/tests.yml)

Gradient status line for Claude Code. Renders a bar of ANSI segments below every response, plus optional extra bars with language ecosystem info, git details, or anything you write yourself.

---

## Features

- **Main status line** — model, effort, context usage, directory, git branch, token counts, rate limits, cost
- **Gradient backgrounds** — linear RGB interpolation across any number of keyframes
- **Themes** — activate a named colour palette with one setting
- **Bars** — one or more extra lines below the main status line, rendered by shell scripts or defined inline in JSON
- **Auto-bars** — bars that appear automatically when a project's signal file (e.g. `composer.json`) is detected
- **13 built-in bars** — 12 language bars (PHP, JavaScript, Go, Shell, Python, Rust, Ruby, Java, Swift, Elixir, Salesforce, Git) plus opt-in `random-facts`
- **Nerd Font, emoji, or text-only icons**
- **Skills** — `/bottomline:setup`, `/bottomline:configure`, `/bottomline:debug`, `/bottomline:create-bar`, `/bottomline:create-theme`

---

## Prerequisites

| Requirement | Notes |
|---|---|
| **Bash ≥ 3.2** | macOS ships Bash 3.2, which meets this requirement |
| **jq** | `brew install jq` / `apt install jq` / [jqlang.github.io/jq](https://jqlang.github.io/jq/download/) |
| **Nerd Font** (optional) | Required for `"icons": { "type": "nerd" }` (the default). Download from [nerdfonts.com](https://www.nerdfonts.com/font-downloads), install, and **set it as your terminal's font**. Switch to `"emoji"` or `"none"` if you don't want one. |

---

## Installation

### Via Claude Code plugin system (recommended)

Add this repo as a marketplace source, then install the plugin:

```
/plugin marketplace add giorgiostokje/bottomline
/plugin install bottomline@bottomline
```

Once installed, run the setup skill to wire the status line:

```
/bottomline:setup
```

### Manual clone

**1. Clone the repository:**

```bash
git clone https://github.com/giorgiostokje/bottomline ~/.claude/bottomline
```

**2. Add the `statusLine` block to `~/.claude/settings.json`:**

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/bottomline/bottomline.sh",
    "refreshInterval": 60
  }
}
```

If a `statusLine` key already exists, update its `command` value in place.

**3. Create `~/.claude/bottomline.json`** (your user config file):

```json
{}
```

This is where your personal colour, icon, and segment preferences live. Start with an empty object and add keys as needed.

**4. Verify:**

```bash
echo '{}' | bash ~/.claude/bottomline/bottomline.sh
```

You should see one line of ANSI status line output. If you see nothing, run `/bottomline:debug`.

### Uninstalling

Remove the `statusLine` block from `~/.claude/settings.json`, or restore its `command` value to whatever it pointed to before.

---

## Skills

Bottomline ships five Claude Code skills. Invoke them with `/` in any Claude Code session.

| Skill | Purpose |
|---|---|
| `/bottomline:setup` | Install, verify prerequisites, wire `statusLine.command` |
| `/bottomline:configure` | Change colours, icons, segments, themes, bars — guided or direct |
| `/bottomline:debug` | Diagnose blank output, missing bars, icon boxes, config errors |
| `/bottomline:create-bar` | Write a new project-specific bar script |
| `/bottomline:create-theme` | Design or extract a named colour theme |

---

## Configuration

### TL;DR

Drop this in `~/.claude/bottomline.json` to get going with sensible defaults:

```json
{
  "auto_bars": {
    "enabled": true,
    "disabled": ["git"]
  },
  "segments": {
    "effort": {
      "xhigh": { "color": "warning", "icon": { "nerd": "f071", "emoji": "26a0" } },
      "max":   { "color": "danger",  "icon": { "nerd": "f05e", "emoji": "1f6d1" } }
    },
    "context": {
      "200000": { "color": "warning", "icon": { "nerd": "f071", "emoji": "26a0" } },
      "300000": { "color": "danger",  "icon": { "nerd": "f05e", "emoji": "1f6d1" } }
    },
    "git_branch": {
      "main": { "color": "danger", "icon": { "nerd": "f05e", "emoji": "1f6d1" } }
    },
    "usage": {
      "75": { "color": "warning" },
      "90": { "color": "danger" }
    }
  }
}
```

- Auto-detects language bars for any project that has a signal file (e.g. `composer.json`, `go.mod`), with the `git` bar excluded — the `git_branch` segment on the main line is enough.
- Colours `effort` orange at `xhigh` and red at `max`, each with a matching icon.
- Colours the context gauge orange at 200k tokens and red at 300k, with icons.
- Flags the `main` branch red with an icon as a heads-up that you're on a protected branch.
- Colours rate-limit usage orange at 75% and red at 90%.

Read on for the full reference.

---

### Config file locations

Three files are **deep-merged** at runtime, highest priority first:

| Priority | Path | Purpose |
|---|---|---|
| 1 (highest) | `<project>/.claude/bottomline.json` | Project overrides |
| 2 | `~/.claude/bottomline.json` | User overrides |
| 3 (lowest) | `<plugin-dir>/settings.json` | Shipped defaults — do not edit |

`<plugin-dir>` is the root of the Bottomline installation. For marketplace installs it is `~/.claude/plugins/marketplaces/bottomline`; for a manual clone to the default location it is `~/.claude/bottomline`.

**Merge rules:** Objects are merged recursively — a partial object in a higher-priority file fills in only the keys it defines. Arrays and scalars: the highest-priority non-null value wins entirely.

Create `~/.claude/bottomline.json` if it doesn't exist yet — start with an empty object:

```json
{}
```

Create `<project>/.claude/bottomline.json` at the project root the same way. Add only the keys you want to override; everything else falls through from lower-priority files.

Whether to commit `<project>/.claude/bottomline.json` is up to you: commit it to share colours and thresholds across a team, or add it to `.gitignore` to keep it personal.

---

### Colors & Theming

Set colours under `appearance.colors`. All values are `#rrggbb` hex strings.

```json
{
  "appearance": {
    "colors": {
      "text":       "#e2d5c3",
      "accent":     "#da7756",
      "warning":    "#f4a261",
      "danger":     "#e05a4e",
      "background": ["#2e1f14", "#160f0a"]
    }
  }
}
```

| Key | Default | Description |
|---|---|---|
| `text` | `#e2d5c3` | Primary text colour |
| `accent` | `#da7756` | Icon and highlight colour |
| `warning` | `#f4a261` | Warning threshold colour |
| `danger` | `#e05a4e` | Critical threshold colour |
| `background` | `["#2e1f14","#160f0a"]` | Hex string (flat) or array of hex keyframes (gradient) |

`background` accepts any number of keyframe stops. The gradient is interpolated in linear RGB across the exact number of segments in the bar at render time, so the first keyframe always lands on the first segment and the last keyframe always lands on the last.

#### Themes

A theme is a named JSON file in `<plugin-dir>/themes/` that sets some or all colours. Themes override all per-file colour settings, regardless of which config level activates them.

Activate a theme at any config level:

```json
{ "appearance": { "theme": "catppuccin-mocha" } }
```

A project-level `appearance.theme` overrides the user's default theme for that project.

**Theme priority vs. `appearance.colors`:** theme colours are applied *after* the three-layer config merge, so `appearance.theme` anywhere in the merged result will overwrite any `appearance.colors` values — including those set at project level. If you set a theme at user level and want project-specific colours, override the theme at the project level:

```json
{ "appearance": { "theme": "my-project-theme" } }
```

To disable the user-level theme entirely for a project and fall back to bare `appearance.colors`, set `appearance.theme` to an empty string at project level:

```json
{ "appearance": { "theme": "" } }
```

To create a new theme, run `/bottomline:create-theme`.

#### Included themes

| Theme | Background | Description |
|---|---|---|
| `claude` | Dark brown gradient | Matches Claude's brand orange tones (the default palette) |
| `catppuccin-mocha` | Dark blue-grey gradient | [Catppuccin](https://github.com/catppuccin/catppuccin) Mocha — dark lavender |
| `catppuccin-macchiato` | Dark indigo gradient | Catppuccin Macchiato |
| `catppuccin-frappe` | Dark slate gradient | Catppuccin Frappé |
| `catppuccin-latte` | Light grey gradient | Catppuccin Latte — light mode |

---

### Icons

```json
{
  "appearance": {
    "icons": {
      "type": "nerd",
      "overrides": {
        "model": "e7a2",
        "git_branch": "e0a0"
      }
    }
  }
}
```

| Key | Values | Description |
|---|---|---|
| `type` | `nerd` \| `emoji` \| `none` | Icon set to use |
| `overrides` | `{ "<segment>": "<codepoint>" }` | Per-segment icon override — 4–5 hex digits (e.g. `"e0b4"`) or a literal glyph |

Override keys are segment names: `model`, `effort`, `context`, `directory`, `git_branch`, `tokens_in`, `tokens_out`, `usage_5h`, `usage_7d`, `cost`. `warn` and `danger` are cross-segment state indicators and are also overridable. A shared `tokens` key overrides both `tokens_in` and `tokens_out` at once; a specific key takes precedence over the shared one.

---

### Segments

#### Enabled segments

Control which segments are shown and in what order:

```json
{
  "segments": {
    "enabled": ["model", "effort", "context", "directory", "git_branch", "tokens_in", "tokens_out", "usage_5h", "usage_7d", "cost"]
  }
}
```

Available segment names:

| Segment | Shows |
|---|---|
| `model` | Active Claude model name |
| `effort` | Current effort level with configurable per-level colour and icon |
| `context` | Context window fill gauge + `used/total` in thousands |
| `directory` | Current project directory name (clickable link in supporting terminals) |
| `git_branch` | Current git branch (clickable link to remote on GitHub/GitLab/Bitbucket) |
| `tokens_in` | Freshly processed input tokens (uncached + cache-write) for the session, with cache-read hits shown as a `+` suffix |
| `tokens_out` | Output tokens for the session |
| `usage_5h` | 5-hour rate limit percentage + time until reset |
| `usage_7d` | 7-day rate limit percentage + time until reset |
| `cost` | Estimated session cost (Sonnet/Opus/Haiku pricing) |

#### Disabling segments

`disabled` is unioned across all config levels — a project can suppress a segment without re-listing the user's disabled set:

```json
{ "segments": { "disabled": ["cost", "tokens_in", "tokens_out"] } }
```

#### Separator

Override the separator glyph with a 4–5 hex codepoint string or a literal character:

```json
{ "segments": { "separator": "e0b0" } }
```

#### Per-segment settings

**`segments.effort`** — colour and icon per effort level:

```json
{
  "segments": {
    "effort": {
      "xhigh": { "color": "warning", "icon": { "nerd": "f071", "emoji": "26a0" } },
      "high":  { "color": "accent" }
    }
  }
}
```

**`segments.context`** — token-count thresholds (quoted integers) → colour and icon:

```json
{
  "segments": {
    "context": {
      "160000": { "color": "warning" },
      "190000": { "color": "danger",  "icon": { "nerd": "f071" } }
    }
  }
}
```

**`segments.git_branch`** — per-branch-name colour and icon:

```json
{
  "segments": {
    "git_branch": {
      "main":   { "color": "danger" },
      "master": { "color": "danger" }
    }
  }
}
```

**`segments.usage`** — percentage thresholds (quoted integers) → colour:

```json
{
  "segments": {
    "usage": {
      "75": { "color": "warning" },
      "90": { "color": "danger"  }
    }
  }
}
```

---

### Bars

A bar is an additional line rendered below the main status line. Bars are defined in the `bars` array. Each entry is either a **script bar** (runs a shell script) or an **inline segment bar** (defined entirely in JSON).

#### Script bars

```json
{
  "bars": [
    { "script": "git" },
    { "script": "php", "colors": "inherit" },
    { "script": "~/my-scripts/custom.sh" }
  ]
}
```

`script` is a bare name (resolved from `<project>/.claude/bottomline/bars/<name>.sh` first, then `<plugin-dir>/bars/<name>.sh`) or a path with `/` (supports `~` expansion).

#### Inline segment bars

Define a bar's segments directly in JSON without writing a shell script:

```json
{
  "bars": [
    {
      "segments": [
        {
          "icon": "f121",
          "content": "Production",
          "colors": { "text": "#ffffff", "accent": "#e05a4e" }
        },
        {
          "script": "env-status",
          "icon": { "nerd": "f013", "emoji": "⚙" }
        },
        {
          "file": "~/.deploy-status"
        }
      ],
      "colors": { "background": ["#3a0000","#1a0000"] }
    }
  ]
}
```

Each segment object supports:

| Key | Description |
|---|---|
| `content` | Static text string |
| `file` | Path to a file — renders its contents as text |
| `script` | Bar script name or path — runs it and captures stdout |
| `icon` | Named icon string, a 4–5 hex codepoint, or a per-type object `{ "nerd": "...", "emoji": "..." }` |
| `colors.text` | Foreground text colour — hex or named (`text`, `accent`, `warning`, `danger`) |
| `colors.accent` | Foreground accent colour |
| `ansi` | `true` to pass `content` / `file` / `script` output through as raw ANSI (default: false) |

#### Bar colors

Each bar entry accepts an optional `colors` block that controls the colours passed to its script:

```json
{ "script": "git", "colors": { "text": "#f0ddd8", "accent": "#f05033", "background": ["#1a0c08","#2e1610"] } }
```

`colors` accepts:

| Value | Behaviour |
|---|---|
| Object `{ "text", "accent", "warning", "danger", "background" }` | Overrides individual colour values; any key may be omitted |
| `"inherit"` | Explicitly use the merged config colours; suppresses the bar's built-in language palette |
| Absent | Bar script can apply its own built-in language palette |

`background` in a `colors` block accepts a hex string or an array of keyframes, same as `appearance.colors.background`.

Named colour references (`text`, `accent`, `warning`, `danger`) in colour values resolve to the current merged config colours.

---

### Auto-bars

Auto-bars are bars that appear automatically when a signal file (e.g. `go.mod`, `composer.json`) is found in the project root.

Enable auto-bar detection at user or project level:

```json
{ "auto_bars": { "enabled": true } }
```

Auto-bars are disabled by default (`enabled: false` in `settings.json`).

#### Disabling specific bars

`auto_bars.disabled` is **unioned** across all config levels, so a project config can add exclusions without overwriting the user's:

```json
{ "auto_bars": { "disabled": ["java", "javascript"] } }
```

#### Cache

Auto-detected language bars cache their rendered output in `/tmp` to avoid re-running expensive detection (manifest parsing, binary version checks) on every refresh.

```json
{
  "auto_bars": {
    "refresh_minutes": 5
  }
}
```

`refresh_minutes` sets the cache TTL in minutes for all auto-detected bars. Set to `0` to disable caching for a bar. Default: `5`.

Override per bar without rewriting the full `scripts` array:

```json
{
  "auto_bars": {
    "refresh_minutes": 5,
    "overrides": {
      "go":         { "refresh_minutes": 10 },
      "javascript": { "refresh_minutes": 0 }
    }
  }
}
```

The `git` bar ships with `refresh_minutes: 0` (live data by default). Set `auto_bars.overrides.git.refresh_minutes` to a positive integer to enable git bar caching.

#### Suppressing language palettes

When `inherit_colors` is `true`, all auto-detected bars behave as if `colors: "inherit"` was set — they use the merged config's colour scheme instead of their built-in language palette:

```json
{ "auto_bars": { "inherit_colors": true } }
```

#### Registered signal files

The `auto_bars.scripts` array maps bar names to the signal files that trigger them. The full list is defined in the plugin's `settings.json`. The eleven language bars are auto-detectable; `random-facts` has no signal file and must be added explicitly.

---

### Included bars

#### `git` — Git enrichment

**Signal:** `.git`

Segments: current branch (or detached HEAD / tag), linked worktree name, dirty/clean status with `+lines -lines`, stash count, ahead/behind tracking branch, last commit author and age.

#### `php` — PHP ecosystem

**Signal:** `composer.json`

Segments: PHP runtime version, then any detected packages from `composer.lock`:
- **Frameworks:** Laravel, Lumen, Symfony, CakePHP, Slim
- **Laravel stack:** Octane, Boost (with `boost.json` validation), Reverb, Livewire, Flux (with Pro badge), Inertia (with frontend framework detection)
- **Admin:** Filament
- **Tooling:** Laravel Herd local `.test` URL (clickable)

Built-in palette: purple tones (`#9898e0` accent on near-black background).

#### `javascript` — JavaScript / Node.js ecosystem

**Signal:** `package.json`

Segments: any detected packages from `package.json` with installed versions from `node_modules`:
- **React:** Next.js, React, Remix
- **Mobile:** Expo, React Native
- **Vue:** Nuxt, Vue
- **Svelte:** SvelteKit, Svelte
- **Other:** Angular, Astro, Electron
- **Build:** Vite (suppressed when implied by Nuxt/SvelteKit/Astro)
- **Language:** TypeScript

Built-in palette: yellow tones (`#f7df1e` accent on near-black background).

#### `go` — Go ecosystem

**Signal:** `go.mod`

Segments: Go version from `go.mod`, workspace flag when `go.work` is present.

Built-in palette: cyan tones (`#29bcd8` accent on dark navy background).

#### `shell` — Shell / Bash ecosystem

**Signal:** `.shellcheckrc`

Segments: target shell and running Bash version. Target shell defaults to `bash`; reads the `shell=` directive from `.shellcheckrc` when present (e.g. `sh`, `dash`). ShellCheck version shown as a second segment when `shellcheck` is on `PATH`.

The bar activates when any `.sh` file exists at the project root — users without a `.shellcheckrc` can add the bar explicitly:

```json
{ "bars": [{ "script": "shell" }] }
```

Built-in palette: green tones (`#4eb144` accent on dark forest-green background).

#### `python` — Python ecosystem

**Signal:** `pyproject.toml`, `requirements.txt`, `Pipfile`, `setup.py`

Segments: Python runtime, package manager (Poetry/PDM/Hatch/Pipenv), detected framework with version (Django, FastAPI, or Flask — from `poetry.lock`, `Pipfile.lock`, or `requirements.txt`).

Built-in palette: yellow accent (`#ffd740`) on dark blue background.

#### `rust` — Rust ecosystem

**Signal:** `Cargo.toml`

Segments: Rust, edition from `Cargo.toml`, workspace flag.

Built-in palette: orange-red tones (`#d05a38` accent on dark charcoal background).

#### `ruby` — Ruby ecosystem

**Signal:** `Gemfile`

Segments: Ruby version (from `.ruby-version` or `ruby -e`), detected framework with version from `Gemfile.lock` (Rails, Sinatra, Hanami).

Built-in palette: red tones (`#e05060` accent on dark crimson background).

#### `java` — Java ecosystem

**Signal:** `pom.xml`, `build.gradle`, `build.gradle.kts`

Segments: build tool (Maven or Gradle) with Java version, detected framework (Spring Boot, Quarkus, or Micronaut) with version.

Built-in palette: orange tones (`#ed8b00` accent on near-black amber background).

#### `swift` — Swift ecosystem

**Signal:** `Package.swift`

Segments: Swift tools version from `Package.swift`, Vapor version from `Package.resolved` (falls back to `Package.swift` grep).

Built-in palette: red-orange tones (`#f05138` accent on dark charcoal background).

#### `elixir` — Elixir ecosystem

**Signal:** `mix.exs`

Segments: Elixir version (from `mix.exs`, `.tool-versions`, or `.elixir-version`), Phoenix version from `mix.lock`.

Built-in palette: purple tones (`#a078d8` accent on near-black background).

#### `salesforce` — Salesforce ecosystem

**Signal:** `sfdx-project.json`, `.forceignore`

Segments: SF CLI version, default target org (alias or username) with sandbox indicator when `sfdcLoginUrl` points to `test.salesforce.com`, authenticated username when it differs from the displayed alias, source API version from `sfdx-project.json`, and namespace when one is defined.

Target org is resolved in priority order: project `.sf/config.json` → project `.sfdx/sfdx-config.json` → global `~/.sf/config.json`. Username is resolved from `~/.sf/alias.json` or legacy `~/.sfdx/<alias>.json`.

Built-in palette: Salesforce Lightning brand — cloud blue `#1B96FF` accent on dark navy gradient (`#032D60` → `#0B4B8B`).

#### `random-facts`

No auto-detection signal — add explicitly via `bars`:

```json
{ "bars": [{ "script": "random-facts", "refresh_minutes": 60 }] }
```

Fetches a random fact from the [Useless Facts API](https://uselessfacts.jsph.pl). The result is cached so the API is only called once per interval — the fact changes after `refresh_minutes` minutes (default: 60). Falls back to a built-in set of 10 offline facts when the network is unavailable. Does not use a built-in palette — colours are always taken from the bar's `colors` config or the merged config defaults.

---

### Complete settings reference

All keys, their types, and which config files they belong in.

| Key | Type | Description |
|---|---|---|
| `appearance.theme` | `string` | Name of a theme file in `<plugin-dir>/themes/`. Overrides all colour settings. |
| `appearance.colors.text` | `#rrggbb` | Primary text colour |
| `appearance.colors.accent` | `#rrggbb` | Icon and highlight colour |
| `appearance.colors.warning` | `#rrggbb` | Warning threshold colour |
| `appearance.colors.danger` | `#rrggbb` | Critical/danger threshold colour |
| `appearance.colors.background` | `#rrggbb` or `["#hex", ...]` | Flat colour or gradient keyframes |
| `appearance.icons.type` | `nerd` \| `emoji` \| `none` | Icon set |
| `appearance.icons.overrides` | `{ "name": "codepoint" }` | Per-segment icon overrides |
| `segments.enabled` | `string[]` | Ordered list of segments to render |
| `segments.disabled` | `string[]` | Segments to suppress (unioned across config levels) |
| `segments.separator` | `string` | Segment separator — 4–5 hex codepoint or literal glyph |
| `segments.effort` | `{ "level": { "color", "icon" } }` | Per-effort-level colour and icon |
| `segments.context` | `{ "threshold": { "color", "icon" } }` | Token-count thresholds → colour/icon |
| `segments.git_branch` | `{ "branch": { "color", "icon" } }` | Per-branch-name colour and icon |
| `segments.usage` | `{ "threshold": { "color" } }` | Usage percentage thresholds → colour |
| `bars` | `array` | Explicit bar list — appended after auto-detected bars |
| `bars[].script` | `string` | Bar script name or path |
| `bars[].segments` | `array` | Inline segment bar segments |
| `bars[].colors` | object \| `"inherit"` | Bar colour overrides — object with any of `text`, `accent`, `warning`, `danger`, `background`; or `"inherit"` to use merged config colours and suppress the bar's built-in palette |
| `bars[].refresh_minutes` | `integer` | Cache TTL in minutes for script bars that use `bl_cache_write`. All 14 built-in language bars respect this. `0` disables caching. For auto-detected bars, defaults to `auto_bars.refresh_minutes` unless overridden. |
| `auto_bars.enabled` | `boolean` | Enable auto-bar detection for this config level (default: `false`) |
| `auto_bars.disabled` | `string[]` | Bar names to exclude from auto-detection (unioned across config levels) |
| `auto_bars.inherit_colors` | `boolean` | When `true`, all auto-detected bars behave as `colors: "inherit"` |
| `auto_bars.scripts` | `array` | Registry of `{ "script", "signals" }` entries — defined by the plugin; do not edit |
| `auto_bars.refresh_minutes` | `integer` | Global cache TTL in minutes for all auto-detected bars. `0` disables caching. Default: `5`. |
| `auto_bars.overrides` | `{ "name": { "refresh_minutes": N } }` | Per-bar overrides — object merges cleanly without rewriting `scripts`. |
| `auto_bars.scripts[].refresh_minutes` | `integer` | Shipped per-entry TTL default. Only set in `settings.json`; use `auto_bars.overrides` to override at user/project level. |

**Color value formats** (anywhere a colour is accepted):

| Format | Example | Description |
|---|---|---|
| Hex string | `"#da7756"` | Direct `#rrggbb` colour |
| Named reference | `"accent"` | Resolves to the merged config value for `text`, `accent`, `warning`, or `danger` |

---

## Writing a custom bar

Bar scripts are standalone Bash files that write ANSI segments to stdout using the shared `add_seg` / `flush` helpers.

**Template:**

```bash
#!/usr/bin/env bash

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0
# Add signal file guards:
# [[ ! -f "$PROJ/my-signal-file" ]] && exit 0

source "$BOTTOMLINE_LIB/helpers.sh"

# Apply a built-in palette — respects BOTTOMLINE_BAR_COLORS override
if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#your_text_hex")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#your_accent_hex")")
  _bar_gradient='["#bg_start","#bg_end"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)  IC_EXAMPLE=$'\xef\x80\x80' ;;
  emoji) IC_EXAMPLE='🔥' ;;
  *)     IC_EXAMPLE='' ;;
esac

add_seg "${FG_ACCENT}${IC_EXAMPLE} ${FG_TEXT}hello"

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
```

**Placement:** save to `<project>/.claude/bottomline/bars/<name>.sh`, then reference by name in `<project>/.claude/bottomline.json`:

```json
{ "bars": [{ "script": "mybar" }] }
```

See `/bottomline:create-bar` for the full guide, available environment variables, and testing commands.

---

## Testing

The test suite uses [bats-core](https://github.com/bats-core/bats-core). Install it with `brew install bats-core` (or see `tests/README.md` for other methods), then run from the plugin root:

```bash
# All tests
bats --recursive tests/

# Just unit tests
bats tests/unit/

# Just integration tests (main status line)
bats tests/integration/config.bats tests/integration/segments.bats

# Just bar tests
bats --recursive tests/integration/bars/
```

### Test structure

```
tests/
├── helpers.bash                    # Shared helpers for all tests
├── unit/
│   ├── fmt.bats                    # fmt_n, fmt_k, fmt_remaining
│   └── decode_icon.bats            # decode_icon hex→Unicode
└── integration/
    ├── segments.bats               # Main status line segment rendering
    ├── config.bats                 # Three-layer config merge, themes, thresholds
    └── bars/
        ├── git.bats                # Git enrichment bar
        ├── go.bats                 # Go bar
        ├── php.bats                # PHP bar
        ├── javascript.bats         # JavaScript bar
        ├── python.bats             # Python bar
        ├── rust.bats               # Rust bar
        ├── ruby.bats               # Ruby bar
        ├── java.bats               # Java bar
        ├── swift.bats              # Swift bar
        ├── elixir.bats             # Elixir bar
        ├── salesforce.bats         # Salesforce bar
        └── random-facts.bats       # Random facts bar (offline fallback)
```

---

## Contributing

Contributions welcome — bug reports, new bars, new themes, and improvements to existing scripts.

**New bar scripts** (contributing to the plugin itself) — follow the template in the "Writing a custom bar" section above and check an existing bar (e.g. `bars/go.sh`) for the expected structure. Bars should:

1. Guard at the top — exit silently when the bar doesn't apply.
2. Check `BOTTOMLINE_BAR_COLORS` before applying a language palette so config overrides are respected.
3. Set `_bar_gradient` and call `flush "$_bar_gradient"` at the end.
4. Support all three icon types (`nerd`, `emoji`, and the no-icon fallback).

**New themes** — add a file to `themes/` following the schema in `skills/create-theme/SKILL.md`. All colour keys are optional.

**Bug reports** — include the output of:

```bash
# Set BL_DIR to wherever you installed Bottomline, e.g.:
#   BL_DIR="$HOME/.claude/plugins/marketplaces/bottomline"   # marketplace
#   BL_DIR="$HOME/.claude/bottomline"                        # manual clone
BL_DIR="/path/to/bottomline"

echo '{}' | bash "$BL_DIR/bottomline.sh"
jq '.' "$BL_DIR/settings.json"
jq '.' ~/.claude/bottomline.json 2>/dev/null
bash --version | head -1
command -v jq && jq --version
```

---

## Credits

Built for [Claude Code](https://claude.ai/code).

The Catppuccin themes are derived from the [Catppuccin](https://github.com/catppuccin/catppuccin) colour palette by the Catppuccin contributors, licensed MIT.

Random facts provided by the [Useless Facts API](https://uselessfacts.jsph.pl) by [lukePeavey](https://github.com/lukePeavey/useless-facts).

Nerd Font glyph codepoints from [Nerd Fonts](https://www.nerdfonts.com/) by Ryan McIntyre and contributors, licensed MIT.
