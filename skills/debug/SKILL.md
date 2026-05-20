---
name: bottomline:debug
description: Diagnoses and fixes Bottomline statusline problems — blank output, missing bars, wrong colours, icon boxes, config merge failures, and invalid config values. Use whenever the Bottomline statusline isn't working as expected, a setting doesn't seem to take effect, or the output looks wrong. Always use this skill before manually editing scripts or config files to troubleshoot.
---

# Bottomline: Debug

Use this skill when the statusline produces no output, icons render as boxes,
a bar is missing, colours are wrong, or the statusLine command isn't firing.

## Detect plugin path

Before running any commands below, detect where Bottomline is installed:

```bash
[[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "$CLAUDE_PLUGIN_ROOT/bottomline.sh" ]] \
  && echo "$CLAUDE_PLUGIN_ROOT" || echo "NOT_FOUND"
```

Store the output as `BL_DIR`. If the result is `NOT_FOUND`, ask the user where they installed Bottomline and use their answer as `BL_DIR`. Every path in this skill that refers to the plugin installation uses `$BL_DIR`.

Work through this checklist in order — each step rules out a class of failure.

## 1. Manual script test

```bash
echo '{}' | bash "$BL_DIR/bottomline.sh"
```

- **Output appears:** the script works; the issue is in hook wiring (step 2).
- **No output / errors:** the issue is in the script or its dependencies. Check
  steps 3–9.

## 2. Hook wiring

Confirm `statusLine.command` points to `bottomline.sh`:

```bash
jq '.statusLine.command // "not configured"' "$HOME/.claude/settings.json"
```

Expected: a path ending in `bottomline.sh`.

If it is `"not configured"` or points elsewhere, run the **setup** skill to
wire it correctly.

## 3. jq on PATH

```bash
command -v jq || echo "MISSING"
```

If missing, **ask the user** whether Claude should install it or they prefer
to do it themselves, then use the appropriate command:

| Detected | Command |
|---|---|
| `brew` | `brew install jq` |
| `apt` / `apt-get` | `sudo apt install -y jq` |
| `dnf` | `sudo dnf install -y jq` |
| `yum` | `sudo yum install -y jq` |
| `pacman` | `sudo pacman -S --noconfirm jq` |
| `zypper` | `sudo zypper install -y jq` |
| `choco` | `choco install jq` |
| `scoop` | `scoop install jq` |
| `winget` | `winget install jqlang.jq` |
| none | Direct to <https://jqlang.github.io/jq/download/> and wait. |

All config loading silently produces no output when jq is absent — this is the
most common cause of a blank statusline.

## 4. Icon boxes

Boxes (□ or ▯) instead of icons mean the terminal font doesn't include Nerd
Font glyphs.

Fix option A — install a Nerd Font and configure your terminal to use it.

Fix option B — switch to emoji icons immediately:

```json
{ "appearance": { "icons": { "type": "emoji" } } }
```

Save to `$HOME/.claude/bottomline.json`.

## 5. Inspect the merged config

Check what config is actually active after the three-layer merge:

```bash
jq -n \
  --argjson s "$(jq '.' "$BL_DIR/settings.json")" \
  --argjson u "$(jq '.' "$HOME/.claude/bottomline.json" 2>/dev/null || echo null)" \
  --argjson p "$(jq '.' "$(pwd)/.claude/bottomline.json" 2>/dev/null || echo null)" '
  def dmerge(a; b):
    if b == null then a
    elif (a | type) == "object" and (b | type) == "object"
    then reduce (b | keys_unsorted[]) as $k (a; .[$k] = dmerge(a[$k]; b[$k]))
    else b end;
  dmerge(dmerge($s; $u); $p)'
```

Look for unexpected `null` values, missing keys, or an overridden `appearance.theme` that
is pulling in colours you didn't expect.

## 6. Invalid settings.json (all defaults silently lost)

If colours, segments, or `project_aware` behave as though system-level defaults
don't exist — especially when a user- or project-level config file is present —
the most likely cause is invalid JSON in `settings.json`.

When `jq` fails to parse `settings.json` the script silently falls back to `{}`,
wiping every system-level default. Higher-priority config files still load, so
the symptom only appears once a user- or project-level config exists.

