# Bottomline Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract duplicated helper code into a shared library, then write five Claude skills that guide Claude when working with the Bottomline plugin.

**Architecture:** A `lib/helpers.sh` library centralises the ANSI/gradient/segment helpers currently duplicated across all bar scripts. `bottomline.sh` exports a `BOTTOMLINE_LIB` env var so bars can source it. Five skill files (`skills/<slug>/SKILL.md`) cover setup, configuration, bar creation, theme creation, and debugging.

**Tech Stack:** Bash, jq, JSON config files, Claude Code plugin skill format (`SKILL.md`)

---

## File Map

**Create:**
- `~/.claude/bottomline/lib/helpers.sh` — shared ANSI, gradient, and segment-engine helpers
- `~/.claude/bottomline/skills/setup/SKILL.md`
- `~/.claude/bottomline/skills/configure/SKILL.md`
- `~/.claude/bottomline/skills/create-bar/SKILL.md`
- `~/.claude/bottomline/skills/create-theme/SKILL.md`
- `~/.claude/bottomline/skills/debug/SKILL.md`

**Modify:**
- `~/.claude/bottomline/bottomline.sh` — add `BOTTOMLINE_LIB` to the bar env-var export block
- `~/.claude/bottomline/bars/elixir.sh` — replace boilerplate with `source` line
- `~/.claude/bottomline/bars/git.sh` — same (also removes `FG_CRIT` setup)
- `~/.claude/bottomline/bars/go.sh` — same
- `~/.claude/bottomline/bars/java.sh` — same
- `~/.claude/bottomline/bars/javascript.sh` — same
- `~/.claude/bottomline/bars/php.sh` — same (two boilerplate blocks: top + segment engine)
- `~/.claude/bottomline/bars/python.sh` — same
- `~/.claude/bottomline/bars/random-facts.sh` — remove only ANSI primitives + color setup (no segment engine block)
- `~/.claude/bottomline/bars/ruby.sh` — same as standard pattern
- `~/.claude/bottomline/bars/rust.sh` — same
- `~/.claude/bottomline/bars/swift.sh` — same

---

## Phase 1 — Helper Library Extraction

### Task 1: Create lib/helpers.sh

**Files:**
- Create: `~/.claude/bottomline/lib/helpers.sh`

- [ ] **Step 1: Create the lib directory and write helpers.sh**

```bash
mkdir -p ~/.claude/bottomline/lib
```

Write `~/.claude/bottomline/lib/helpers.sh` with this exact content:

