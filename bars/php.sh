#!/usr/bin/env bash
# Bottomline bar: PHP ecosystem bar
# Renders for any project containing a composer.json.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
if [[ "$_bl_ttl" -gt 0 ]]; then
  _bl_cache=$(bl_cache_path "php" "$_bl_ttl" "$PROJ")
  [[ -f "$_bl_cache" ]] && cat "$_bl_cache" && exit 0
fi

[[ ! -f "$PROJ/composer.json" ]] && exit 0

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#ddd6f3")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#9898e0")")
  _bar_gradient='["#0d0b1e","#1c1850"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_PHP=$'\xee\x9d\xa5'       # U+E765  nf-dev-php
    IC_LARAVEL=$'\xee\x9c\xbf'   # U+E73F  nf-dev-laravel
    IC_LUMEN=$'\xee\x9c\xbf'     # U+E73F  nf-dev-laravel  (Lumen = Laravel family)
    IC_SYMFONY=$'\xee\x9d\x97'   # U+E757  nf-dev-symfony
    IC_CAKE=$'\xef\x87\xbd'      # U+F1FD  nf-fa-birthday-cake
    IC_SLIM=$'\xef\x81\xac'      # U+F06C  nf-fa-leaf
    IC_OCTANE=$'\xef\x83\xa4'    # U+F0E4  nf-fa-tachometer
    IC_BOOST=$'\xef\x83\xa7'     # U+F0E7  nf-fa-bolt
    IC_REVERB=$'\xef\x87\xab'    # U+F1EB  nf-fa-wifi
    IC_LIVEWIRE=$'\xef\x81\x83'  # U+F043  nf-fa-tint
    IC_FLUX=$'\xef\x84\xa1'      # U+F121  nf-fa-code
    IC_INERTIA=$'\xef\x84\xa4'   # U+F124  nf-fa-location-arrow
    IC_FILAMENT=$'\xef\x80\x85'  # U+F005  nf-fa-star
    IC_HERD=$'\xef\x82\xac'      # U+F0AC  nf-fa-globe
    IC_TEST=$'\xef\x81\x80'      # U+F040  nf-fa-pencil
    IC_PHPSTAN=$'\xef\x80\x8c'   # U+F00C  nf-fa-check
    IC_CSFIXER=$'\xef\x80\xb1'   # U+F031  nf-fa-font
    IC_PRO=$'\xef\x82\x91'       # U+F091  nf-fa-trophy
    IC_WARN=$'\xef\x81\xb1'      # U+F071  nf-fa-warning
    ;;
  emoji)
    IC_PHP='🐘'
    IC_LARAVEL='🔥'
    IC_LUMEN='🔦'
    IC_SYMFONY='🎵'
    IC_CAKE='🎂'
    IC_SLIM='🪶'
    IC_OCTANE='🏎'
    IC_BOOST='⚡'
    IC_REVERB='📡'
    IC_LIVEWIRE='🌊'
    IC_FLUX='✨'
    IC_INERTIA='🚀'
    IC_FILAMENT='⭐'
    IC_HERD='🌐'
    IC_TEST='🧪'
    IC_PHPSTAN='🔍'
    IC_CSFIXER='🔧'
    IC_PRO='🏅'
    IC_WARN='⚠'
    ;;
  *)
    IC_PHP='' IC_LARAVEL='' IC_LUMEN='' IC_SYMFONY='' IC_CAKE='' IC_SLIM=''
    IC_OCTANE='' IC_BOOST='' IC_REVERB='' IC_LIVEWIRE='' IC_FLUX='' IC_INERTIA=''
    IC_FILAMENT='' IC_HERD='' IC_TEST='' IC_PHPSTAN='' IC_CSFIXER=''
    IC_PRO='' IC_WARN=''
    ;;
esac

# PHP version from the active binary (fast — no framework bootstrap).
php_version=''
command -v php > /dev/null 2>&1 \
  && php_version=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null)

# Read all relevant versions in one pass over composer.lock.
lock="$PROJ/composer.lock"
laravel_version=''
lumen_version=''
symfony_version=''
cake_version=''
slim_version=''
octane_version=''
boost_version=''
reverb_version=''
livewire_version=''
flux_version=''
flux_pro=false
inertia_version=''
filament_version=''
pest_version=''
phpunit_version=''
phpstan_version=''
csfixer_version=''

