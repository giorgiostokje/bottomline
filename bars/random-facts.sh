#!/usr/bin/env bash
# Bottomline bar: random fact bar
# Colors are fully dictated by the bar's config — no hardcoded fallbacks.

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"
case "$BOTTOMLINE_ICON_TYPE" in
  nerd)  IC_FACT=$'\xef\x83\xab' ;;
  emoji) IC_FACT='💡' ;;
  *)     IC_FACT='' ;;
esac

# Cache is managed manually here rather than via bl_cache_path/bl_cache_write
# because the cache key is time-bucket based (not project-scoped), so there is
# no per-project component in the filename.
_refresh_mins="${BOTTOMLINE_BAR_REFRESH_MINUTES:-60}"
_bucket=$(( $(date +%s) / (_refresh_mins * 60) ))
_cache_file="/tmp/bl_random-fact_${_bucket}.txt"

fact=''
if [[ -f "$_cache_file" ]]; then
  fact=$(cat "$_cache_file")
fi

if [[ -z "$fact" ]]; then
  fact=$(curl -sf --max-time 3 \
    'https://uselessfacts.jsph.pl/api/v2/facts/random?language=en' \
    2>/dev/null | jq -r '.text // empty' 2>/dev/null)
  if [[ -n "$fact" ]]; then
    printf '%s' "$fact" > "$_cache_file"
    find -L /tmp -maxdepth 1 -name 'bl_random-fact_*.txt' \
      ! -name "bl_random-fact_${_bucket}.txt" -print0 2>/dev/null | xargs -0 rm -f 2>/dev/null
  fi
fi

offline_suffix=''
if [[ -z "$fact" ]]; then
  offline_suffix=" ${FG_ACCENT}(offline)"
  offline_facts=(
    "Cleopatra lived closer in time to the Moon landing than to the Great Pyramid."
    "Oxford University is older than the Aztec Empire."
    "A day on Venus is longer than a year on Venus."
    "Sharks are older than trees."
    "The fax machine was invented before the telephone."
    "Nintendo was founded in 1889 as a playing-card company."
    "Bats are the only mammals capable of sustained, powered flight."
    "A jiffy is a real unit of time: 1/100th of a second."
    "There are more trees on Earth than stars in the Milky Way."
    "Every atom in your body was forged inside a star."
  )
  fact="${offline_facts[$((RANDOM % ${#offline_facts[@]}))]}"
fi

fact="${fact%"${fact##*[^[:space:]]}"}"

fact_bg=$(bg3 "$BOTTOMLINE_BG_R" "$BOTTOMLINE_BG_G" "$BOTTOMLINE_BG_B")
fact_fg=$(fg3 "$BOTTOMLINE_BG_R" "$BOTTOMLINE_BG_G" "$BOTTOMLINE_BG_B")
printf '%s' "${fact_bg} ${B}${FG_ACCENT}${IC_FACT} ${FG_TEXT}${fact}${offline_suffix}${fact_bg} ${R}${fact_fg}${SEP}${R}"