```bash
#!/usr/bin/env bash
# Shared helpers sourced by every Bottomline bar script.
# Source at the top of your bar (after the shebang and guard):
#   source "$BOTTOMLINE_LIB/helpers.sh"

# ── ANSI primitives ───────────────────────────────────────────────────────────
bg3()     { printf '\e[48;2;%d;%d;%dm' "$1" "$2" "$3"; }
fg3()     { printf '\e[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
make_fg() { local r g b; read -r r g b <<< "$1"; fg3 $r $g $b; }

hex_to_rgb() {
  local h="${1#'#'}"
  [[ ${#h} -ne 6 ]] && printf '128 128 128' && return
  printf '%d %d %d' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}

link() { printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$1" "$2"; }

# ── Background gradient interpolation ─────────────────────────────────────────
expand_bg() {
  local cfg="$1" n_out="${2:-8}"
  local bg_type
  bg_type=$(printf '%s' "$cfg" | jq -r 'type' 2>/dev/null)
  case "$bg_type" in
    string)
      local hex; hex=$(printf '%s' "$cfg" | jq -r '.')
      printf '%s' "$hex" | awk -v n="$n_out" '{
        h=$0; printf "[";
        for(i=0;i<n;i++){if(i)printf ","; printf "\"" h "\""}
        printf "]"
      }'
      ;;
    array)
      printf '%s' "$cfg" | jq -r '.[]' | awk -v n_out="$n_out" '
        function h2d(h,   i,c,v) {
          v = 0
          for (i = 1; i <= length(h); i++) {
            c = substr(h, i, 1)
            if      (c ~ /[0-9]/) v = v*16 + c+0
            else if (c ~ /[a-f]/) v = v*16 + index("abcdef",c)+9
            else if (c ~ /[A-F]/) v = v*16 + index("ABCDEF",c)+9
          }
          return v
        }
        { colors[NR-1] = $0 }
        END {
          k = NR
          if (k == 0) {
            printf "["; for(i=0;i<n_out;i++){if(i)printf ","; printf "\"#0F0F0F\""}; printf "]"; exit
          }
          if (k == 1) {
            printf "["; for(i=0;i<n_out;i++){if(i)printf ","; printf "\"" colors[0] "\""} ; printf "]"; exit
          }
          printf "["
          for (i = 0; i < n_out; i++) {
            if (i) printf ","
            t   = (n_out > 1) ? i / (n_out - 1.0) : 0
            pos = t * (k - 1); seg = int(pos); if (seg >= k-1) seg = k-2; frac = pos - seg
            c1 = substr(colors[seg], 2); c2 = substr(colors[seg+1], 2)
            r = int(h2d(substr(c1,1,2)) + (h2d(substr(c2,1,2))-h2d(substr(c1,1,2)))*frac+0.5)
            g = int(h2d(substr(c1,3,2)) + (h2d(substr(c2,3,2))-h2d(substr(c1,3,2)))*frac+0.5)
            b = int(h2d(substr(c1,5,2)) + (h2d(substr(c2,5,2))-h2d(substr(c1,5,2)))*frac+0.5)
            printf "\"#%02X%02X%02X\"", r, g, b
          }
          printf "]"
        }
      '
      ;;
    *) printf '["#0F0F0F"]' ;;
  esac
}

# ── Segment engine ─────────────────────────────────────────────────────────────
declare -a _sc
seg()     { _sc+=("$1"); }
add_seg() { seg "$1"; }

flush() {
  local gradient_json="$1"
  local n=${#_sc[@]}
  (( n == 0 )) && return
  local expanded i hex
  expanded=$(expand_bg "$gradient_json" "$n")
  declare -a fr fg fb
  for ((i=0; i<n; i++)); do
    hex=$(printf '%s' "$expanded" | jq -r ".[$i]" 2>/dev/null)
    [[ -z "$hex" ]] && hex='#0F0F0F'
    read -r fr[$i] fg[$i] fb[$i] <<< "$(hex_to_rgb "$hex")"
  done
  for ((i=0; i<n; i++)); do
    local r=${fr[$i]} g=${fg[$i]} b=${fb[$i]}
    printf '%s' "$(bg3 $r $g $b) ${B}${_sc[$i]}$(bg3 $r $g $b) "
    if (( i + 1 < n )); then
      printf '%s' "$(fg3 $r $g $b)$(bg3 ${fr[$((i+1))]} ${fg[$((i+1))]} ${fb[$((i+1))]})${SEP}"
    else
      printf '%s' "${R}$(fg3 $r $g $b)${SEP}${R}"
    fi
  done
}

# ── Convenience variables from BOTTOMLINE_* env vars ─────────────────────────
R="$BOTTOMLINE_RESET"
B="$BOTTOMLINE_BOLD"
SEP="$BOTTOMLINE_SEP"
FG_TEXT=$(make_fg  "$(hex_to_rgb "$BOTTOMLINE_TEXT_HEX")")
FG_ACCENT=$(make_fg "$(hex_to_rgb "$BOTTOMLINE_ACCENT_HEX")")
FG_WARN=$(make_fg  "$(hex_to_rgb "${BOTTOMLINE_WARN_HEX:-#f4a261}")")
FG_CRIT=$(make_fg  "$(hex_to_rgb "${BOTTOMLINE_DANGER_HEX:-#e05a4e}")")
```

- [ ] **Step 2: Verify the file was written**

```bash
bash -n ~/.claude/bottomline/lib/helpers.sh && echo "syntax OK"
```

Expected: `syntax OK`

---

### Task 2: Export BOTTOMLINE_LIB from bottomline.sh