if [[ -f "$lock" ]]; then
  while IFS=$'\t' read -r name version; do
    case "$name" in
      laravel/framework)         laravel_version="${version#v}"  ;;
      laravel/lumen-framework)   lumen_version="${version#v}"    ;;
      symfony/framework-bundle)  symfony_version="${version#v}"  ;;
      cakephp/cakephp)           cake_version="${version#v}"     ;;
      slim/slim)                 slim_version="${version#v}"     ;;
      laravel/octane)            octane_version="${version#v}"   ;;
      laravel/boost)             boost_version="${version#v}"    ;;
      laravel/reverb)            reverb_version="${version#v}"   ;;
      livewire/livewire)         livewire_version="${version#v}" ;;
      livewire/flux)             flux_version="${version#v}"     ;;
      livewire/flux-pro)         flux_pro=true                   ;;
      inertiajs/inertia-laravel) inertia_version="${version#v}"  ;;
      inertiajs/inertia-symfony) inertia_version="${version#v}"  ;;
      filament/filament)         filament_version="${version#v}" ;;
      pestphp/pest)              pest_version="${version#v}"     ;;
      phpunit/phpunit)           phpunit_version="${version#v}"  ;;
      phpstan/phpstan)           phpstan_version="${version#v}"  ;;
      friendsofphp/php-cs-fixer) csfixer_version="${version#v}"  ;;
    esac
  done < <(jq -r '(.packages + (.["packages-dev"] // [])) | .[] | [.name, .version] | @tsv' "$lock" 2>/dev/null)
fi

