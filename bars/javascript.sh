#!/usr/bin/env bash
# Bottomline bar: JavaScript / Node.js ecosystem bar
# Only renders when the project contains a package.json.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" || ! -f "$PROJ/package.json" ]] && exit 0

source "$BOTTOMLINE_LIB/helpers.sh"

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#f5f0c8")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#f7df1e")")
  _bar_gradient='["#1c1a00","#2d2b00"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_REACT=$'\xee\x9e\xba'      # U+E7BA  nf-dev-react
    IC_NEXT=$'\xee\x9f\x8a'       # U+E7CA  nf-dev-nextjs
    IC_RN=$'\xee\x9e\xba'         # U+E7BA  nf-dev-react  (React Native)
    IC_EXPO=$'\xef\x84\xb5'       # U+F135  nf-fa-rocket
    IC_VUE=$'\xee\x9e\xa8'        # U+E7A8  nf-dev-vuejs
    IC_NUXT=$'\xee\x9e\xa8'       # U+E7A8  nf-dev-vuejs  (no dedicated Nuxt glyph)
    IC_SVELTE=$'\xee\x9f\xab'     # U+E7EB  nf-dev-svelte
    IC_SVELTEKIT=$'\xee\x9f\xab'  # U+E7EB  nf-dev-svelte
    IC_VITE=$'\xef\x83\xa7'       # U+F0E7  nf-fa-bolt
    IC_ANGULAR=$'\xee\x9d\x93'    # U+E753  nf-dev-angularjs
    IC_ASTRO=$'\xef\x84\xb5'      # U+F135  nf-fa-rocket
    IC_REMIX=$'\xef\x84\xa1'      # U+F121  nf-fa-code
    IC_ELECTRON=$'\xee\x9d\x8a'   # U+E74A  nf-dev-electron
    IC_TS=$'\xee\x98\xa8'         # U+E628  nf-seti-typescript
    ;;
  emoji)
    IC_REACT='⚛'
    IC_NEXT='▲'
    IC_RN='📱'
    IC_EXPO='📱'
    IC_VUE='💚'
    IC_NUXT='💚'
    IC_SVELTE='🧡'
    IC_SVELTEKIT='🧡'
    IC_VITE='⚡'
    IC_ANGULAR='🔴'
    IC_ASTRO='🚀'
    IC_REMIX='♻'
    IC_ELECTRON='⚡'
    IC_TS='🔷'
    ;;
  *)
    IC_REACT='' IC_NEXT='' IC_RN='' IC_EXPO='' IC_VUE='' IC_NUXT=''
    IC_SVELTE='' IC_SVELTEKIT='' IC_VITE='' IC_ANGULAR='' IC_ASTRO=''
    IC_REMIX='' IC_ELECTRON='' IC_TS=''
    ;;
esac


# Returns the installed version from node_modules, or empty if not found.
npm_version() {
  local vf="$PROJ/node_modules/${1}/package.json"
  [[ -f "$vf" ]] && jq -r '.version // empty' "$vf" 2>/dev/null || printf ''
}

# Parse package.json once — collect all dependency keys in a single jq pass.
pkg="$PROJ/package.json"
has_react=false   has_next=false    has_rn=false      has_expo=false
has_vue=false     has_nuxt=false
has_svelte=false  has_sveltekit=false
has_vite=false    has_angular=false
has_ts=false      has_astro=false
has_remix=false   has_electron=false

while IFS= read -r dep; do
  case "$dep" in
    react)            has_react=true     ;;
    next)             has_next=true      ;;
    react-native)     has_rn=true        ;;
    expo)             has_expo=true      ;;
    vue)              has_vue=true       ;;
    nuxt)             has_nuxt=true      ;;
    svelte)           has_svelte=true    ;;
    @sveltejs/kit)    has_sveltekit=true ;;
    vite)             has_vite=true      ;;
    @angular/core)    has_angular=true   ;;
    typescript)       has_ts=true        ;;
    astro)            has_astro=true     ;;
    @remix-run/react) has_remix=true     ;;
    @remix-run/node)  has_remix=true     ;;
    electron)         has_electron=true  ;;
  esac
done < <(jq -r '((.dependencies // {}) + (.devDependencies // {})) | keys[]' "$pkg" 2>/dev/null)

# Build a segment with icon, label, and optional version from node_modules.
js_seg() {
  local icon="$1" label="$2" pkg_name="$3"
  local vsuf=''
  if [[ -n "$pkg_name" ]]; then
    local version; version=$(npm_version "$pkg_name")
    [[ -n "$version" ]] && vsuf=" ${FG_ACCENT}v${version}"
  fi
  seg "${FG_ACCENT}${icon} ${FG_TEXT}${label}${vsuf}"
}

# ── React ecosystem ───────────────────────────────────────────────────────────
$has_next  && js_seg "$IC_NEXT"  "Next.js" "next"
( $has_react && ! $has_next && ! $has_remix ) && js_seg "$IC_REACT" "React" "react"
$has_remix && js_seg "$IC_REMIX" "Remix" "@remix-run/react"

# ── Mobile ────────────────────────────────────────────────────────────────────
$has_expo && js_seg "$IC_EXPO" "Expo" "expo"
( $has_rn && ! $has_expo ) && js_seg "$IC_RN" "React Native" "react-native"

# ── Vue ecosystem ─────────────────────────────────────────────────────────────
$has_nuxt && js_seg "$IC_NUXT" "Nuxt" "nuxt"
( $has_vue && ! $has_nuxt ) && js_seg "$IC_VUE" "Vue" "vue"

# ── Svelte ecosystem ──────────────────────────────────────────────────────────
$has_sveltekit && js_seg "$IC_SVELTEKIT" "SvelteKit" "@sveltejs/kit"
( $has_svelte && ! $has_sveltekit ) && js_seg "$IC_SVELTE" "Svelte" "svelte"

# ── Other frameworks ──────────────────────────────────────────────────────────
$has_angular  && js_seg "$IC_ANGULAR"  "Angular"  "@angular/core"
$has_astro    && js_seg "$IC_ASTRO"    "Astro"    "astro"
$has_electron && js_seg "$IC_ELECTRON" "Electron" "electron"

# Vite — suppress when implied by Vite-native meta-frameworks.
( $has_vite && ! $has_nuxt && ! $has_sveltekit && ! $has_astro ) \
  && js_seg "$IC_VITE" "Vite" "vite"

# ── Language ──────────────────────────────────────────────────────────────────
$has_ts && js_seg "$IC_TS" "TypeScript" "typescript"

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