**Files:**
- Modify: `~/.claude/bottomline/bottomline.sh`

- [ ] **Step 1: Add BOTTOMLINE_LIB to the bar env-var export block**

Find the block in `bottomline.sh` that begins with:
```bash
export BOTTOMLINE_TEXT_HEX="$CFG_TEXT_HEX"   BOTTOMLINE_ACCENT_HEX="$CFG_ACCENT_HEX"
```

Add one line immediately after the last `export` line in that block (after `export BOTTOMLINE_GRADIENT="$CFG_BG"`):

```bash
export BOTTOMLINE_LIB="$HOME/.claude/bottomline/lib"
```

The block should look like this after the edit:
```bash
export BOTTOMLINE_TEXT_HEX="$CFG_TEXT_HEX"   BOTTOMLINE_ACCENT_HEX="$CFG_ACCENT_HEX"
export BOTTOMLINE_WARN_HEX="$CFG_WARN_HEX"   BOTTOMLINE_DANGER_HEX="$CFG_CRIT_HEX"
export BOTTOMLINE_BG_R="${C_R[0]}" BOTTOMLINE_BG_G="${C_G[0]}" BOTTOMLINE_BG_B="${C_B[0]}"
export BOTTOMLINE_SEP="$SEP" BOTTOMLINE_BOLD="$B" BOTTOMLINE_RESET="$R"
export BOTTOMLINE_ICON_TYPE="$CFG_ICON_TYPE"
export BOTTOMLINE_IC_FACT="$IC_FACT"
export BOTTOMLINE_PROJECT_DIR="$cdir"
export BOTTOMLINE_GRADIENT="$CFG_BG"
export BOTTOMLINE_LIB="$HOME/.claude/bottomline/lib"
```

- [ ] **Step 2: Verify syntax**

```bash
bash -n ~/.claude/bottomline/bottomline.sh && echo "syntax OK"
```

Expected: `syntax OK`

---

### Task 3: Migrate php.sh (reference migration)

`php.sh` has two boilerplate blocks to remove: one at the top (ANSI helpers) and one near the bottom (segment engine). Other bars typically have one contiguous block.

**Files:**
- Modify: `~/.claude/bottomline/bars/php.sh`

- [ ] **Step 1: Remove the top boilerplate block**

In `php.sh`, find and delete everything from:
```bash
bg3() { printf '\e[48;2;%d;%d;%dm' "$1" "$2" "$3"; }
```
through to (and including):
```bash
FG_WARN=$(make_fg "$(hex_to_rgb "$BOTTOMLINE_WARN_HEX")")
```
(This is roughly lines 8–24.)

- [ ] **Step 2: Remove the segment engine block**

Further down in `php.sh`, find and delete everything from:
```bash
# Segment engine — mirrors bottomline.sh: content-only seg, flush expands the
```
through to (and including):
```bash
add_seg() { seg "$1"; }
```

- [ ] **Step 3: Remove the expand_bg block**

Find and delete everything from:
```bash
# Expands colors.background config (hex string or K-keyframe array) into a JSON
```
through to (and including) the closing `;;` and `esac` of `expand_bg`.

- [ ] **Step 4: Add the source line**

After the project guard (`[[ -z "$PROJ" || ... ]] && exit 0`), add:

```bash
source "$BOTTOMLINE_LIB/helpers.sh"
```

The top of `php.sh` should now look like this:

```bash
#!/usr/bin/env bash
# Bottomline bar: PHP ecosystem bar
# Renders for any project containing a composer.json.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" || ! -f "$PROJ/composer.json" ]] && exit 0

source "$BOTTOMLINE_LIB/helpers.sh"

# PHP version from the active binary (fast — no framework bootstrap).
php_version=''
```

- [ ] **Step 5: Verify syntax**

```bash
bash -n ~/.claude/bottomline/bars/php.sh && echo "syntax OK"
```

Expected: `syntax OK`

---

### Task 4: Migrate remaining bar scripts