Check:

```bash
jq '.' "$BL_DIR/settings.json" && echo "valid" || echo "INVALID JSON"
```

If invalid, open `settings.json` and look for trailing commas (the most common
cause — a comma after the last item in an object or array). Fix the JSON, then
re-run the step 1 manual test.

## 7. Config value validation

Run the block below against each config file you have edited. No output from
the jq script means that file passed all checks.

```bash
for _f in "$HOME/.claude/bottomline.json" "$(pwd)/.claude/bottomline.json"; do
  [[ ! -f "$_f" ]] && continue
  echo "── $_f ──"

  # Theme file existence (needs bash, not jq)
  _theme=$(jq -r '.appearance.theme // empty' "$_f" 2>/dev/null)
  if [[ -n "$_theme" ]]; then
    _tf="$BL_DIR/themes/${_theme}.json"
    [[ -f "$_tf" ]] || echo "  appearance.theme: \"$_theme\" — file not found at $_tf"
  fi
  unset _theme _tf

  jq -r '
    def vhex: type == "string" and test("^#[0-9a-fA-F]{6}$");
    def vcolor: . == "text" or . == "accent" or . == "warning" or . == "danger" or vhex;
    def vcp: type == "string" and test("^[0-9a-fA-F]{4,5}$");
    ["model","effort","context","directory","git_branch","tokens_in","tokens_out","usage_5h","usage_7d","cost"] as $vsegs |
    [
      # hex color values must be #rrggbb
      ( (.appearance.colors // {}) | to_entries[]
        | select(.key != "background") | select(.value | type == "string")
        | select(.value | vhex | not)
        | "appearance.colors.\(.key): \"\(.value)\" — must be #rrggbb" ),
      ( (.appearance.colors.background // [])
        | if type == "array" then .[] else . end | select(type == "string")
        | select(vhex | not)
        | "appearance.colors.background item \"\(.)\" — must be #rrggbb" ),

      # icon type enum
      ( .appearance.icons.type // empty
        | select(. != "nerd" and . != "emoji" and . != "none")
        | "appearance.icons.type: \"\(.)\" — must be nerd, emoji, or none" ),

      # icon overrides must not be blank
      ( (.appearance.icons.overrides // {}) | to_entries[]
        | select(.value | type == "string")
        | select(.value | ltrimstr(" ") | ltrimstr("\t") | . == "")
        | "appearance.icons.overrides.\(.key): blank — expected a 4-5 hex digit codepoint" ),

      # icon override codepoints: 4-5 hex digits
      ( (.appearance.icons.overrides // {}) | to_entries[]
        | select(.value | type == "string" and length > 0)
        | select(.value | vcp | not)
        | "appearance.icons.overrides.\(.key): \"\(.value)\" — expected 4-5 hex digits, e.g. \"e0b4\"" ),

      # auto_bars sub-keys must be correct types
      ( .auto_bars.enabled // null | if . != null and type != "boolean"
        then "auto_bars.enabled: \"\(.)\" — must be true or false" else empty end ),
      ( .auto_bars.inherit_colors // null | if . != null and type != "boolean"
        then "auto_bars.inherit_colors: \"\(.)\" — must be true or false" else empty end ),

      # segment names in enabled/disabled must be valid
      ( ((.segments.enabled // []) + (.segments.disabled // []))[]
        | . as $s | select(($vsegs | index($s)) == null)
        | "segments: \"\(.)\" — not a valid segment name" ),

      # .color references must use a known name or #rrggbb
      ( [ {p:"segments.effort",    c:(.segments.effort     // {})},
          {p:"segments.context",   c:(.segments.context    // {})},
          {p:"segments.git_branch",c:(.segments.git_branch // {})},
          {p:"segments.usage",     c:(.segments.usage      // {})} ][]
        | .p as $path | .c | to_entries[]
        | "\($path).\(.key)" as $loc | .value
        | select(.color != null) | select(.color | vcolor | not)
        | "\($loc).color: \"\(.color)\" — use text/accent/warning/danger or #rrggbb" ),

      # threshold keys in context/usage must be quoted integers
      ( (.segments.context // {}) | keys[]
        | select(test("^[0-9]+$") | not)
        | "segments.context key \"\(.)\" — must be a quoted integer, e.g. \"200000\"" ),
      ( (.segments.usage // {}) | keys[]
        | select(test("^[0-9]+$") | not)
        | "segments.usage key \"\(.)\" — must be a quoted integer, e.g. \"90\"" ),

      # nerd/emoji icon codepoints in segment configs: 4-5 hex digits
      ( [ {p:"segments.effort",    c:(.segments.effort     // {})},
          {p:"segments.context",   c:(.segments.context    // {})},
          {p:"segments.git_branch",c:(.segments.git_branch // {})} ][]
        | .p as $path | .c | to_entries[]
        | "\($path).\(.key)" as $loc | .value
        | if type == "object" then (.icon // {}) | to_entries[] else empty end
        | select(.key == "nerd" or .key == "emoji")
        | select(.value | type == "string" and length > 0 and (vcp | not))
        | "\($loc).icon.\(.key): \"\(.value)\" — expected 4-5 hex digits, e.g. \"f071\"" )
    ]
    | if length == 0 then "OK" else .[] end
  ' "$_f" 2>/dev/null || echo "  (skipped — parse error; see step 6)"
done
```

