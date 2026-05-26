#!/usr/bin/env bash
# Bottomline bar: Ruby ecosystem bar
# Only renders when the project contains a Gemfile.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init ruby "#f5d0d0" "#e05060" '["#1e0505","#350c0c"]' "$PROJ/Gemfile" "$PROJ/Gemfile.lock"

[[ ! -f "$PROJ/Gemfile" ]] && exit 0

bl_icon_set IC_RUBY    $'\xee\x9e\x91' '💎'  # U+E791  nf-dev-ruby
bl_icon_set IC_RAILS   $'\xee\x9c\xbb' '🛤'  # U+E73B  nf-dev-rails
bl_icon_set IC_SINATRA $'\xef\x81\xad' '🎵'  # U+F06D  nf-fa-fire  (Sinatra — keeps it simple)
bl_icon_set IC_HANAMI  $'\xef\x81\xac' '🌸'  # U+F06C  nf-fa-leaf
bl_icon_set IC_TEST    $'\xef\x81\x80' '🧪'  # U+F040  nf-fa-pencil
bl_icon_set IC_QUEUE   $'\xef\x83\xa2' '📨'  # U+F0E2  nf-fa-history
bl_icon_set IC_AUTH    $'\xef\x82\xa3' '🔑'  # U+F0A3  nf-fa-certificate
bl_icon_set IC_LINT    $'\xef\x80\x8c' '✓'   # U+F00C  nf-fa-check
bl_icon_set IC_TYPE    $'\xef\x80\xae' '🔎'  # U+F02E  nf-fa-search (type checker)
bl_icon_set IC_BUILD   $'\xef\x84\xa1' '🔨'  # U+F121  nf-fa-wrench


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
  _ruby_exit=$?
  (( _ruby_exit != 0 )) && bl_log debug ruby "ruby -e 'print RUBY_VERSION' exit=${_ruby_exit}"
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
has_factory_bot=false
has_sidekiq=false
has_devise=false
has_sorbet=false
has_brakeman=false
rubocop_version=''
sorbet_version=''

if [[ -f "$lock" ]]; then
  grep -Eq '^[[:space:]]+rspec(-core)?[[:space:]]' "$lock" 2>/dev/null && has_rspec=true
  grep -Eq '^[[:space:]]+minitest[[:space:]]' "$lock" 2>/dev/null && has_minitest=true
  grep -Eq '^[[:space:]]+factory_bot(_rails)?[[:space:]]' "$lock" 2>/dev/null && has_factory_bot=true
  grep -Eq '^[[:space:]]+sorbet(-runtime)?[[:space:]]' "$lock" 2>/dev/null && has_sorbet=true
  grep -Eq '^[[:space:]]+sidekiq[[:space:]]' "$lock" 2>/dev/null && has_sidekiq=true
  grep -Eq '^[[:space:]]+devise[[:space:]]' "$lock" 2>/dev/null && has_devise=true
  grep -Eq '^[[:space:]]+brakeman[[:space:]]' "$lock" 2>/dev/null && has_brakeman=true
  rubocop_version=$(awk '/^[[:space:]]+rubocop[[:space:]]+\(/{gsub(/[()]/,"",$2); print $2; exit}' "$lock" 2>/dev/null)
fi

grep -qiE "gem ['\"]brakeman['\"]" "$PROJ/Gemfile" 2>/dev/null && has_brakeman=true

has_rake=false
[[ -f "$PROJ/Rakefile" ]] && has_rake=true

# RuboCop can also be detected via config file alone
[[ -z "$rubocop_version" && -f "$PROJ/.rubocop.yml" ]] && rubocop_version='present'

# ── Version detection for add-ons ──────────────────────────────────────────────
sidekiq_version=''
devise_version=''
brakeman_version=''
$has_sorbet  && sorbet_version=$(gem_version "sorbet-runtime")
$has_brakeman && brakeman_version=$(gem_version "brakeman")
$has_sidekiq && sidekiq_version=$(gem_version "sidekiq")
$has_devise  && devise_version=$(gem_version "devise")

# ── Ruby runtime ──────────────────────────────────────────────────────────────
bl_version_seg "$IC_RUBY" Ruby "$ruby_version"

# ── Framework ─────────────────────────────────────────────────────────────────
$has_rails   && bl_version_seg "$IC_RAILS" Rails "$rails_version"
$has_sinatra && bl_version_seg "$IC_SINATRA" Sinatra "$sinatra_version"
$has_hanami  && bl_version_seg "$IC_HANAMI" Hanami "$hanami_version"

# Slot 5: Testing
$has_rspec       && bl_version_seg "$IC_TEST" RSpec
$has_minitest    && bl_version_seg "$IC_TEST" Minitest
$has_factory_bot && bl_version_seg "$IC_TEST" factory_bot

# Slot 6: Tooling (order: Sorbet → RuboCop → Brakeman → Sidekiq → Devise → Rake)
$has_sorbet && bl_version_seg "$IC_TYPE" Sorbet "$sorbet_version"
if [[ -n "$rubocop_version" ]]; then
  _rcv="$rubocop_version"
  [[ "$_rcv" == "present" ]] && _rcv=""
  bl_seg "$IC_LINT" RuboCop "$_rcv"
fi
$has_brakeman && bl_version_seg "$IC_LINT" Brakeman "$brakeman_version"
$has_sidekiq && bl_version_seg "$IC_QUEUE" Sidekiq "$sidekiq_version"
$has_devise  && bl_version_seg "$IC_AUTH" Devise "$devise_version"
$has_rake    && bl_version_seg "$IC_BUILD" Rake

bl_bar_finish "$_bar_gradient"
