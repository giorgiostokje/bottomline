---
name: bottomline:configure
description: Configures the Bottomline status line — segments, colours, icons, themes, separators, and thresholds — at user or project level. Use whenever the user wants to change how their status line looks or behaves, apply a colour palette (including from a brand name, mood, or visual description), choose which segments to show, set a theme, or tweak any Bottomline setting. Always use this skill rather than editing config files directly.
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
3. `<plugin-dir>/settings.json` — shipped defaults (do not edit)

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

## Claude Plan vs API

Before diving into configuration, ask:

> "Are you using Claude via a subscription plan (claude.ai) or the Claude API?"

**Subscription plan:**

Ask: "Would you like to see Claude API cost approximations in the status line?"

- **No** — disable the `cost` segment so it never appears:

  ```bash
  tmp=$(mktemp) \
    && jq '.segments.disabled += ["cost"]' "$HOME/.claude/bottomline.json" > "$tmp" \
    && mv "$tmp" "$HOME/.claude/bottomline.json"
  ```

- **Yes** — leave `cost` enabled (it is on by default); no action needed.

**Claude API:**

The `usage_5h` and `usage_7d` segments track subscription rate-limit consumption and are not meaningful for API users. Disable them:

```bash
tmp=$(mktemp) \
  && jq '.segments.disabled += ["usage_5h", "usage_7d"]' "$HOME/.claude/bottomline.json" > "$tmp" \
  && mv "$tmp" "$HOME/.claude/bottomline.json"
```

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
| `separator` | Hex codepoint (e.g. `"e0b4"`) or literal glyph for the segment separator |
| `effort` | Per-level colour/icon: `{ "xhigh": { "color": "warning", "icon": { "nerd": "f071", "emoji": "26a0" } } }` |
| `context` | Token-count thresholds → colour/icon: `{ "200000": { "color": "warning" } }` |
| `git_branch` | Per-branch-name colour/icon: `{ "main": { "color": "danger" } }` |
| `usage` | Percentage thresholds → colour: `{ "90": { "color": "danger" }, "75": { "color": "warning" } }` |

### Top-level keys

| Key | Description |
|---|---|
| `appearance.theme` | Name of a file in `themes/` (e.g. `"catppuccin-mocha"`). Overrides all colour settings in the merged config. Does not affect icon type. |
| `bars` | Explicit bar list. Each entry is a script bar `{ "script": "name", "colors": {...}, "refresh_minutes": N }` or an inline segment bar `{ "segments": [...], "colors": {...} }`. Appended after auto-detected bars. `colors` may be an object with any of `text`, `accent`, `warning`, `danger`, `background` (hex or named colour), or the string `"inherit"` to explicitly use the merged config colours and suppress the bar's built-in language palette. `refresh_minutes` controls how long the bar caches external data (e.g. API responses) between fetches; supported by bars that make network calls (e.g. `random-facts`). |
| `auto_bars.enabled` | Boolean. Defaults to `false` — auto-bar detection is off unless explicitly enabled. Set `true` to turn on detection for this config level. |
| `auto_bars.disabled` | Array of bar script names to exclude from auto-detection. Values are unioned across all config levels so a project can add exclusions without re-listing the user's. |
| `auto_bars.inherit_colors` | Boolean. When `true`, all auto-detected bars behave as if `colors: "inherit"` was set — they use the merged config colours instead of their built-in language palette. |

## Threshold Alerts

### Context window thresholds

The `context` segment shows a fill gauge and a `used/total` token count. By
default no thresholds are set — the count always uses the text colour.

Ask the user whether they would like colour alerts as the conversation
approaches the model's context limit:

- **Recommended defaults** (from the Bottomline quick-start guide):
  - **200,000 tokens** → warning colour with a ⚠ icon
  - **300,000 tokens** → danger colour with a 🚫 icon

If the user agrees to the recommended defaults:

```bash
tmp=$(mktemp) \
  && jq '.segments.context = {
    "300000": { "color": "danger",  "icon": { "nerd": "f05e", "emoji": "1f6d1" } },
    "200000": { "color": "warning", "icon": { "nerd": "f071", "emoji": "26a0" } }
  }' "$HOME/.claude/bottomline.json" > "$tmp" \
  && mv "$tmp" "$HOME/.claude/bottomline.json"
```

If the user wants custom thresholds, apply them with the same structure.
Always order keys from highest to lowest — this mirrors the evaluation order
and keeps the file readable.

Keys are token counts (quoted integers); values are
`{ "color": "warning"|"danger"|"accent"|"text", "icon": { "nerd": "hex", "emoji": "hex" } }`.

### Rate-limit usage thresholds

The `usage_5h` and `usage_7d` segments show rolling rate-limit consumption as a
percentage. By default no thresholds are set.

Ask the user whether they would like colour alerts as usage climbs:

- **Recommended defaults** (from the Bottomline quick-start guide):
  - **75%** → warning colour (orange)
  - **90%** → danger colour (red)

If the user agrees to the recommended defaults:

```bash
tmp=$(mktemp) \
  && jq '.segments.usage = {
    "90": { "color": "danger"  },
    "75": { "color": "warning" }
  }' "$HOME/.claude/bottomline.json" > "$tmp" \
  && mv "$tmp" "$HOME/.claude/bottomline.json"
```

If the user wants different percentages, apply them with the same structure.
Always order keys from highest to lowest. Keys are percentage integers (quoted);
values are `{ "color": "warning"|"danger"|"accent"|"text" }`.

## Bars

### Auto-bars

Auto-bars are extra lines rendered below the main status line when a
language-specific signal file (e.g. `go.mod`, `package.json`,
`sfdx-project.json`) is detected in the project root. They are **disabled by
default**.

Ask the user whether they would like to enable auto-bars:

- **Yes** → also ask whether they want to suppress the `git` bar. The main
  status line already shows the current branch via the `git_branch` segment, so
  most users prefer to exclude the git bar from auto-detection:

  With `git` excluded (recommended):

  ```bash
  tmp=$(mktemp) \
    && jq '.auto_bars.enabled = true | .auto_bars.disabled = ["git"]' \
         "$HOME/.claude/bottomline.json" > "$tmp" \
    && mv "$tmp" "$HOME/.claude/bottomline.json"
  ```

  Without any exclusions:

  ```bash
  tmp=$(mktemp) \
    && jq '.auto_bars.enabled = true' "$HOME/.claude/bottomline.json" > "$tmp" \
    && mv "$tmp" "$HOME/.claude/bottomline.json"
  ```

- **No** → skip; auto-bars remain off. Continue to **Explicit bars** below if
  the user wants to add a specific bar.

### Explicit bars

The `bars` array lets you add specific bars that will render in every project,
regardless of whether their signal file is present.

When `auto_bars.enabled` is `true`, the bars worth adding explicitly are those
that **will not** be auto-detected:

1. **`random-facts`** — has no signal file and is never auto-detected.
2. Any bar listed in `auto_bars.disabled` — the user has excluded it from
   auto-detection, so it will only render if explicitly added here.

**Step 1 — check what is already configured:**

```bash
jq '{bars: (.bars // []), auto_bars_disabled: (.auto_bars.disabled // [])}' \
  "$HOME/.claude/bottomline.json"
```

**Step 2 — determine candidates:**

Start from the full built-in bar list (ordered by system integration depth,
languages first, VCS last, opt-in bars at the end):
`rust`, `go`, `shell`, `swift`, `elixir`, `dotnet`, `java`, `python`, `ruby`, `javascript`,
`dart`, `php`, `salesforce`, `git`, `random-facts`, `linear`

Remove bars already present in the `bars` array (already configured).

Then keep only bars that cannot auto-detect — i.e. bars in `auto_bars.disabled`
plus `random-facts` (which has no signal file). Present this filtered list to
the user and ask which they would like to add.

**Step 3 — add each selected bar:**

For each bar the user selects, run:

```bash
tmp=$(mktemp) \
  && jq --arg name "BARNAME" '.bars += [{"script": $name}]' \
       "$HOME/.claude/bottomline.json" > "$tmp" \
  && mv "$tmp" "$HOME/.claude/bottomline.json"
```

Replace `BARNAME` with the bar name. Run once per bar.
To customise a bar's colours, add a `"colors"` key: `{"script": "mybar", "colors": {"accent": "#7c3aed"}}`, or `"colors": "inherit"` to use the main status line palette.

**`random-facts` — refresh interval**

`random-facts` fetches from an external API and caches the result. Before adding
or updating it, ask the user how often they want a new fact:

> "How often should the fact refresh? Default is every 60 minutes."

Then add (or update) the bar with the chosen interval:

*Adding for the first time:*
```bash
tmp=$(mktemp) \
  && jq --argjson rm MINUTES '.bars += [{"script": "random-facts", "refresh_minutes": $rm}]' \
       "$HOME/.claude/bottomline.json" > "$tmp" \
  && mv "$tmp" "$HOME/.claude/bottomline.json"
```

*Updating an existing entry:*
```bash
tmp=$(mktemp) \
  && jq --argjson rm MINUTES \
       '.bars |= map(if .script == "random-facts" then .refresh_minutes = $rm else . end)' \
       "$HOME/.claude/bottomline.json" > "$tmp" \
  && mv "$tmp" "$HOME/.claude/bottomline.json"
```

Replace `MINUTES` with the integer the user chose (e.g. `60`). Use the "adding"
command when the bar is absent from the array, the "updating" command when it
is already present.

**`linear` — required params and refresh interval**

`linear` calls the Linear GraphQL API and requires two params before it can render.
Write the `linear` bar config to the **project-level** config (`.claude/bottomline.json`), not the user-level config — the `team` key is project-specific.

Before adding it, ask the user for:

1. **API key** — from Linear → Settings → API → Personal API keys. Prompt:
   > "What is your Linear personal API key? You can store it as a literal value in the config, or in a key file (e.g. `file:~/.linear_token`) to keep it out of the JSON."

   **Recommended — key file:**

   ```bash
   printf 'lin_api_YOUR_KEY_HERE' > "$HOME/.linear_token"
   chmod 600 "$HOME/.linear_token"
   ```

   Then set `"api_key": "file:~/.linear_token"` in the params. The file is read at render
   time; no restart needed after rotating the key.

2. **Team key** — the short identifier for the team (e.g. `ENG`, `MOBILE`). Prompt:
   > "What is your Linear team key? This is the short uppercase identifier visible in your Linear workspace URL."

3. **Refresh interval** — how often to call the API. Prompt:
   > "How often should Linear data refresh? Suggested: every 15 minutes."

Then add the bar with the chosen values:

*Adding for the first time:*
```bash
tmp=$(mktemp) \
  && jq --arg key "API_KEY_VALUE" --arg team "TEAM_KEY" --argjson rm MINUTES \
       '.bars += [{"script":"linear","refresh_minutes":$rm,"params":{"api_key":$key,"team":$team}}]' \
       ".claude/bottomline.json" > "$tmp" \
  && mv "$tmp" ".claude/bottomline.json"
```

Replace `API_KEY_VALUE`, `TEAM_KEY`, and `MINUTES` with the user's choices.

*Updating an existing entry:*
```bash
tmp=$(mktemp) \
  && jq --argjson rm MINUTES \
       '.bars |= map(if .script == "linear" then .refresh_minutes = $rm else . end)' \
       ".claude/bottomline.json" > "$tmp" \
  && mv "$tmp" ".claude/bottomline.json"
```

## Going Further

After applying configuration changes, let the user know about two extension points and offer to transition immediately if they are interested:

- **Custom theme** — create a named colour palette in the plugin's `themes/` directory. Invoke `/bottomline:create-theme` to build one.
- **Custom bar** — add a second (or third…) line below the status line for project-specific info. Invoke `/bottomline:create-bar` to build one.

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