Apply the same pattern to each remaining bar. The standard migration for each file is:
1. Remove the `bg3`/`fg3`/`make_fg`/`hex_to_rgb` function block
2. Remove the `link()` function if present
3. Remove the `expand_bg` function if present
4. Remove the `R`/`B`/`SEP` variable assignments
5. Remove the `FG_TEXT`/`FG_ACCENT`/`FG_WARN` (and `FG_CRIT` if present) variable assignments
6. Remove the `declare -a _sc` / `seg` / `flush` / `add_seg` block if present
7. Add `source "$BOTTOMLINE_LIB/helpers.sh"` after the shebang comment and project guard

**`random-facts.sh` is different:** it has no `expand_bg`, `link`, or segment engine block. Only remove steps 1, 4, and 5 from the list above.

**Files:**
- Modify: `~/.claude/bottomline/bars/elixir.sh`
- Modify: `~/.claude/bottomline/bars/git.sh`
- Modify: `~/.claude/bottomline/bars/go.sh`
- Modify: `~/.claude/bottomline/bars/java.sh`
- Modify: `~/.claude/bottomline/bars/javascript.sh`
- Modify: `~/.claude/bottomline/bars/python.sh`
- Modify: `~/.claude/bottomline/bars/random-facts.sh`
- Modify: `~/.claude/bottomline/bars/ruby.sh`
- Modify: `~/.claude/bottomline/bars/rust.sh`
- Modify: `~/.claude/bottomline/bars/swift.sh`

- [ ] **Step 1: Migrate each bar**

For each file, apply the migration pattern described above. After migrating each file, check syntax immediately:

```bash
bash -n ~/.claude/bottomline/bars/elixir.sh    && echo "elixir OK"
bash -n ~/.claude/bottomline/bars/git.sh       && echo "git OK"
bash -n ~/.claude/bottomline/bars/go.sh        && echo "go OK"
bash -n ~/.claude/bottomline/bars/java.sh      && echo "java OK"
bash -n ~/.claude/bottomline/bars/javascript.sh && echo "javascript OK"
bash -n ~/.claude/bottomline/bars/python.sh    && echo "python OK"
bash -n ~/.claude/bottomline/bars/random-facts.sh && echo "random-facts OK"
bash -n ~/.claude/bottomline/bars/ruby.sh      && echo "ruby OK"
bash -n ~/.claude/bottomline/bars/rust.sh      && echo "rust OK"
bash -n ~/.claude/bottomline/bars/swift.sh     && echo "swift OK"
```

Expected: all 10 lines print `OK`.

---

### Task 5: Smoke-test the refactor and commit

**Files:** none new

- [ ] **Step 1: Run the main statusline with empty input**

```bash
echo '{}' | bash ~/.claude/bottomline/bottomline.sh
```

Expected: one line of ANSI-coloured text with powerline separators. No error output.

- [ ] **Step 2: Run with a project directory that has composer.json to exercise the PHP bar**

```bash
echo "{\"workspace\":{\"current_dir\":\"$(pwd)\"}}" \
  | bash ~/.claude/bottomline/bottomline.sh
```

(Run from a directory that has `composer.json`.) Expected: main statusline line followed by a second line with PHP/Laravel segments.

- [ ] **Step 3: Commit**

```bash
git -C ~/.claude/bottomline init  # only if not already a repo
git -C ~/.claude/bottomline add lib/helpers.sh bottomline.sh bars/
git -C ~/.claude/bottomline commit -m "refactor: extract shared helpers to lib/helpers.sh"
```

---

## Phase 2 — Skills

### Task 6: Write the setup skill

**Files:**
- Create: `~/.claude/bottomline/skills/setup/SKILL.md`

- [ ] **Step 1: Create the skills directory and write the file**

```bash
mkdir -p ~/.claude/bottomline/skills/setup
```

Write `~/.claude/bottomline/skills/setup/SKILL.md`:

```markdown
# Bottomline: Setup

Use this skill when installing Bottomline for the first time, re-wiring the
statusLine command, verifying the plugin is working, or uninstalling.

## Prerequisites

Check all three before proceeding:

- **Bash ≥4:** `bash --version` — macOS ships Bash 3.2; install a newer version
  with `brew install bash` if needed.
- **jq:** `which jq` — install with `brew install jq` if missing. Config loading
  silently produces no output when jq is absent.
- **Font:** A [Nerd Font](https://www.nerdfonts.com/) for the default `nerd` icon
  type. If you cannot install one, set `appearance.icons.type` to `"emoji"` or
  `"none"` in `~/.claude/bottomline.json`.

## Installing

**1. Create the statusLine shim** at `~/.claude/statusline.sh`:

```bash
cat > ~/.claude/statusline.sh << 'EOF'
#!/usr/bin/env bash
exec bash "$HOME/.claude/bottomline/bottomline.sh"
EOF
chmod +x ~/.claude/statusline.sh
```

**2. Add the `statusLine` block** to `~/.claude/settings.json` (merge into the
existing JSON object — do not replace the file):

```json
"statusLine": {
  "type": "command",
  "command": "~/.claude/statusline.sh",
  "refreshInterval": 60
}
```

`refreshInterval` is in seconds. 60 is a sensible default; set lower for more
frequent updates or higher to reduce shell spawning.

**3. Verify:**

```bash
echo '{}' | bash ~/.claude/bottomline/bottomline.sh
```

Expected: one line of ANSI-coloured powerline text. If you see nothing, run the
`debug` skill.

## Uninstalling

Remove the `statusLine` block from `~/.claude/settings.json`, then delete the
shim:

```bash
rm ~/.claude/statusline.sh
```
```

- [ ] **Step 2: Verify the file exists**

```bash
ls ~/.claude/bottomline/skills/setup/SKILL.md
```

Expected: path printed with no error.

---

### Task 7: Write the configure skill

**Files:**
- Create: `~/.claude/bottomline/skills/configure/SKILL.md`

- [ ] **Step 1: Create directory and write file**

```bash
mkdir -p ~/.claude/bottomline/skills/configure
```

Write `~/.claude/bottomline/skills/configure/SKILL.md`:

```markdown
# Bottomline: Configure

Use this skill when changing which segments are shown, adjusting colours or
icons, setting thresholds, applying a theme, or adding project-specific
overrides.

## Config File Locations

Three files are deep-merged at runtime (highest priority first):

1. `<project>/.claude/bottomline.json` — project overrides
2. `~/.claude/bottomline.json` — user overrides (create if it doesn't exist)
3. `~/.claude/bottomline/settings.json` — shipped defaults (do not edit)

**Merge rules:** Objects are merged recursively — a partial object in a
higher-priority file fills in only the keys it defines. Arrays and scalars:
the highest-priority non-null value wins entirely.

Always make changes in `~/.claude/bottomline.json` (user) or
`<project>/.claude/bottomline.json` (project). Never edit `settings.json`.

## Key Reference

### `appearance.colors`

| Key | Default | Description |
|---|---|---|
| `text` | `#e2d5c3` | Primary text colour |
| `accent` | `#da7756` | Icon and highlight colour |
| `warning` | `#f4a261` | Warning threshold colour |
| `danger` | `#e05a4e` | Critical threshold colour |
| `background` | gradient array | Hex string (flat) or array of hex keyframes (gradient) |

### `appearance.icons`

| Key | Values | Description |
|---|---|---|
| `type` | `nerd` \| `emoji` \| `none` | Icon set to use |
| `overrides` | `{ "name": "hex-codepoint or glyph" }` | Per-icon overrides |

Named icons: `model`, `bolt`, `ctx`, `dir`, `git`, `up`, `down`, `clock`,
`cal`, `warn`, `fact`, `cost`.

### `segments`

