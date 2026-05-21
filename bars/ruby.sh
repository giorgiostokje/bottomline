#!/usr/bin/env bash
# Bottomline bar: Ruby ecosystem bar
# Only renders when the project contains a Gemfile.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" || ! -f "$PROJ/Gemfile" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

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
    ;;
  emoji)
    IC_RUBY='💎'
    IC_RAILS='🛤'
    IC_SINATRA='🎵'
    IC_HANAMI='🌸'
    ;;
  *)
    IC_RUBY='' IC_RAILS='' IC_SINATRA='' IC_HANAMI=''
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

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
