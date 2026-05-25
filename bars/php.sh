#!/usr/bin/env bash
# Bottomline bar: PHP ecosystem bar
# Renders for any project containing a composer.json.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init php "#ddd6f3" "#9898e0" '["#0d0b1e","#1c1850"]' \
  "$PROJ/composer.json" "$PROJ/composer.lock"

[[ ! -f "$PROJ/composer.json" ]] && exit 0

bl_icon_set IC_PHP      $'\xee\x9d\xa5' '🐘'  # U+E765  nf-dev-php
bl_icon_set IC_LARAVEL  $'\xee\x9c\xbf' '🔥'  # U+E73F  nf-dev-laravel
bl_icon_set IC_LUMEN    $'\xee\x9c\xbf' '🔦'  # U+E73F  nf-dev-laravel  (Lumen = Laravel family)
bl_icon_set IC_SYMFONY  $'\xee\x9d\x97' '🎵'  # U+E757  nf-dev-symfony
bl_icon_set IC_CAKE     $'\xef\x87\xbd' '🎂'  # U+F1FD  nf-fa-birthday-cake
bl_icon_set IC_SLIM     $'\xef\x81\xac' '🪶'  # U+F06C  nf-fa-leaf
bl_icon_set IC_OCTANE   $'\xef\x83\xa4' '🏎'  # U+F0E4  nf-fa-tachometer
bl_icon_set IC_BOOST    $'\xef\x83\xa7' '⚡'  # U+F0E7  nf-fa-bolt
bl_icon_set IC_REVERB   $'\xef\x87\xab' '📡'  # U+F1EB  nf-fa-wifi
bl_icon_set IC_LIVEWIRE $'\xef\x81\x83' '🌊'  # U+F043  nf-fa-tint
bl_icon_set IC_FLUX     $'\xef\x84\xa1' '✨'  # U+F121  nf-fa-code
bl_icon_set IC_INERTIA  $'\xef\x84\xa4' '🚀'  # U+F124  nf-fa-location-arrow
bl_icon_set IC_FILAMENT $'\xef\x80\x85' '⭐'  # U+F005  nf-fa-star
bl_icon_set IC_HERD     $'\xef\x82\xac' '🌐'  # U+F0AC  nf-fa-globe
bl_icon_set IC_TEST     $'\xef\x81\x80' '🧪'  # U+F040  nf-fa-pencil
bl_icon_set IC_PHPSTAN  $'\xef\x80\x8c' '🔍'  # U+F00C  nf-fa-check
bl_icon_set IC_CSFIXER  $'\xef\x80\xb1' '🔧'  # U+F031  nf-fa-font
bl_icon_set IC_PRO      $'\xef\x82\x91' '🏅'  # U+F091  nf-fa-trophy
bl_icon_set IC_WARN     $'\xef\x81\xb1' '⚠'   # U+F071  nf-fa-warning

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
larastan_version=''
phpstan_version=''
pint_version=''
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
      nunomaduro/larastan|larastan/larastan) larastan_version="${version#v}" ;;
      phpstan/phpstan)           phpstan_version="${version#v}"  ;;
      laravel/pint)              pint_version="${version#v}"     ;;
      friendsofphp/php-cs-fixer) csfixer_version="${version#v}"  ;;
    esac
  done < <(jq -r '(.packages + (.["packages-dev"] // [])) | .[] | [.name, .version] | @tsv' "$lock" 2>/dev/null)
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
[[ -n "$php_version" ]] \
  && add_seg "${FG_ACCENT}${IC_PHP} ${FG_TEXT}PHP ${FG_ACCENT}${php_version}"

# ── Framework ─────────────────────────────────────────────────────────────────
[[ -n "$laravel_version" ]] \
  && bl_version_seg "$IC_LARAVEL" Laravel "$laravel_version"
[[ -n "$lumen_version" ]] \
  && bl_version_seg "$IC_LUMEN" Lumen "$lumen_version"
