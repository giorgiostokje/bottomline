#!/usr/bin/env bash
# Bottomline bar: JavaScript / Node.js ecosystem bar
# Only renders when the project contains a package.json.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init javascript "#f5f0c8" "#f7df1e" '["#1c1a00","#2d2b00"]' \
  "$PROJ/package.json" "$PROJ/package-lock.json" \
  "$PROJ/pnpm-lock.yaml" "$PROJ/yarn.lock" \
  "$PROJ/bun.lockb" "$PROJ/bun.lock"

[[ ! -f "$PROJ/package.json" ]] && exit 0

bl_icon_set IC_REACT    $'\xee\x9e\xba' '⚛'   # U+E7BA  nf-dev-react
bl_icon_set IC_NEXT     $'\xee\x9f\x8a' '▲'   # U+E7CA  nf-dev-nextjs
bl_icon_set IC_RN       $'\xee\x9e\xba' '📱'  # U+E7BA  nf-dev-react  (React Native)
bl_icon_set IC_EXPO     $'\xef\x84\xb5' '📱'  # U+F135  nf-fa-rocket
bl_icon_set IC_VUE      $'\xee\x9e\xa8' '💚'  # U+E7A8  nf-dev-vuejs
bl_icon_set IC_NUXT     $'\xee\x9e\xa8' '💚'  # U+E7A8  nf-dev-vuejs  (no dedicated Nuxt glyph)
bl_icon_set IC_SVELTE   $'\xee\x9f\xab' '🧡'  # U+E7EB  nf-dev-svelte
bl_icon_set IC_SVELTEKIT $'\xee\x9f\xab' '🧡' # U+E7EB  nf-dev-svelte
bl_icon_set IC_VITE     $'\xef\x83\xa7' '⚡'  # U+F0E7  nf-fa-bolt
bl_icon_set IC_ANGULAR  $'\xee\x9d\x93' '🔴'  # U+E753  nf-dev-angularjs
bl_icon_set IC_ASTRO    $'\xef\x84\xb5' '🚀'  # U+F135  nf-fa-rocket
bl_icon_set IC_REMIX    $'\xef\x84\xa1' '♻'   # U+F121  nf-fa-code
bl_icon_set IC_ELECTRON $'\xee\x9d\x8a' '⚡'  # U+E74A  nf-dev-electron
bl_icon_set IC_TS       $'\xee\x98\xa8' '🔷'  # U+E628  nf-seti-typescript
bl_icon_set IC_NODE     $'\xee\x9c\x98' '🟢'  # U+E718  nf-seti-nodejs
bl_icon_set IC_PKG      $'\xef\x92\xae' '📦'  # U+F4AE  nf-mdi-package
bl_icon_set IC_TEST     $'\xef\x81\x80' '🧪'  # U+F040  nf-fa-pencil
bl_icon_set IC_CSS      $'\xee\x9d\x89' '🎨'  # U+E749  nf-dev-css3
bl_icon_set IC_LINT     $'\xef\x80\x8c' '✓'   # U+F00C  nf-fa-check
bl_icon_set IC_FMT      $'\xef\x80\xb1' '🖋'  # U+F031  nf-fa-font


# ── Node version (priority: .nvmrc → .node-version → engines.node) ────────────
node_version=''
if [[ -f "$PROJ/.nvmrc" ]]; then
  node_version=$(awk '/^[0-9]|^v[0-9]/{gsub(/^v/,""); print; exit}' "$PROJ/.nvmrc" 2>/dev/null)
elif [[ -f "$PROJ/.node-version" ]]; then
  node_version=$(awk '/^[0-9]|^v[0-9]/{gsub(/^v/,""); print; exit}' "$PROJ/.node-version" 2>/dev/null)
elif [[ -f "$PROJ/package.json" ]]; then
  node_version=$(jq -r '.engines.node // empty' "$PROJ/package.json" 2>/dev/null | sed 's/[^0-9.]//g')
fi

# ── Package manager (lockfile-driven) ─────────────────────────────────────────
pkg_mgr=''
if [[ -f "$PROJ/pnpm-lock.yaml" ]]; then
  pkg_mgr='pnpm'
elif [[ -f "$PROJ/yarn.lock" ]]; then
  pkg_mgr='yarn'
elif [[ -f "$PROJ/bun.lockb" || -f "$PROJ/bun.lock" ]]; then
  pkg_mgr='bun'
elif [[ -f "$PROJ/package-lock.json" ]]; then
  pkg_mgr='npm'
fi

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
has_jest=false has_vitest=false has_playwright=false has_cypress=false
has_tailwind=false has_eslint=false has_prettier=false has_biome=false

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
    jest)             has_jest=true      ;;
    vitest)           has_vitest=true    ;;
    '@playwright/test') has_playwright=true ;;
    cypress)          has_cypress=true   ;;
    tailwindcss)      has_tailwind=true  ;;
    eslint)           has_eslint=true    ;;
    prettier)         has_prettier=true  ;;
    '@biomejs/biome') has_biome=true     ;;
  esac
done < <(jq -r '((.dependencies // {}) + (.devDependencies // {})) | keys[]' "$pkg" 2>/dev/null)

# Config-file fallbacks
if ! $has_eslint; then [[ -f "$PROJ/.eslintrc" || -f "$PROJ/.eslintrc.js" || -f "$PROJ/.eslintrc.cjs" || -f "$PROJ/.eslintrc.json" || -f "$PROJ/eslint.config.js" || -f "$PROJ/eslint.config.mjs" ]] && has_eslint=true; fi
if ! $has_prettier; then [[ -f "$PROJ/.prettierrc" || -f "$PROJ/.prettierrc.json" || -f "$PROJ/.prettierrc.js" || -f "$PROJ/prettier.config.js" ]] && has_prettier=true; fi
if ! $has_biome; then [[ -f "$PROJ/biome.json" ]] && has_biome=true; fi

# Build a segment with icon, label, and optional version from node_modules.
js_seg() {
  local icon="$1" label="$2" pkg_name="$3"
  local version=''
  [[ -n "$pkg_name" ]] && version=$(npm_version "$pkg_name")
  bl_seg "$icon" "$label" "$version"
}

# Slot 1: Runtime
[[ -n "$node_version" ]] && bl_seg "$IC_NODE" Node "$node_version"

# Slot 2: Package manager
[[ -n "$pkg_mgr" ]] && bl_seg "$IC_PKG" "$pkg_mgr"

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

# Slot 5: Testing
$has_jest       && js_seg "$IC_TEST" "Jest" "jest"
$has_vitest     && js_seg "$IC_TEST" "Vitest" "vitest"
$has_playwright && js_seg "$IC_TEST" "Playwright" "@playwright/test"
$has_cypress    && js_seg "$IC_TEST" "Cypress" "cypress"

# Slot 6: Tooling
$has_eslint   && js_seg "$IC_LINT" "ESLint"       "eslint"
$has_prettier && js_seg "$IC_FMT"  "Prettier"     "prettier"
$has_biome    && js_seg "$IC_LINT" "Biome"        "@biomejs/biome"
$has_tailwind && js_seg "$IC_CSS"  "Tailwind CSS" "tailwindcss"

bl_bar_finish "$_bar_gradient"