## 8. Bar not appearing

A bar that should auto-detect is missing. Check in order:

```bash
# Is the bar's signal file actually in the project root?
ls /path/to/project/composer.json   # (replace with your signal file)

# Is auto-bar detection enabled?
jq '.auto_bars.enabled' "$BL_DIR/settings.json"
jq '.auto_bars.enabled' "$HOME/.claude/bottomline.json" 2>/dev/null

# Is the bar name in auto_bars.disabled?
jq '.auto_bars.disabled' "$BL_DIR/settings.json"
jq '.auto_bars.disabled' "$HOME/.claude/bottomline.json" 2>/dev/null

# Is the bar registered in auto_bars.scripts?
jq '.auto_bars.scripts' "$BL_DIR/settings.json"
```

Test the bar directly with `BOTTOMLINE_PROJECT_DIR` set:

```bash
BOTTOMLINE_LIB="$BL_DIR/lib" \
BOTTOMLINE_TEXT_HEX="#e2d5c3" BOTTOMLINE_ACCENT_HEX="#da7756" \
BOTTOMLINE_WARN_HEX="#f4a261" BOTTOMLINE_DANGER_HEX="#e05a4e" \
BOTTOMLINE_BG_R=46 BOTTOMLINE_BG_G=31 BOTTOMLINE_BG_B=20 \
BOTTOMLINE_SEP=$'\xee\x82\xb4' BOTTOMLINE_BOLD=$'\e[1m' BOTTOMLINE_RESET=$'\e[0m' \
BOTTOMLINE_ICON_TYPE=nerd BOTTOMLINE_IC_DANGER=$'\xef\x81\x9e' \
BOTTOMLINE_PROJECT_DIR="/path/to/project" \
BOTTOMLINE_GRADIENT='["#2e1f14","#160f0a"]' \
bash "$BL_DIR/bars/php.sh"
```

If this produces output but the full stack doesn't: `project_aware` may be
`false` in a config file, or the signal file check is failing on a symlinked
path.

## 9. Bash version

```bash
bash --version | head -1
```

Bottomline requires Bash ≥4. If the version shown is below 4, **ask the user** whether Claude should
install a newer Bash or they prefer to do it themselves, then use the
appropriate command:

| Detected | Command |
|---|---|
| `brew` | `brew install bash` |
| `apt` / `apt-get` | `sudo apt install -y bash` |
| `dnf` | `sudo dnf install -y bash` |
| `yum` | `sudo yum install -y bash` |
| `pacman` | `sudo pacman -S --noconfirm bash` |
| `zypper` | `sudo zypper install -y bash` |
| `choco` | `choco install git` (Git for Windows includes Bash ≥4) |
| `scoop` | `scoop install git` |
| `winget` | `winget install Git.Git` |
| none | Direct to <https://git-scm.com/downloads> (Windows) or <https://www.gnu.org/software/bash/> (other) and wait. |

After installing, the user may need to ensure the new Bash appears on `PATH`
before the system default. `bottomline.sh` uses `#!/usr/bin/env bash`, which
resolves to the first `bash` on `PATH`.