[[ -n "$symfony_version" ]] \
  && bl_version_seg "$IC_SYMFONY" Symfony "$symfony_version"
[[ -n "$cake_version" ]] \
  && bl_version_seg "$IC_CAKE" CakePHP "$cake_version"
[[ -n "$slim_version" ]] \
  && bl_version_seg "$IC_SLIM" Slim "$slim_version"

# ── Laravel runtime & tooling ─────────────────────────────────────────────────
[[ -n "$octane_version" ]] \
  && bl_version_seg "$IC_OCTANE" Octane "$octane_version"

if [[ -n "$boost_version" ]]; then
  if [[ "$boost_json_exists" == "false" || "$boost_agents_ok" == "true" ]]; then
    add_seg "${FG_ACCENT}${IC_BOOST} ${FG_TEXT}Boost ${N}${FG_ACCENT}v${boost_version}"
  else
    add_seg "${FG_ACCENT}${IC_BOOST} ${FG_WARN}Boost ${FG_WARN}v${boost_version} ${IC_WARN}"
  fi
fi

[[ -n "$reverb_version" ]] \
  && bl_version_seg "$IC_REVERB" Reverb "$reverb_version"

# ── Livewire + Flux ───────────────────────────────────────────────────────────
[[ -n "$livewire_version" ]] \
  && bl_version_seg "$IC_LIVEWIRE" Livewire "$livewire_version"

if [[ -n "$livewire_version" && -n "$flux_version" ]]; then
  local_pro=''
  [[ "$flux_pro" == "true" ]] && local_pro=" ${FG_ACCENT}${IC_PRO}"
  add_seg "${FG_ACCENT}${IC_FLUX} ${FG_TEXT}Flux ${N}${FG_ACCENT}v${flux_version}${local_pro}"
fi

# ── Inertia ───────────────────────────────────────────────────────────────────
[[ -n "$inertia_version" ]] \
  && bl_version_seg "$IC_INERTIA" Inertia "$inertia_version"

# ── Admin panels ──────────────────────────────────────────────────────────────
[[ -n "$filament_version" ]] \
  && bl_version_seg "$IC_FILAMENT" Filament "$filament_version"

# ── Testing (slot 5) ──────────────────────────────────────────────────────────
if [[ -n "$pest_version" ]]; then
  bl_version_seg "$IC_TEST" Pest "$pest_version"
elif [[ -n "$phpunit_version" ]]; then
  bl_version_seg "$IC_TEST" PHPUnit "$phpunit_version"
fi

# ── Static analysis (slot 6) ──────────────────────────────────────────────
# Larastan wraps PHPStan for Laravel — show Larastan only when present.
if [[ -n "$larastan_version" ]]; then
  bl_version_seg "$IC_PHPSTAN" Larastan "$larastan_version"
elif [[ -n "$phpstan_version" ]]; then
  if [[ "$phpstan_version" == 'present' ]]; then
    add_seg "${FG_ACCENT}${IC_PHPSTAN} ${FG_TEXT}PHPStan"
  else
    bl_version_seg "$IC_PHPSTAN" PHPStan "$phpstan_version"
  fi
fi
# Pint wraps PHP-CS-Fixer for Laravel — show Pint only when present.
if [[ -n "$pint_version" ]]; then
  bl_version_seg "$IC_CSFIXER" Pint "$pint_version"
elif [[ -n "$csfixer_version" ]]; then
  if [[ "$csfixer_version" == 'present' ]]; then
    add_seg "${FG_ACCENT}${IC_CSFIXER} ${FG_TEXT}PHP CS Fixer"
  else
    bl_version_seg "$IC_CSFIXER" "PHP CS Fixer" "$csfixer_version"
  fi
fi

# ── Herd local URL ────────────────────────────────────────────────────────────
if [[ -n "$herd_url" ]]; then
  herd_label="${FG_ACCENT}${IC_HERD} ${FG_TEXT}$(link "$herd_url" "${herd_site}.test")"
  add_seg "$herd_label"
fi

bl_bar_finish "$_bar_gradient"
