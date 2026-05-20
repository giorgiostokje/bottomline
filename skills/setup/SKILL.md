---
name: bottomline:setup
description: Installs, verifies, and uninstalls the Bottomline powerline statusline plugin for Claude Code. Use when a user wants to install Bottomline for the first time, something isn't showing up after installation, or they want to uninstall it. Also use when the user mentions setting up the statusline, running the initial install, or removing Bottomline.
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

If the output already contains `bottomline.sh`, nothing to do — use the **debug**
skill if something isn't working.

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
_bl_dir=$(tr ':' '\n' <<< "$PATH" | grep -m1 '/bottomline/bottomline/.*/bin$' | sed 's|/bin$||')
[[ -z "$_bl_dir" || ! -f "$_bl_dir/bottomline.sh" ]] && exit 0
exec bash "$_bl_dir/bottomline.sh"
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

This is where user-level config overrides live (colours, segments, theme, etc.).
The file is created as an empty JSON object if it does not already exist.

If the user does not have a Nerd Font, set the icon type now:

```bash
tmp=$(mktemp) \
  && jq '.appearance.icons.type = "emoji"' "$HOME/.claude/bottomline.json" > "$tmp" \
  && mv "$tmp" "$HOME/.claude/bottomline.json"
```

Ask the user which they prefer — `"emoji"` or `"none"` — and use that value.
Skip this step if they have a Nerd Font installed.

**3. Verify:**

```bash
echo '{}' | bash "$BL_DIR/bottomline.sh"
```

Expected: one line of ANSI-coloured powerline text. If you see nothing, run the
**debug** skill.

**4. Offer configuration**

Ask the user whether they would like to configure Bottomline now (segments,
colours, theme, icon type, etc.).

- **Yes** → invoke the **configure** skill (`/bottomline:configure`) immediately.
- **No** → inform them they can run `/bottomline:configure` at any time, or edit
  the config files directly:
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
