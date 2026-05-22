---
name: add-bar
description: Step-by-step checklist for adding a new built-in bar script to the Bottomline plugin. Use when contributing a new language or tool bar to bars/ — covers the script, auto-detection registration, and tests.
---

# Add a Built-in Bar

A built-in bar lives in `bars/` and is available to all users. Adding one requires three things: the script itself, an auto-detection entry in `settings.json`, and integration tests.

---

## 1. Write `bars/<name>.sh`

Follow this structure exactly. The `BOTTOMLINE_BAR_COLORS` guard is mandatory for built-in bars — it lets users override the language palette via config.

```bash
#!/usr/bin/env bash
# Bottomline bar: <description>

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0
[[ ! -f "$PROJ/<signal-file>" ]] && exit 0   # hard guard: exit when not applicable

source "$BOTTOMLINE_LIB/helpers.sh"

# ── Icons ─────────────────────────────────────────────────────────────────────
case "$BOTTOMLINE_ICON_TYPE" in
  nerd)  IC_LANG=$'\x..\x..\x..'  ;;   # U+XXXX  nf-* description
  emoji) IC_LANG='<emoji>'        ;;
  *)     IC_LANG=''               ;;
esac

# ── Palette ───────────────────────────────────────────────────────────────────
# Apply brand colours only when the caller hasn't supplied overrides.
if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg   "$(hex_to_rgb "<text_hex>")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "<accent_hex>")")
  _bar_gradient='["<bg_start>","<bg_end>"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

# ── Gather data ───────────────────────────────────────────────────────────────
# ... read files, run commands, build segment strings ...

# ── Segments (canonical slot order) ───────────────────────────────────────────
# Slot 1: Runtime
[[ -n "$lang_version" ]] && add_seg "${FG_ACCENT}${IC_LANG} ${FG_TEXT}<Name> ${FG_ACCENT}v${lang_version}"

# Slot 2: Package manager (when not implicit)
# [[ -n "$pm_name" ]] && add_seg "${FG_ACCENT}${IC_PM} ${FG_TEXT}${pm_name}"

# Slot 3: Framework
# [[ -n "$framework_version" ]] && add_seg "${FG_ACCENT}${IC_FRAMEWORK} ${FG_TEXT}<Framework> ${FG_ACCENT}v${framework_version}"

# Slot 4: Framework add-ons
# [[ -n "$addon_version" ]] && add_seg "${FG_ACCENT}${IC_ADDON} ${FG_TEXT}<Addon> ${FG_ACCENT}v${addon_version}"

# Slot 5: Testing (REQUIRED — see CLAUDE.md "Language bar segment ordering")
# [[ -n "$test_framework" ]] && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}${test_framework}"

# Slot 6: Static analysis / tooling (REQUIRED — at least one)
# [[ -n "$linter_version" ]] && add_seg "${FG_ACCENT}${IC_LINT} ${FG_TEXT}<Linter> ${FG_ACCENT}v${linter_version}"

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
```

Key rules:
- Exit silently (`exit 0`) when the bar doesn't apply — never produce output for an irrelevant project.
- Always check `(( ${#_sc[@]} == 0 )) && exit 0` before `flush` to avoid emitting an empty line.
- Pass `"$_bar_gradient"` (not `"$BOTTOMLINE_GRADIENT"`) to `flush` — the palette block sets this correctly for both the brand and inherit cases.

---

## 2. Register auto-detection in `settings.json`

Add an entry to `auto_bars.scripts`. List every signal file that indicates this language/tool is in use:

```json
"auto_bars": {
  "scripts": [
    ...
    { "script": "<name>", "signals": ["<signal-file>", "<alt-signal>"] }
  ]
}
```

Signal files are checked relative to the project root. The bar is prepended automatically when **any** listed signal file is found there.

**Placement in the list:** entries are ordered by system integration depth — languages first (deepest to shallowest: `rust`, `go`, `shell`, `swift`, `elixir`, `dotnet`, `java`, `python`, `ruby`, `javascript`, `dart`, `php`, `salesforce`), then `git` last (VCS tool, not a language). Insert the new entry at the position that best reflects where the language sits on that spectrum.

`auto_bars.enabled` defaults to `false` in `settings.json`. Users opt in. Do not change the default.

---

## 3. Write `tests/integration/bars/<name>.bats`

```bash
#!/usr/bin/env bats
# Integration tests for the <name> bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

setup()    { setup_fake_proj; }
teardown() { teardown_fake_proj; }

@test "<name>: exits silently when no signal file" {
  bar_run <name> "$FAKE_PROJ"
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -z "$stripped" ]
}

@test "<name>: renders <key info> from <signal file>" {
  # Create the signal file with realistic content
  printf '<content>\n' > "$FAKE_PROJ/<signal-file>"
  bar_run <name> "$FAKE_PROJ"
  [[ "$BAR_OUTPUT" == *"<expected text>"* ]]
}
```

Cover at minimum:
- Silent exit when no signal file is present.
- Renders the primary value (version, name, etc.) when the signal file exists.
- Any conditional segments (workspace mode, tool presence, error state).

---

## Checklist

- [ ] `bars/<name>.sh` written with `BOTTOMLINE_BAR_COLORS` guard
- [ ] Hard guard exits silently when signal file is absent
- [ ] `(( ${#_sc[@]} == 0 )) && exit 0` before `flush`
- [ ] `_bar_gradient` used, not `$BOTTOMLINE_GRADIENT` directly
- [ ] Segments emitted in canonical slot order (Runtime → PM → Framework → Add-ons → Testing → Tooling)
- [ ] At least one **testing segment** (slot 5) — see [[testing-framework-layering]]
- [ ] At least one **static analysis segment** (slot 6) — linter, type checker, or formatter
- [ ] Testing framework **layering rules** applied (Pest > PHPUnit, JUnit5 > JUnit4, etc.)
- [ ] Detection uses the correct signal type — dep / config file / binary
- [ ] Entry added to `auto_bars.scripts` in `settings.json`
- [ ] `tests/integration/bars/<name>.bats` written
- [ ] Silent-exit test passes
- [ ] Functional tests cover primary output, testing segment, and static analysis segment
- [ ] Layering suppression test included where the stack has layered frameworks