| Key | Description |
|---|---|
| `enabled` | Ordered array of segment names to render. Available: `model`, `effort`, `context`, `directory`, `git_branch`, `tokens`, `usage_5h`, `usage_7d`, `cost` |
| `disabled` | Array of segment names to suppress (union across all config levels) |
| `separator` | Hex codepoint (e.g. `"e0b4"`) or literal glyph for the powerline separator |
| `effort` | Per-level colour/icon: `{ "xhigh": { "color": "warning", "icon": { "nerd": "f071", "emoji": "26a0" } } }` |
| `context` | Token-count thresholds → colour/icon: `{ "200000": { "color": "warning" } }` |
| `git_branch` | Per-branch-name colour/icon: `{ "main": { "color": "danger" } }` |
| `usage` | Percentage thresholds → colour: `{ "90": { "color": "danger" }, "75": { "color": "warning" } }` |

### Top-level keys

| Key | Description |
|---|---|
| `theme` | Name of a file in `themes/` (e.g. `"catppuccin-mocha"`). Overrides all colour and icon settings in the merged config. |
| `project_aware` | Boolean. Set `false` to disable auto-bar detection for a project. |
| `bars` | Explicit bar list: `[{ "script": "name" }]`. Appended after auto-detected bars. |
| `disabled_auto_bars` | Array of bar names to exclude from auto-detection. Values are unioned across all config levels. |

## Example: user override file

`~/.claude/bottomline.json`:
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
```

- [ ] **Step 2: Verify**

```bash
ls ~/.claude/bottomline/skills/configure/SKILL.md
```

Expected: path printed with no error.

---

### Task 8: Write the create-bar skill

**Files:**
- Create: `~/.claude/bottomline/skills/create-bar/SKILL.md`

- [ ] **Step 1: Create directory and write file**

```bash
mkdir -p ~/.claude/bottomline/skills/create-bar
```

Write `~/.claude/bottomline/skills/create-bar/SKILL.md`:

```markdown
# Bottomline: Create a Bar

Use this skill when writing a new bar script — whether project-specific or a
new built-in bar for the plugin.

## What is a Bar?

A bar is a second (or third, fourth…) line rendered below the main statusline.
Each bar is a standalone Bash script that writes ANSI-coloured powerline
segments to stdout via the shared `seg`/`flush` helpers.

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
| `SEP` | Powerline separator glyph |

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
| `BOTTOMLINE_IC_FACT` | Pre-resolved icon for the `fact` named icon |

## Placement

**Project-specific bar** (only runs for this project):
- Save to: `<project>/.claude/bottomline/bars/<name>.sh`
- Reference by name (no path) in `<project>/.claude/bottomline.json`:
  ```json
  { "bars": [{ "script": "mybar" }] }
  ```

**Plugin built-in bar** (available across all projects):
- Save to: `~/.claude/bottomline/bars/<name>.sh`
- Optionally register for auto-detection in `~/.claude/bottomline/settings.json`:
  ```json
  "auto_bars": [
    { "script": "mybar", "signals": ["signal-file.ext", "alt-signal"] }
  ]
  ```
  Signal files are checked relative to the project root; the bar is prepended
  automatically when any signal file is found there.

## Testing Your Bar

Set the required env vars and run the script directly:

```bash
BOTTOMLINE_LIB="$HOME/.claude/bottomline/lib" \
BOTTOMLINE_TEXT_HEX="#e2d5c3" \
BOTTOMLINE_ACCENT_HEX="#da7756" \
BOTTOMLINE_WARN_HEX="#f4a261" \
BOTTOMLINE_DANGER_HEX="#e05a4e" \
BOTTOMLINE_BG_R=46 BOTTOMLINE_BG_G=31 BOTTOMLINE_BG_B=20 \
BOTTOMLINE_SEP=$'\xee\x82\xb4' \
BOTTOMLINE_BOLD=$'\e[1m' \
BOTTOMLINE_RESET=$'\e[0m' \
BOTTOMLINE_ICON_TYPE=nerd \
BOTTOMLINE_IC_FACT=$'\xef\x83\xab' \
BOTTOMLINE_PROJECT_DIR="$(pwd)" \
BOTTOMLINE_GRADIENT='["#2e1f14","#160f0a"]' \
bash ~/.claude/bottomline/bars/mybar.sh
```

Or test the full stack (replace the path with a directory matching your bar's
guard condition):

