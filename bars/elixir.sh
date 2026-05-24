#!/usr/bin/env bash
# Bottomline bar: Elixir ecosystem bar
# Only renders when the project contains a mix.exs.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
if [[ "$_bl_ttl" -gt 0 ]]; then
  _bl_cache=$(bl_cache_path "elixir" "$_bl_ttl" "$PROJ" "$PROJ/mix.exs" "$PROJ/mix.lock")
  [[ -f "$_bl_cache" ]] && cat "$_bl_cache" && exit 0
fi

[[ ! -f "$PROJ/mix.exs" ]] && exit 0

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
    IC_LV=$'\xef\x84\xa1'        # U+F121  nf-fa-code
    IC_DB=$'\xef\x87\x80'        # U+F1C0  nf-fa-database
    IC_QUEUE=$'\xef\x83\xa2'     # U+F0E2  nf-fa-history
    IC_TEST=$'\xef\x81\x80'      # U+F040  nf-fa-pencil
    IC_LINT=$'\xef\x80\x8c'      # U+F00C  nf-fa-check
    IC_TYPE=$'\xef\x80\xae'      # U+F02E  nf-fa-bookmark (type analysis)
    ;;
  emoji)
    IC_ELIXIR='💧'
    IC_PHOENIX='🔥'
    IC_LV='🔌' IC_DB='🗄' IC_QUEUE='📨' IC_TEST='🧪' IC_LINT='✓' IC_TYPE='🔎'
    ;;
  *)
    IC_ELIXIR='' IC_PHOENIX=''
    IC_LV='' IC_DB='' IC_QUEUE='' IC_TEST='' IC_LINT='' IC_TYPE=''
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

# ── Detect add-ons + tooling from mix.lock ────────────────────────────────────
liveview_version=''
ecto_version=''
oban_version=''
credo_version=''
dialyxir_version=''

if [[ -f "$lock" ]]; then
  liveview_version=$(awk -F'"' '/"phoenix_live_view":/{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\./){print $i; exit}}' "$lock" 2>/dev/null)
  ecto_version=$(awk -F'"' '/"ecto_sql":/{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\./){print $i; exit}}' "$lock" 2>/dev/null)
  oban_version=$(awk -F'"' '/"oban":/{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\./){print $i; exit}}' "$lock" 2>/dev/null)
  credo_version=$(awk -F'"' '/"credo":/{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\./){print $i; exit}}' "$lock" 2>/dev/null)
  dialyxir_version=$(awk -F'"' '/"dialyxir":/{for(i=1;i<=NF;i++) if($i ~ /^[0-9]+\./){print $i; exit}}' "$lock" 2>/dev/null)
fi

has_exunit=false
[[ -d "$PROJ/test" ]] && has_exunit=true

_bl_out=$(
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

  # Slot 4: Add-ons
  [[ -n "$liveview_version" ]] \
    && add_seg "${FG_ACCENT}${IC_LV} ${FG_TEXT}LiveView ${FG_ACCENT}v${liveview_version}"
  [[ -n "$ecto_version" ]] \
    && add_seg "${FG_ACCENT}${IC_DB} ${FG_TEXT}Ecto ${FG_ACCENT}v${ecto_version}"
  [[ -n "$oban_version" ]] \
    && add_seg "${FG_ACCENT}${IC_QUEUE} ${FG_TEXT}Oban ${FG_ACCENT}v${oban_version}"

  # Slot 5: Testing
  $has_exunit \
    && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}ExUnit"

  # Slot 6: Tooling
  [[ -n "$credo_version" ]] \
    && add_seg "${FG_ACCENT}${IC_LINT} ${FG_TEXT}Credo ${FG_ACCENT}v${credo_version}"
  [[ -n "$dialyxir_version" ]] \
    && add_seg "${FG_ACCENT}${IC_TYPE} ${FG_TEXT}Dialyxir ${FG_ACCENT}v${dialyxir_version}"

  (( ${#_sc[@]} == 0 )) && exit 0
  flush "$_bar_gradient"
)
if [[ "$_bl_ttl" -gt 0 ]]; then
  bl_cache_write "$_bl_cache" "$_bl_out"
fi
printf '%s' "$_bl_out"
