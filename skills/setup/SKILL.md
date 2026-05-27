---
name: bottomline:setup
description: Use when a user wants to install Bottomline for the first time, something isn't showing up after installation, or they want to uninstall it. Also use when the user mentions setting up the status line, running the initial install, or removing Bottomline.
---

# Bottomline: Setup

Use this skill when installing Bottomline, verifying it is working, or uninstalling.

> **Path notation:** `$HOME` refers to the current user's home directory.
> On Linux/macOS this is `/home/<user>` or `/Users/<user>`; on Windows it is
> `%USERPROFILE%` (e.g. `C:\Users\YourName`). In Git Bash and WSL, `$HOME`
> expands automatically — no substitution needed.

## Detect plugin path

Before doing anything else, detect where Bottomline is installed:

```bash
[[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "$CLAUDE_PLUGIN_ROOT/bottomline.sh" ]] \
  && echo "$CLAUDE_PLUGIN_ROOT" || echo "NOT_FOUND"
```

Store the output as `BL_DIR`. If the result is `NOT_FOUND`, use the base directory shown in this skill's invocation header as `BL_DIR`. Every path in this skill that refers to the plugin installation uses `$BL_DIR`.

## Check current state

```bash
jq '.statusLine.command // "not configured"' "$HOME/.claude/settings.json"
```

- **Manual install** (command points directly to a path inside `/plugins/cache/`
  or a user-chosen path outside `$HOME/.claude/bottomline.sh`): nothing to do —
  use the **debug** skill if something isn't working.
- **Marketplace install** (command is `$HOME/.claude/bottomline.sh` or `not
  configured`): always continue to **Installing** and recreate the shim — this
  is safe to re-run and ensures the shim is up to date.

## Prerequisites

Before installing, check each dependency. For any that is missing or
insufficient, detect the OS and package manager, then **ask the user** whether
Claude should install it or they prefer to install it themselves. If the user
wants to install it, provide the exact command or download URL for their system
and wait for confirmation before continuing.

**Detect OS and package manager:**

```bash
os=$(uname -s 2>/dev/null || echo "unknown")
if   command -v brew    >/dev/null 2>&1; then pm="unix:brew"
elif command -v apt     >/dev/null 2>&1; then pm="unix:apt"
elif command -v apt-get >/dev/null 2>&1; then pm="unix:apt-get"
elif command -v dnf     >/dev/null 2>&1; then pm="unix:dnf"
elif command -v yum     >/dev/null 2>&1; then pm="unix:yum"
elif command -v pacman  >/dev/null 2>&1; then pm="unix:pacman"
elif command -v zypper  >/dev/null 2>&1; then pm="unix:zypper"
elif command -v choco   >/dev/null 2>&1; then pm="win:choco"
elif command -v scoop   >/dev/null 2>&1; then pm="win:scoop"
elif command -v winget  >/dev/null 2>&1; then pm="win:winget"
else pm=""
fi
echo "OS: $os  package manager: ${pm:-none detected}"
```

**Bash ≥3.2**

```bash
bash --version | head -1
```

If the version is below 3.2, ask the user whether Claude should install it or
they prefer to do it themselves, then use the appropriate command:

| Detected | Command |
|---|---|
| `unix:brew` | `brew install bash` |
| `unix:apt` / `apt-get` | `sudo apt install -y bash` |
| `unix:dnf` | `sudo dnf install -y bash` |
| `unix:yum` | `sudo yum install -y bash` |
| `unix:pacman` | `sudo pacman -S --noconfirm bash` |
| `unix:zypper` | `sudo zypper install -y bash` |
| `win:choco` | `choco install git` (Git for Windows includes Bash) |
| `win:scoop` | `scoop install git` |
| `win:winget` | `winget install Git.Git` |
| none detected | Direct to <https://git-scm.com/downloads> (Windows) or <https://www.gnu.org/software/bash/> (other) and wait. |

**jq**

```bash
command -v jq || echo "MISSING"
```

If missing, ask the user whether Claude should install it or they prefer to do
it themselves, then use the appropriate command:

| Detected | Command |
|---|---|
| `unix:brew` | `brew install jq` |
| `unix:apt` / `apt-get` | `sudo apt install -y jq` |
| `unix:dnf` | `sudo dnf install -y jq` |
| `unix:yum` | `sudo yum install -y jq` |
| `unix:pacman` | `sudo pacman -S --noconfirm jq` |
| `unix:zypper` | `sudo zypper install -y jq` |
| `win:choco` | `choco install jq` |
| `win:scoop` | `scoop install jq` |
| `win:winget` | `winget install jqlang.jq` |
| none detected | Direct to <https://jqlang.github.io/jq/download/> and wait. |

Config loading silently produces no output when jq is absent.

**Font**

