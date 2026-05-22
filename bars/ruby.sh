#!/usr/bin/env bash
# Bottomline bar: Ruby ecosystem bar
# Only renders when the project contains a Gemfile.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
if [[ "$_bl_ttl" -gt 0 ]]; then
  _bl_cache=$(bl_cache_path "ruby" "$_bl_ttl" "$PROJ")
  [[ -f "$_bl_cache" ]] && cat "$_bl_cache" && exit 0
fi

[[ ! -f "$PROJ/Gemfile" ]] && exit 0

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#f5d0d0")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#e05060")")
  _bar_gradient='["#1e0505","#350c0c"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_RUBY=$'\xee\x9e\x91'    # U+E791  nf-dev-ruby
    IC_RAILS=$'\xee\x9c\xbb'   # U+E73B  nf-dev-rails
    IC_SINATRA=$'\xef\x81\xad' # U+F06D  nf-fa-fire  (Sinatra — keeps it simple)
    IC_HANAMI=$'\xef\x81\xac'  # U+F06C  nf-fa-leaf
    IC_TEST=$'\xef\x81\x80'    # U+F040  nf-fa-pencil
    IC_QUEUE=$'\xef\x83\xa2'   # U+F0E2  nf-fa-history
    IC_AUTH=$'\xef\x82\xa3'    # U+F0A3  nf-fa-certificate
    IC_LINT=$'\xef\x80\x8c'    # U+F00C  nf-fa-check
    ;;
  emoji)
    IC_RUBY='💎'
    IC_RAILS='🛤'
    IC_SINATRA='🎵'
    IC_HANAMI='🌸'
    IC_TEST='🧪' IC_QUEUE='📨' IC_AUTH='🔑' IC_LINT='✓'
    ;;
  *)
    IC_RUBY='' IC_RAILS='' IC_SINATRA='' IC_HANAMI=''
    IC_TEST='' IC_QUEUE='' IC_AUTH='' IC_LINT=''
    ;;
esac


# Returns the locked version of a gem from Gemfile.lock.
gem_version() {
  local gem="$1" lock="$PROJ/Gemfile.lock"
  [[ ! -f "$lock" ]] && return
  awk -v g="$gem" '$1==g { match($2,/[0-9][0-9.]*/); if(RSTART) print substr($2,RSTART,RLENGTH); exit }' \
    "$lock" 2>/dev/null
}

# ── Read Ruby version ─────────────────────────────────────────────────────────
ruby_version=''
if [[ -f "$PROJ/.ruby-version" ]]; then
  ruby_version=$(tr -d '[:space:]' < "$PROJ/.ruby-version" | sed 's/^ruby-//')
elif command -v ruby > /dev/null 2>&1; then
  ruby_version=$(ruby -e 'print RUBY_VERSION' 2>/dev/null)
fi

# ── Detect framework ──────────────────────────────────────────────────────────
has_rails=false has_sinatra=false has_hanami=false
rails_version='' sinatra_version='' hanami_version=''

if grep -qiE "gem ['\"]rails['\"]" "$PROJ/Gemfile" 2>/dev/null; then
  has_rails=true; rails_version=$(gem_version "rails")
fi
if grep -qiE "gem ['\"]sinatra['\"]" "$PROJ/Gemfile" 2>/dev/null; then
  has_sinatra=true; sinatra_version=$(gem_version "sinatra")
fi
if grep -qiE "gem ['\"]hanami['\"]" "$PROJ/Gemfile" 2>/dev/null; then
  has_hanami=true; hanami_version=$(gem_version "hanami")
fi

# ── Detect testing + add-ons + linter from Gemfile.lock ───────────────────────
lock="$PROJ/Gemfile.lock"
has_rspec=false
has_minitest=false
has_sidekiq=false
has_devise=false
rubocop_version=''

