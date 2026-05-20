#!/usr/bin/env bash
# Bottomline bar: random fact bar
# Colors are fully dictated by the bar's config — no hardcoded fallbacks.

source "$BOTTOMLINE_LIB/helpers.sh"
case "$BOTTOMLINE_ICON_TYPE" in
  nerd)  IC_FACT=$'\xef\x83\xab' ;;
  emoji) IC_FACT='💡' ;;
  *)     IC_FACT='' ;;
esac

fact=$(curl -sf --max-time 3 \
  'https://uselessfacts.jsph.pl/api/v2/facts/random?language=en' \
  2>/dev/null | jq -r '.text // empty' 2>/dev/null)

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