```bash
echo '{"workspace":{"current_dir":"/path/to/project"}}' \
  | bash ~/.claude/bottomline/bottomline.sh
```
```

- [ ] **Step 2: Verify**

```bash
ls ~/.claude/bottomline/skills/create-bar/SKILL.md
```

Expected: path printed with no error.

---

### Task 9: Write the create-theme skill

**Files:**
- Create: `~/.claude/bottomline/skills/create-theme/SKILL.md`

- [ ] **Step 1: Create directory and write file**

```bash
mkdir -p ~/.claude/bottomline/skills/create-theme
```

Write `~/.claude/bottomline/skills/create-theme/SKILL.md`:

```markdown
# Bottomline: Create a Theme

Use this skill when creating a new colour theme for Bottomline.

## Theme File Location

Save themes to:
```
~/.claude/bottomline/themes/<name>.json
```

The `<name>` is what users set in their config: `"theme": "<name>"`.

## Schema

```json
{
  "colors": {
    "text":       "#rrggbb",
    "accent":     "#rrggbb",
    "warning":    "#rrggbb",
    "danger":     "#rrggbb",
    "background": "#rrggbb"
  },
  "icons": {
    "type": "nerd | emoji | none"
  }
}
```

All keys are optional. Only the keys present in the theme file override the
active merged config — omitting a key leaves the user's own setting in place.

`background` accepts either:
- A single hex string: `"#1e1e2e"` — flat colour across all segments.
- An array of hex keyframes: `["#45475a","#11111b"]` — gradient interpolated
  left-to-right across segments. Any number of keyframes ≥1 is valid.

Theme colours take the highest priority — they override all per-file colour and
icon settings regardless of which config level the `"theme"` key is set at.

## Example: Catppuccin Mocha

```json
{
  "colors": {
    "text":       "#cdd6f4",
    "accent":     "#cba6f7",
    "warning":    "#f9e2af",
    "danger":     "#f38ba8",
    "background": ["#45475a", "#11111b"]
  },
  "icons": {
    "type": "nerd"
  }
}
```

## Activating a Theme

Set `"theme"` in any config level:

```json
{ "theme": "my-theme-name" }
```

Project-level activation (`<project>/.claude/bottomline.json`) overrides the
user's default theme for that project.
```

- [ ] **Step 2: Verify**

```bash
ls ~/.claude/bottomline/skills/create-theme/SKILL.md
```

Expected: path printed with no error.

---

### Task 10: Write the debug skill

**Files:**
- Create: `~/.claude/bottomline/skills/debug/SKILL.md`

- [ ] **Step 1: Create directory and write file**

```bash
mkdir -p ~/.claude/bottomline/skills/debug
```

Write `~/.claude/bottomline/skills/debug/SKILL.md`:

```markdown
# Bottomline: Debug

Use this skill when the statusline produces no output, icons render as boxes,
a bar is missing, colours are wrong, or the statusLine command isn't firing.

Work through this checklist in order — each step rules out a class of failure.

## 1. Manual script test

```bash
echo '{}' | bash ~/.claude/bottomline/bottomline.sh
```

- **Output appears:** the script works; the issue is in hook wiring (step 2).
- **No output / errors:** the issue is in the script or its dependencies. Check
  steps 3–7.

## 2. Hook wiring

Confirm `~/.claude/settings.json` contains a `statusLine` block:

```bash
jq '.statusLine' ~/.claude/settings.json
```

Expected: `{ "type": "command", "command": "~/.claude/statusline.sh", ... }`

Confirm the shim exists and is executable:

```bash
ls -l ~/.claude/statusline.sh
```

Expected: `-rwxr-xr-x` (note the `x` bits).

If the shim is missing, create it:

```bash
printf '#!/usr/bin/env bash\nexec bash "$HOME/.claude/bottomline/bottomline.sh"\n' \
  > ~/.claude/statusline.sh && chmod +x ~/.claude/statusline.sh
```

## 3. jq on PATH

```bash
which jq || echo "MISSING"
```

If missing, install: `brew install jq`. All config loading silently produces no
output when jq is absent — this is the most common cause of a blank statusline.

## 4. Icon boxes

