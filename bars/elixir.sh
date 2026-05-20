#!/usr/bin/env bash
# Bottomline bar: Elixir ecosystem bar
# Only renders when the project contains a mix.exs.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" || ! -f "$PROJ/mix.exs" ]] && exit 0

source "$BOTTOMLINE_LIB/helpers.sh"

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#e8d8f8")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#a078d8")")
  _bar_gradient='["#180c2e","#2a1850"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_ELIXIR=$'\xef\x81\xad'   # U+F06D  nf-fa-fire  (Elixir's flame-like logo)
    IC_PHOENIX=$'\xef\x86\x85'  # U+F185  nf-fa-sun-o  (Phoenix rising)
    ;;
  emoji)
    IC_ELIXIR='💧'
    IC_PHOENIX='🔥'
    ;;
  *)
    IC_ELIXIR='' IC_PHOENIX=''
    ;;
esac


# ── Read Elixir version constraint from mix.exs ───────────────────────────────
elixir_version=$(grep -m1 'elixir:' "$PROJ/mix.exs" 2>/dev/null \
  | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')

# Fallback: .tool-versions (asdf/mise) or .elixir-version
if [[ -z "$elixir_version" && -f "$PROJ/.tool-versions" ]]; then
  elixir_version=$(awk '/^elixir /{print $2; exit}' "$PROJ/.tool-versions" 2>/dev/null)
fi
[[ -z "$elixir_version" && -f "$PROJ/.elixir-version" ]] && \
  elixir_version=$(tr -d '[:space:]' < "$PROJ/.elixir-version")

# ── Detect Phoenix from mix.lock ──────────────────────────────────────────────
has_phoenix=false phoenix_version=''
lock="$PROJ/mix.lock"
if [[ -f "$lock" ]]; then
  if grep -q '"phoenix"' "$lock" 2>/dev/null; then
    has_phoenix=true
    phoenix_version=$(awk '/"phoenix"/{match($0,/"[0-9]+\.[0-9]+\.[0-9]+"/, a); if(a[0]) {gsub(/"/, "", a[0]); print a[0]; exit}}' "$lock" 2>/dev/null)
  fi
fi

# Fallback: check mix.exs deps for {:phoenix, ...}
if ! $has_phoenix && grep -q ':phoenix,' "$PROJ/mix.exs" 2>/dev/null; then
  has_phoenix=true
fi


# ── Elixir runtime ────────────────────────────────────────────────────────────
elixir_seg="${FG_ACCENT}${IC_ELIXIR} ${FG_TEXT}Elixir"
[[ -n "$elixir_version" ]] && elixir_seg+=" ${FG_ACCENT}v${elixir_version}"
add_seg "$elixir_seg"

# ── Phoenix ───────────────────────────────────────────────────────────────────
if $has_phoenix; then
  phoenix_seg="${FG_ACCENT}${IC_PHOENIX} ${FG_TEXT}Phoenix"
  [[ -n "$phoenix_version" ]] && phoenix_seg+=" ${FG_ACCENT}v${phoenix_version}"
  add_seg "$phoenix_seg"
fi

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
