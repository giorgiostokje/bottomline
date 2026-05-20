#!/usr/bin/env bash
# Pure utility functions — no global state, no side effects.
# Sourced by bottomline.sh and the test suite.

fmt_n() {
  local n=$1
  if   [ "$n" -ge 1000000 ]; then printf '%.1fM' "$(echo "scale=1; $n/1000000" | bc)"
  elif [ "$n" -ge 1000 ];    then printf '%.1fk' "$(echo "scale=1; $n/1000"    | bc)"
  else printf '%d' "$n"; fi
}

fmt_k() { printf '%dk' "$(( (${1:-0} + 500) / 1000 ))"; }

fmt_remaining() {
  local secs="${1:-0}"; (( secs <= 0 )) && return
  local h=$(( secs / 3600 )) m=$(( (secs % 3600) / 60 ))
  if   (( h >= 24 )); then printf '%dd%dh' $(( h / 24 )) $(( h % 24 ))
  elif (( h >  0  )); then printf '%dh%dm' "$h" "$m"
  else                     printf '%dm' "$m"; fi
}

# Converts a 4–6 digit hex codepoint string (e.g. "e73f") to its Unicode
# character. Any other string (a literal glyph or emoji) is returned as-is.
decode_icon() {
  local s="$1"
  [[ -z "$s" ]] && return
  if [[ "$s" =~ ^[0-9a-fA-F]{4,6}$ ]]; then
    printf '%s' "$s" | jq -Rr '
      split("") | map(
        if test("[0-9]") then tonumber
        elif test("[a-f]") then explode[0] - 87
        elif test("[A-F]") then explode[0] - 55
        else 0 end
      ) | reduce .[] as $d (0; . * 16 + $d) | [.] | implode
    ' 2>/dev/null || printf '%s' "$s"
  else
    printf '%s' "$s"
  fi
}
