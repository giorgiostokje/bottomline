---
name: add-segment
description: Step-by-step checklist for adding a new built-in segment to the main Bottomline status line. Use whenever implementing a new segment — the change spans five files and agents reliably miss steps without this checklist.
---

# Add a Built-in Segment

Adding a segment requires **nine steps across five files** — steps 1–5 all modify `bottomline.sh`; steps 6–9 each touch a different file. Complete every step; skipping any leaves the segment broken or inconsistent.

---

## 1. `bottomline.sh` — icon constants

Add one `NF_*` entry (raw UTF-8 bytes of the Nerd Font codepoint) and one `EM_*` entry (emoji or ASCII fallback) alongside the existing constants:

```bash
NF_<NAME>=$'\x..\x..\x..'   # U+XXXX  nf-* glyph description
EM_<NAME>='<emoji or symbol>'
```

Use `printf '\U<codepoint>'` or a Nerd Font reference to find the correct bytes.

---

## 2. `bottomline.sh` — `get_icon()` cases

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

## 3. `bottomline.sh` — resolved icon variable

Add `IC_<NAME>=$(get_icon <name>)` to the block of resolved icon vars below `get_icon()`:

```bash
IC_<NAME>=$(get_icon <name>)
```

---

## 4. `bottomline.sh` — `build_<name>()` function

Write the builder. Choose the pattern that fits:

**Simple (static value from JSON input):**
```bash
build_<name>() {
  local val; val=$(j '.<json_path>')
  [[ -z "$val" ]] && return
  add_seg "${FG_ACCENT}${IC_<NAME>} ${FG_TEXT}${val}"
}
```

**With threshold colouring:**
```bash
build_<name>() {
  local val; val=$(j '.<json_path>')
  [[ -z "$val" ]] && return
  local int_val; int_val=$(printf '%.0f' "$val")
  threshold_resolve "$CFG_<NAME>_THR" "$int_val"
  add_seg "${FG_ACCENT}${IC_<NAME>} ${THR_COLOR_ANSI}${val}"
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

If the segment reads a threshold config from `settings.json`, declare the config var near the top of the config-reading block:

```bash
CFG_<NAME>_THR=$(cfg_json '.segments.<name>')
```

---

## 5. `bottomline.sh` — render loop

Add an entry to `_items_out` default list and to the `case` statement:

```bash
# _items_out default string — add "<name>" on its own line
[[ -z "$_items_out" ]] && _items_out="model
...
<name>"

# case statement
<name>) build_<name> ;;
```

---

## 6. `settings.json` — defaults

Add the segment name to `segments.enabled`:

```json
"enabled": ["model", "effort", "context", "directory", "git_branch",
            "tokens_in", "tokens_out", "usage_5h", "usage_7d", "cost", "<name>"]
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

- [ ] `NF_<NAME>` and `EM_<NAME>` constants added
- [ ] Both `nerd` and `emoji` cases in `get_icon()`
- [ ] `IC_<NAME>` resolved var added
- [ ] `build_<name>()` written; config var declared if needed
- [ ] Added to `_items_out` default list and render `case`
- [ ] `settings.json` `enabled` list updated; threshold defaults added if needed
- [ ] `skills/configure/SKILL.md` icon override list and segment reference updated
- [ ] `skills/debug/SKILL.md` `$vsegs` array updated
- [ ] Tests added to `tests/integration/segments.bats`
