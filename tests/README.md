# Bottomline Tests

## Dependencies

- **Bash ≥ 4** — `bash --version`
- **jq** — `jq --version`
- **bats-core ≥ 1.5** — `bats --version`
- **perl** — for ANSI stripping in helpers (ships with macOS/Linux)

### Install bats-core

**Homebrew (macOS / Linux):**
```sh
brew install bats-core
```

**npm:**
```sh
npm install -g bats
```

**From source:**
```sh
git clone https://github.com/bats-core/bats-core.git
cd bats-core && ./install.sh /usr/local
```

## Running Tests

From the plugin root (`~/.claude/bottomline/`):

```sh
# All tests
bats --recursive tests/

# Only unit tests
bats tests/unit/

# Only integration tests
bats tests/integration/

# Single file
bats tests/unit/fmt.bats

# Verbose output
bats --verbose-run tests/
```

## Test Structure

```
tests/
├── helpers.bash               # Shared helpers (strip_ansi, bl_run, make_transcript)
├── unit/
│   ├── fmt.bats               # fmt_n, fmt_k, fmt_remaining
│   └── decode_icon.bats       # decode_icon (hex codepoint → Unicode char)
└── integration/
    ├── segments.bats          # Segment rendering, tokens icon fallback
    └── config.bats            # Three-layer config merge, theme priority, thresholds
```

## How Integration Tests Work

Each integration test:
1. Creates a temporary fake `$HOME` containing `settings.json` and the available themes.
2. Optionally writes user- and project-level config JSON.
3. Runs `bottomline.sh` with controlled JSON input piped to stdin.
4. Asserts on `$BL_OUTPUT` (ANSI stripped) or `$BL_OUTPUT_RAW` (raw) as needed.

Config isolation means no test is affected by your actual `~/.claude/bottomline.json`.

## Bats gotcha: `${var:-{}}` appends an extra `}`

In bats (and in bash generally), `"${1:-{}}"` does **not** mean "default to `{}`". Bash parses `${1:-{}` as the whole expansion (default = `{`), leaving a bare `}` that gets concatenated. The result is `$1 + }` — so any JSON argument with nested braces silently becomes invalid.

The helpers avoid this by using plain `"$1"` with a separate empty check:
```bash
local json="$1"
if [[ -z "$json" ]]; then json='{}'; fi
```

Never use `"${var:-{}}"` in test helpers or bats-loaded scripts.

## Notes

- **Token count tests** create a temporary JSON-lines transcript file via `make_transcript`. The path is passed in `{"transcript_path":"..."}` in the input JSON, matching how Claude Code calls the script.
- **Color/ANSI tests** check `$BL_OUTPUT_RAW` directly for specific RGB escape sequences (e.g. `\e[38;2;203;166;247m`). This is the only reliable way to verify that a theme or threshold color fired.
