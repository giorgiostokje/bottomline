#!/usr/bin/env bash
# Bottomline bar: Elixir ecosystem bar
# Only renders when the project contains a mix.exs.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init elixir "#e8d8f8" "#a078d8" '["#180c2e","#2a1850"]' "$PROJ/mix.exs" "$PROJ/mix.lock"

[[ ! -f "$PROJ/mix.exs" ]] && exit 0

bl_icon_set IC_ELIXIR $'\xef\x81\xad' '💧'
bl_icon_set IC_PHOENIX $'\xef\x86\x85' '🔥'
bl_icon_set IC_LV     $'\xef\x84\xa1' '🔌'
bl_icon_set IC_DB     $'\xef\x87\x80' '🗄'
bl_icon_set IC_QUEUE  $'\xef\x83\xa2' '📨'
bl_icon_set IC_TEST   $'\xef\x81\x80' '🧪'
bl_icon_set IC_LINT   $'\xef\x80\x8c' '✓'
bl_icon_set IC_TYPE   $'\xef\x80\xae' '🔎'


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

# ── Elixir runtime ────────────────────────────────────────────────────────────
bl_version_seg "$IC_ELIXIR" Elixir "$elixir_version"

# ── Phoenix ───────────────────────────────────────────────────────────────────
$has_phoenix && bl_version_seg "$IC_PHOENIX" Phoenix "$phoenix_version"

# Slot 4: Add-ons
[[ -n "$liveview_version" ]] && bl_version_seg "$IC_LV" LiveView "$liveview_version"
[[ -n "$ecto_version" ]] && bl_version_seg "$IC_DB" Ecto "$ecto_version"
[[ -n "$oban_version" ]] && bl_version_seg "$IC_QUEUE" Oban "$oban_version"

# Slot 5: Testing
$has_exunit && bl_version_seg "$IC_TEST" ExUnit ""

# Slot 6: Tooling
[[ -n "$credo_version" ]] && bl_version_seg "$IC_LINT" Credo "$credo_version"
[[ -n "$dialyxir_version" ]] && bl_version_seg "$IC_TYPE" Dialyxir "$dialyxir_version"

bl_bar_finish "$_bar_gradient"
