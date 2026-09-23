---
name: add-segment
description: Use when implementing a new built-in segment for the Bottomline status line — the change spans five files and agents reliably miss steps without this checklist.
---

# Add a Built-in Segment

Adding a segment requires **nine steps across six files** — steps 1–3 modify `lib/icons.sh`; step 4 modifies `lib/segments.sh` and `lib/config.sh`; step 5 modifies `lib/segments.sh`; steps 6–9 each touch a different file. Complete every step; skipping any leaves the segment broken or inconsistent.

---

## 1. `lib/icons.sh` — icon constants

Add one `NF_*` entry (raw UTF-8 bytes of the Nerd Font codepoint) and one `EM_*` entry (emoji or ASCII fallback) alongside the existing constants:

```bash
NF_<NAME>=$'\x..\x..\x..'   # U+XXXX  nf-* glyph description
EM_<NAME>='<emoji or symbol>'
```

Use `printf '\U<codepoint>'` or a Nerd Font reference to find the correct bytes.

---

## 2. `lib/icons.sh` — `get_icon()` cases

Add a case entry for the new name in **both** the `nerd` and `emoji` blocks inside `get_icon()`:

```bash
nerd)
  case "$name" in
    ...
    <name>) printf '%s' "$NF_<NAME>" ;;
    ...
  esac ;;
emoji)
  case "$name" in
    ...
    <name>) printf '%s' "$EM_<NAME>" ;;
    ...
  esac ;;
```

---

## 3. `lib/icons.sh` — resolved icon variable

Add `IC_<NAME>=$(get_icon <name>)` to the `bl_init_icons()` function, in the block of resolved icon vars:

```bash
IC_<NAME>=$(get_icon <name>)
```

---

## 4. `lib/config.sh` — config variable (if needed)

If the segment reads a threshold or config value from `settings.json`, declare the config var in `bl_load_config()`:

```bash
CFG_<NAME>_THR=$(cfg_json '.segments.<name>')
```

---

## 5. `lib/segments.sh` — `build_<name>()` function

Write the builder. Choose the pattern that fits:

**Simple (static value from JSON input):**
```bash
build_<name>() {
  [[ -z "$<name>_val" ]] && return   # read in bl_read_state (see below)
  add_seg "${FG_ACCENT}${IC_<NAME>} ${FG_TEXT}${<name>_val}"
}
```

**With threshold colouring:**
```bash
build_<name>() {
  [[ -z "$<name>_val" ]] && return
  local int_val; int_val=$(printf '%.0f' "$<name>_val")
  threshold_resolve "$CFG_<NAME>_THR" "$int_val"
  add_seg "${FG_ACCENT}${IC_<NAME>} ${THR_COLOR_ANSI}${<name>_val}"
}
```

**With a gauge bar:**
```bash
build_<name>() {
  (( <total> <= 0 )) && return
  local bar; bar=$(gauge "$<used>" "$<total>" 10)
  add_seg "${FG_ACCENT}${IC_<NAME>} ${bar} ${FG_TEXT}$(fmt_k "$<used>")/$(fmt_k "$<total>")"
}
```

Also add the new segment name to the `case` statement in `bl_render_main_line()`, and — only if it should render when no config sets `segments.enabled` — to the fallback list in `bl_resolve_active_segments()`:

```bash
# case statement
<name>) build_<name> ;;
```

**Payload fields:** `bl_read_state()` in `lib/state.sh` reads the whole payload in one jq pass. Add the field to that array (and a variable to its `read`) instead of calling `j` in the builder — each `j` call forks jq on every refresh. Use `(.a // .b)` alternatives, never `empty`: an element that produces nothing shifts every later field.

**Transcript totals:** if the segment needs `sum_*` or `web_searches`, add it to `_bl_usage_needed()` in `lib/usage.sh`; the transcript is not read otherwise.

---

## 6. `settings.json` — defaults

If the segment should show out of the box, add it to `segments.enabled` — and to the matching fallback list in `bl_resolve_active_segments()` (step 5). Segments that are niche or cost a transcript read (`tokens_in`, `tokens_out`) stay opt-in: documented, but not in the default list.

```json
"enabled": ["model", "effort", "context", "prompt_cache", "directory",
            "git_branch", "usage_5h", "usage_7d", "cost", "<name>"]
```

If the segment has threshold configuration, add its default entry under `segments`:

```json
"<name>": {
  "90": { "color": "danger" },
  "75": { "color": "warning" }
}
```

---

## 7. `skills/configure/SKILL.md` — two places

**`appearance.icons.overrides` key list** — add `<name>` to the sentence listing overridable segment keys.

**`segments.enabled` reference** — add `<name>` to the Available list in the `segments` key reference table:

```
| `enabled` | Ordered array... Available: `model`, ..., `<name>` |
```

---

## 8. `skills/debug/SKILL.md` — `$vsegs` validation array

Find the config-validation jq snippet in step 7 and add `"<name>"` to the `$vsegs` array:

```jq
["model","effort","context","directory","git_branch",
 "tokens_in","tokens_out","usage_5h","usage_7d","cost","<name>"] as $vsegs |
```

---

## 9. Tests

Add to `tests/integration/segments.bats` — minimum two cases:

```bash
@test "<name>: renders when value present" {
  bl_run '<json with the value>' "$(_only <name>)"
  [[ "$BL_OUTPUT" == *"<expected text>"* ]]
}

@test "<name>: hidden when value absent" {
  bl_run '{}' "$(_only <name>)"
  stripped=$(printf '%s' "$BL_OUTPUT" | tr -d ' \n')
  [ -z "$stripped" ]
}
```

If the segment uses a threshold config, add a third test asserting the correct colour fires. Assert on `$BL_OUTPUT_RAW` for ANSI colour checks (see `write-tests` skill).

---

## Checklist

- [ ] `NF_<NAME>` and `EM_<NAME>` constants added to `lib/icons.sh`
- [ ] Both `nerd` and `emoji` cases in `get_icon()` in `lib/icons.sh`
- [ ] `IC_<NAME>` resolved var added to `bl_init_icons()` in `lib/icons.sh`
- [ ] Config var declared in `bl_load_config()` in `lib/config.sh` (if needed)
- [ ] `build_<name>()` written in `lib/segments.sh`; added to the render `case` (and the `bl_resolve_active_segments` fallback if it is a default)
- [ ] Payload fields added to the jq pass in `bl_read_state()`; `_bl_usage_needed()` updated if it uses transcript totals
- [ ] `settings.json` `enabled` list updated; threshold defaults added if needed
- [ ] `skills/configure/SKILL.md` icon override list and segment reference updated
- [ ] `skills/debug/SKILL.md` `$vsegs` array updated
- [ ] Tests added to `tests/integration/segments.bats`