Boxes (□ or ▯) instead of icons mean the terminal font doesn't include Nerd
Font glyphs.

Fix option A — install a Nerd Font and configure your terminal to use it.

Fix option B — switch to emoji icons immediately:

```json
{ "appearance": { "icons": { "type": "emoji" } } }
```

Save to `~/.claude/bottomline.json`.

## 5. Inspect the merged config

Check what config is actually active after the three-layer merge:

```bash
jq -n \
  --argjson s "$(jq '.' ~/.claude/bottomline/settings.json)" \
  --argjson u "$(jq '.' ~/.claude/bottomline.json 2>/dev/null || echo null)" \
  'if $u == null then $s else $s * $u end'
```

Look for unexpected `null` values, missing keys, or an overridden `theme` that
is pulling in colours you didn't expect.

## 6. Bar not appearing

A bar that should auto-detect is missing. Check in order:

```bash
# Is the bar's signal file actually in the project root?
ls /path/to/project/composer.json   # (replace with your signal file)

# Is the bar name in disabled_auto_bars?
jq '.disabled_auto_bars' ~/.claude/bottomline/settings.json
jq '.disabled_auto_bars' ~/.claude/bottomline.json 2>/dev/null

# Is the bar registered in auto_bars?
jq '.auto_bars' ~/.claude/bottomline/settings.json
```

Test the bar directly with `BOTTOMLINE_PROJECT_DIR` set:

```bash
BOTTOMLINE_LIB="$HOME/.claude/bottomline/lib" \
BOTTOMLINE_TEXT_HEX="#e2d5c3" BOTTOMLINE_ACCENT_HEX="#da7756" \
BOTTOMLINE_WARN_HEX="#f4a261" BOTTOMLINE_DANGER_HEX="#e05a4e" \
BOTTOMLINE_BG_R=46 BOTTOMLINE_BG_G=31 BOTTOMLINE_BG_B=20 \
BOTTOMLINE_SEP=$'\xee\x82\xb4' BOTTOMLINE_BOLD=$'\e[1m' BOTTOMLINE_RESET=$'\e[0m' \
BOTTOMLINE_ICON_TYPE=nerd BOTTOMLINE_IC_FACT=$'\xef\x83\xab' \
BOTTOMLINE_PROJECT_DIR="/path/to/project" \
BOTTOMLINE_GRADIENT='["#2e1f14","#160f0a"]' \
bash ~/.claude/bottomline/bars/php.sh
```

If this produces output but the full stack doesn't: `project_aware` may be
`false` in a config file, or the signal file check is failing on a symlinked
path.

## 7. Bash version

```bash
bash --version | head -1
```

Bottomline requires Bash ≥4. macOS ships Bash 3.2 as `/bin/bash`.

If the shim uses `/bin/bash`, update it to use the Homebrew bash:

```bash
printf '#!/usr/bin/env bash\nexec bash "$HOME/.claude/bottomline/bottomline.sh"\n' \
  > ~/.claude/statusline.sh
```

`env bash` resolves to whichever `bash` is first on PATH — Homebrew bash if
installed. Alternatively install: `brew install bash`.
```

- [ ] **Step 2: Verify**

```bash
ls ~/.claude/bottomline/skills/debug/SKILL.md
```

Expected: path printed with no error.

- [ ] **Step 3: Commit all skills**

```bash
git -C ~/.claude/bottomline add skills/
git -C ~/.claude/bottomline commit -m "feat: add setup, configure, create-bar, create-theme, debug skills"
```

---

## Self-Review Checklist (for the implementing engineer)

After completing all tasks, verify:

- [ ] `echo '{}' | bash ~/.claude/bottomline/bottomline.sh` renders without errors
- [ ] No bar script contains `bg3()`, `fg3()`, `expand_bg()`, or `flush()` function definitions
- [ ] Each bar script starts with `source "$BOTTOMLINE_LIB/helpers.sh"` (after its guard)
- [ ] All five `skills/*/SKILL.md` files exist
- [ ] `bash -n` passes for every file in `bars/` and `lib/helpers.sh`