if [[ -f "$lock" ]]; then
  grep -Eq '^[[:space:]]+rspec(-core)?[[:space:]]' "$lock" 2>/dev/null && has_rspec=true
  grep -Eq '^[[:space:]]+minitest[[:space:]]' "$lock" 2>/dev/null && has_minitest=true
  grep -Eq '^[[:space:]]+sidekiq[[:space:]]' "$lock" 2>/dev/null && has_sidekiq=true
  grep -Eq '^[[:space:]]+devise[[:space:]]' "$lock" 2>/dev/null && has_devise=true
  rubocop_version=$(awk '/^[[:space:]]+rubocop[[:space:]]+\(/{gsub(/[()]/,"",$2); print $2; exit}' "$lock" 2>/dev/null)
fi

# RuboCop can also be detected via config file alone
[[ -z "$rubocop_version" && -f "$PROJ/.rubocop.yml" ]] && rubocop_version='present'

# ── Version detection for add-ons ──────────────────────────────────────────────
sidekiq_version=''
devise_version=''
$has_sidekiq && sidekiq_version=$(gem_version "sidekiq")
$has_devise  && devise_version=$(gem_version "devise")


_bl_out=$(
  # ── Ruby runtime ──────────────────────────────────────────────────────────────
  ruby_seg="${FG_ACCENT}${IC_RUBY} ${FG_TEXT}Ruby"
  [[ -n "$ruby_version" ]] && ruby_seg+=" ${FG_ACCENT}v${ruby_version}"
  add_seg "$ruby_seg"

  # ── Framework ─────────────────────────────────────────────────────────────────
  if $has_rails; then
    rails_seg="${FG_ACCENT}${IC_RAILS} ${FG_TEXT}Rails"
    [[ -n "$rails_version" ]] && rails_seg+=" ${FG_ACCENT}v${rails_version}"
    add_seg "$rails_seg"
  fi
  if $has_sinatra; then
    sinatra_seg="${FG_ACCENT}${IC_SINATRA} ${FG_TEXT}Sinatra"
    [[ -n "$sinatra_version" ]] && sinatra_seg+=" ${FG_ACCENT}v${sinatra_version}"
    add_seg "$sinatra_seg"
  fi
  if $has_hanami; then
    hanami_seg="${FG_ACCENT}${IC_HANAMI} ${FG_TEXT}Hanami"
    [[ -n "$hanami_version" ]] && hanami_seg+=" ${FG_ACCENT}v${hanami_version}"
    add_seg "$hanami_seg"
  fi

  # Slot 5: Testing
  $has_rspec    && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}RSpec"
  $has_minitest && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}Minitest"

  # Slot 6: Tooling (order: RuboCop → Sidekiq → Devise)
  if [[ -n "$rubocop_version" ]]; then
    if [[ "$rubocop_version" == "present" ]]; then
      add_seg "${FG_ACCENT}${IC_LINT} ${FG_TEXT}RuboCop"
    else
      add_seg "${FG_ACCENT}${IC_LINT} ${FG_TEXT}RuboCop ${FG_ACCENT}v${rubocop_version}"
    fi
  fi
  if $has_sidekiq; then
    sk_seg="${FG_ACCENT}${IC_QUEUE} ${FG_TEXT}Sidekiq"
    [[ -n "$sidekiq_version" ]] && sk_seg+=" ${FG_ACCENT}v${sidekiq_version}"
    add_seg "$sk_seg"
  fi
  if $has_devise; then
    dv_seg="${FG_ACCENT}${IC_AUTH} ${FG_TEXT}Devise"
    [[ -n "$devise_version" ]] && dv_seg+=" ${FG_ACCENT}v${devise_version}"
    add_seg "$dv_seg"
  fi

  (( ${#_sc[@]} == 0 )) && exit 0
  flush "$_bar_gradient"
)
if [[ "$_bl_ttl" -gt 0 ]]; then
  bl_cache_write "$_bl_cache" "$_bl_out"
fi
printf '%s' "$_bl_out"