# Detect Inertia frontend framework from package.json.
inertia_framework=''
if [[ -n "$inertia_version" && -f "$PROJ/package.json" ]]; then
  inertia_framework=$(jq -r '
    ((.dependencies // {}) + (.devDependencies // {})) as $d |
    if   ($d | has("@inertiajs/vue3")) or ($d | has("@inertiajs/vue2")) then "Vue"
    elif  $d | has("@inertiajs/react")   then "React"
    elif  $d | has("@inertiajs/svelte")  then "Svelte"
    else ""
    end
  ' "$PROJ/package.json" 2>/dev/null)
fi

# Check boost.json for agents.claude_code.
# Warning is shown only when boost.json exists but claude_code is absent.
boost_json="$PROJ/boost.json"
boost_json_exists=false
boost_agents_ok=false
if [[ -f "$boost_json" ]]; then
  boost_json_exists=true
  agents_has_claude=$(jq -r '(.agents // []) | if type == "array" then any(. == "claude_code") else has("claude_code") end' "$boost_json" 2>/dev/null)
  [[ "$agents_has_claude" == "true" ]] && boost_agents_ok=true
fi

# PHPStan config fallback
[[ -z "$phpstan_version" ]] && { [[ -f "$PROJ/phpstan.neon" || -f "$PROJ/phpstan.dist.neon" ]] && phpstan_version='present'; }
# PHP-CS-Fixer config fallback
[[ -z "$csfixer_version" ]] && { [[ -f "$PROJ/.php-cs-fixer.php" || -f "$PROJ/.php-cs-fixer.dist.php" ]] && csfixer_version='present'; }

# Herd: derive local URL from project directory name.
# Herd secures all .test sites with a local certificate, so HTTPS is correct.
herd_site=''
herd_url=''
if command -v herd > /dev/null 2>&1; then
  herd_site=$(basename "$PROJ")
  herd_url="https://${herd_site}.test"
fi

# ── PHP runtime ───────────────────────────────────────────────────────────────
_bl_out=$(
[[ -n "$php_version" ]] \
  && add_seg "${FG_ACCENT}${IC_PHP} ${FG_TEXT}PHP ${FG_ACCENT}${php_version}"

# ── Framework ─────────────────────────────────────────────────────────────────
[[ -n "$laravel_version" ]] \
  && add_seg "${FG_ACCENT}${IC_LARAVEL} ${FG_TEXT}Laravel ${FG_ACCENT}v${laravel_version}"
[[ -n "$lumen_version" ]] \
  && add_seg "${FG_ACCENT}${IC_LUMEN} ${FG_TEXT}Lumen ${FG_ACCENT}v${lumen_version}"
[[ -n "$symfony_version" ]] \
  && add_seg "${FG_ACCENT}${IC_SYMFONY} ${FG_TEXT}Symfony ${FG_ACCENT}v${symfony_version}"
[[ -n "$cake_version" ]] \
  && add_seg "${FG_ACCENT}${IC_CAKE} ${FG_TEXT}CakePHP ${FG_ACCENT}v${cake_version}"
[[ -n "$slim_version" ]] \
  && add_seg "${FG_ACCENT}${IC_SLIM} ${FG_TEXT}Slim ${FG_ACCENT}v${slim_version}"

# ── Laravel runtime & tooling ─────────────────────────────────────────────────
[[ -n "$octane_version" ]] \
  && add_seg "${FG_ACCENT}${IC_OCTANE} ${FG_TEXT}Octane ${FG_ACCENT}v${octane_version}"

if [[ -n "$boost_version" ]]; then
  if [[ "$boost_json_exists" == "false" || "$boost_agents_ok" == "true" ]]; then
    add_seg "${FG_ACCENT}${IC_BOOST} ${FG_TEXT}Boost ${FG_ACCENT}v${boost_version}"
  else
    add_seg "${FG_ACCENT}${IC_BOOST} ${FG_WARN}Boost ${FG_WARN}v${boost_version} ${IC_WARN}"
  fi
fi

[[ -n "$reverb_version" ]] \
  && add_seg "${FG_ACCENT}${IC_REVERB} ${FG_TEXT}Reverb ${FG_ACCENT}v${reverb_version}"

# ── Livewire + Flux ───────────────────────────────────────────────────────────
[[ -n "$livewire_version" ]] \
  && add_seg "${FG_ACCENT}${IC_LIVEWIRE} ${FG_TEXT}Livewire ${FG_ACCENT}v${livewire_version}"

if [[ -n "$livewire_version" && -n "$flux_version" ]]; then
  local_pro=''
  [[ "$flux_pro" == "true" ]] && local_pro=" ${FG_ACCENT}${IC_PRO}"
  add_seg "${FG_ACCENT}${IC_FLUX} ${FG_TEXT}Flux ${FG_ACCENT}v${flux_version}${local_pro}"
fi

# ── Inertia ───────────────────────────────────────────────────────────────────
if [[ -n "$inertia_version" ]]; then
  local_framework=''
  [[ -n "$inertia_framework" ]] && local_framework=" ${FG_ACCENT}[${FG_TEXT}${inertia_framework}${FG_ACCENT}]"
  add_seg "${FG_ACCENT}${IC_INERTIA} ${FG_TEXT}Inertia ${FG_ACCENT}v${inertia_version}${local_framework}"
fi

# ── Admin panels ──────────────────────────────────────────────────────────────
[[ -n "$filament_version" ]] \
  && add_seg "${FG_ACCENT}${IC_FILAMENT} ${FG_TEXT}Filament ${FG_ACCENT}v${filament_version}"

# ── Testing (slot 5) ──────────────────────────────────────────────────────────
if [[ -n "$pest_version" ]]; then
  add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}Pest ${FG_ACCENT}v${pest_version}"
elif [[ -n "$phpunit_version" ]]; then
  add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}PHPUnit ${FG_ACCENT}v${phpunit_version}"
fi

# ── Static analysis (slot 6) ──────────────────────────────────────────────
if [[ -n "$phpstan_version" ]]; then
  if [[ "$phpstan_version" == 'present' ]]; then
    add_seg "${FG_ACCENT}${IC_PHPSTAN} ${FG_TEXT}PHPStan"
  else
    add_seg "${FG_ACCENT}${IC_PHPSTAN} ${FG_TEXT}PHPStan ${FG_ACCENT}v${phpstan_version}"
  fi
fi
if [[ -n "$csfixer_version" ]]; then
  if [[ "$csfixer_version" == 'present' ]]; then
    add_seg "${FG_ACCENT}${IC_CSFIXER} ${FG_TEXT}PHP CS Fixer"
  else
    add_seg "${FG_ACCENT}${IC_CSFIXER} ${FG_TEXT}PHP CS Fixer ${FG_ACCENT}v${csfixer_version}"
  fi
fi

# ── Herd local URL ────────────────────────────────────────────────────────────
if [[ -n "$herd_url" ]]; then
  herd_label="${FG_ACCENT}${IC_HERD} ${FG_TEXT}$(link "$herd_url" "${herd_site}.test")"
  add_seg "$herd_label"
fi

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
)
if [[ "$_bl_ttl" -gt 0 ]]; then
  bl_cache_write "$_bl_cache" "$_bl_out"
fi
printf '%s' "$_bl_out"