A [Nerd Font](https://www.nerdfonts.com/) is required for the default `nerd`
icon type. Ask the user whether they have one installed **and set as their
terminal font**. Claude cannot install or configure a font.

If the user needs to install one:
1. Direct them to <https://www.nerdfonts.com/font-downloads> to download a font.
2. Instruct them to install the font on their system (double-click the `.ttf`/`.otf` files on Windows/macOS, or copy to `$HOME/.local/share/fonts/` and run `fc-cache -fv` on Linux).
3. **Emphasise that they must open their terminal's settings and select the Nerd Font as the active font** — downloading alone is not enough; icons will not render until the terminal is configured to use it.
4. Ask the user to confirm the font is set before continuing.

If the user does not want to install a font, note that the icon fallback will be
configured in step 2 below.

## Installing

**1. Wire `statusLine` in `$HOME/.claude/settings.json`**

**Marketplace installs** (where `BL_DIR` contains `/plugins/cache/`) use a stable launcher
at `$HOME/.claude/bottomline.sh` that resolves the current plugin version via `$PATH` at
runtime — so `settings.json` never needs updating after a plugin upgrade:

```bash
cat > "$HOME/.claude/bottomline.sh" << 'LAUNCHER'
#!/usr/bin/env bash
_cache="${HOME}/.claude/plugins/cache/bottomline/bottomline"
_bl_dir="" _best="0 0 0"
for _d in "${_cache}"/*/; do
  [[ -f "${_d}bottomline.sh" ]] || continue
  _v="${_d%/}"; _v="${_v##*/}"
  IFS=. read -r _ma _mi _pa <<< "${_v}"
  IFS=' ' read -r _bma _bmi _bpa <<< "${_best}"
  (( 10#${_ma:-0} > 10#${_bma} \
  || (10#${_ma:-0} == 10#${_bma} && 10#${_mi:-0} > 10#${_bmi}) \
  || (10#${_ma:-0} == 10#${_bma} && 10#${_mi:-0} == 10#${_bmi} && 10#${_pa:-0} > 10#${_bpa}) )) \
  && { _bl_dir="${_d%/}"; _best="${_ma:-0} ${_mi:-0} ${_pa:-0}"; }
done
[[ -z "${_bl_dir}" ]] && exit 0
exec bash "${_bl_dir}/bottomline.sh"
LAUNCHER
chmod +x "$HOME/.claude/bottomline.sh"
```

Then wire `settings.json` to the stable launcher:

```bash
tmp=$(mktemp) \
  && jq --arg cmd "$HOME/.claude/bottomline.sh" '
       if .statusLine == null
       then .statusLine = {"type": "command", "command": $cmd, "refreshInterval": 60}
       else .statusLine.command = $cmd | .statusLine.type = "command"
       end
     ' "$HOME/.claude/settings.json" > "$tmp" \
  && mv "$tmp" "$HOME/.claude/settings.json"
```

**Manual installs** (where `BL_DIR` is a user-chosen path outside `/plugins/cache/`) skip the
launcher — wire `settings.json` directly to `$BL_DIR/bottomline.sh` instead:

```bash
tmp=$(mktemp) \
  && jq --arg cmd "$BL_DIR/bottomline.sh" '
       if .statusLine == null
       then .statusLine = {"type": "command", "command": $cmd, "refreshInterval": 60}
       else .statusLine.command = $cmd | .statusLine.type = "command"
       end
     ' "$HOME/.claude/settings.json" > "$tmp" \
  && mv "$tmp" "$HOME/.claude/settings.json"
```

Both paths are safe to re-run and preserve any existing `refreshInterval`.

**2. Create `$HOME/.claude/bottomline.json`** (user config file)

```bash
[[ ! -f "$HOME/.claude/bottomline.json" ]] \
  && printf '{}\n' > "$HOME/.claude/bottomline.json" \
  && echo "created" || echo "already exists"
```

This file starts **completely empty** (`{}`). There are no pre-applied user
defaults — all defaults live only in the plugin's `settings.json`, which ships
with the plugin and must never be edited directly. Every key you add to
`$HOME/.claude/bottomline.json` overrides only that specific key; everything
else falls through from `settings.json`.

If the user does not have a Nerd Font, set the icon type now:

```bash
tmp=$(mktemp) \
  && jq '.appearance.icons.type = "emoji"' "$HOME/.claude/bottomline.json" > "$tmp" \
  && mv "$tmp" "$HOME/.claude/bottomline.json"
```

Ask the user which they prefer — `"emoji"` or `"none"` — and use that value.
Skip this step if they have a Nerd Font installed.

> **To change this later:** edit `$HOME/.claude/bottomline.json` and set
> `appearance.icons.type` to `"nerd"`, `"emoji"`, or `"none"`.

**3. Verify:**

```bash
echo '{}' | bash "$BL_DIR/bottomline.sh"
```

Expected: one line of ANSI-coloured status line output. If you see nothing, run the
**debug** skill.

For Marketplace installs, also verify the stable launcher shim — this is the
path Claude Code actually invokes:

```bash
echo '{}' | bash "$HOME/.claude/bottomline.sh"
```

Expected: the same ANSI output. If the shim produces no output, run the
**debug** skill and follow the shim test (step 2).

**4. Offer further configuration**

Let the user know they can customise colours, themes, active segments,
separators, threshold alerts, and bars at any time:

- Run `/bottomline:configure` for a guided configuration session — this covers
  threshold alerts (context window and rate-limit usage), auto-bar detection,
  and explicitly adding bars that don't auto-detect.
- Edit the config files directly:
  - User-level: `$HOME/.claude/bottomline.json`
  - Project-level: `<project>/.claude/bottomline.json`

## Uninstalling

Remove the stable launcher if present, then revert `statusLine.command` to the
original `statusline.sh` shim if it exists; otherwise remove the `statusLine` block:

```bash
rm -f "$HOME/.claude/bottomline.sh"

if [[ -f "$HOME/.claude/statusline.sh" ]]; then
  tmp=$(mktemp) \
    && jq --arg cmd "$HOME/.claude/statusline.sh" '.statusLine.command = $cmd' \
         "$HOME/.claude/settings.json" > "$tmp" \
    && mv "$tmp" "$HOME/.claude/settings.json"
else
  tmp=$(mktemp) \
    && jq 'del(.statusLine)' "$HOME/.claude/settings.json" > "$tmp" \
    && mv "$tmp" "$HOME/.claude/settings.json"
fi
```
