#!/usr/bin/env bats
# Integration tests for the random-facts bar script.

bats_require_minimum_version 1.5.0
load '../../helpers'

# Inject a fake curl that always fails so tests are deterministic and instant.
setup() {
  FAKE_BIN=$(mktemp -d)
  printf '#!/bin/bash\nexit 1\n' > "$FAKE_BIN/curl"
  chmod +x "$FAKE_BIN/curl"
  # Evict any cached fact so tests exercise the offline fallback path.
  # Use -print0 | xargs -0 rm -f because macOS forbids -L with -delete.
  find -L /tmp -maxdepth 1 -name 'bl_random-fact_*.txt' -print0 2>/dev/null | xargs -0 rm -f 2>/dev/null
}

teardown() {
  if [[ -n "${FAKE_BIN:-}" ]]; then
    rm -rf "$FAKE_BIN"
    FAKE_BIN=''
  fi
}

# Run the random-facts bar with the fake curl on PATH.
_rf_run() {
  BAR_OUTPUT_RAW=$(
    PATH="$FAKE_BIN:$PATH" \
    BOTTOMLINE_LIB="$BOTTOMLINE_ROOT/lib" \
    BOTTOMLINE_ICON_TYPE=none \
    BOTTOMLINE_GRADIENT='"#1a1a1a"' \
    BOTTOMLINE_BAR_COLORS= \
    BOTTOMLINE_BG_R=26 BOTTOMLINE_BG_G=26 BOTTOMLINE_BG_B=26 \
    BOTTOMLINE_SEP='|' \
    BOTTOMLINE_BOLD='' BOTTOMLINE_RESET='' \
    BOTTOMLINE_TEXT_HEX='#e2d5c3' \
    BOTTOMLINE_ACCENT_HEX='#da7756' \
    BOTTOMLINE_WARN_HEX='#f4a261' \
    BOTTOMLINE_DANGER_HEX='#e05a4e' \
    bash "$BOTTOMLINE_ROOT/bars/random-facts.sh"
  )
  BAR_OUTPUT=$(printf '%s' "$BAR_OUTPUT_RAW" | strip_ansi)
}

@test "random-facts: produces non-empty output when curl fails (offline fallback)" {
  _rf_run
  stripped=$(printf '%s' "$BAR_OUTPUT" | tr -d ' \n|')
  [ -n "$stripped" ]
}

@test "random-facts: output contains offline marker when curl fails" {
  _rf_run
  [[ "$BAR_OUTPUT" == *"(offline)"* ]]
}
