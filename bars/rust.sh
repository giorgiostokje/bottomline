#!/usr/bin/env bash
# Bottomline bar: Rust ecosystem bar
# Only renders when the project contains a Cargo.toml.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

_bl_ttl="${BOTTOMLINE_BAR_REFRESH_MINUTES:-5}"
if [[ "$_bl_ttl" -gt 0 ]]; then
  _bl_cache=$(bl_cache_path "rust" "$_bl_ttl" "$PROJ" "$PROJ/Cargo.toml" "$PROJ/Cargo.lock")
  [[ -f "$_bl_cache" ]] && cat "$_bl_cache" && exit 0
fi

[[ ! -f "$PROJ/Cargo.toml" ]] && exit 0

# Returns the exact version of a package from Cargo.lock.
cargo_lock_version() {
  local pkg="$1"
  [[ ! -f "$PROJ/Cargo.lock" ]] && return
  awk -v p="$pkg" '
    /^\[\[package\]\]/ { name=""; ver="" }
    /^name = / { gsub(/"/, ""); name=substr($0, 9) }
    /^version = / { gsub(/"/, ""); ver=substr($0, 12) }
    name==p && ver!="" { print ver; exit }
  ' "$PROJ/Cargo.lock" 2>/dev/null
}

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#f0ddd8")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#d05a38")")
  _bar_gradient='["#1a0a04","#301508"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_RUST=$'\xee\x9a\x8b'      # U+E68B  nf-seti-rust
    IC_WORKSPACE=$'\xef\x81\xae' # U+F06E  nf-fa-eye
    IC_WEB=$'\xef\x83\xac'       # U+F0EC  nf-fa-exchange (web framework)
    IC_TEST=$'\xef\x81\x80'      # U+F040  nf-fa-pencil (test runner)
    IC_RUNTIME=$'\xef\x83\xa4'   # U+F0E4  nf-fa-tachometer (async runtime)
    IC_DB=$'\xef\x87\x80'        # U+F1C0  nf-fa-database (ORM)
    IC_LINT=$'\xef\x80\x8c'      # U+F00C  nf-fa-check (linter)
    ;;
  emoji)
    IC_RUST='🦀'
    IC_WORKSPACE='🗂'
    IC_WEB='🌐'
    IC_TEST='🧪'
    IC_RUNTIME='⚡'
    IC_DB='🗄'
    IC_LINT='✓'
    ;;
  *)
    IC_RUST='' IC_WORKSPACE='' IC_WEB='' IC_TEST='' IC_RUNTIME='' IC_DB='' IC_LINT=''
    ;;
esac


# ── Read Cargo.toml ───────────────────────────────────────────────────────────
edition=$(awk -F'"' '/^edition[[:space:]]*=/{print $2; exit}' "$PROJ/Cargo.toml" 2>/dev/null)
is_workspace=false
grep -q '^\[workspace\]' "$PROJ/Cargo.toml" && is_workspace=true


# ── Detect frameworks/libraries from Cargo.toml ───────────────────────────────
toml="$PROJ/Cargo.toml"
framework=''
framework_display=''
framework_version=''
for fw in actix-web axum rocket warp; do
  if grep -Eq "^${fw}[[:space:]]*=" "$toml" 2>/dev/null; then
    case "$fw" in
      actix-web) framework_display='Actix Web' ;;
      axum)      framework_display='axum'      ;;
      rocket)    framework_display='Rocket'    ;;
      warp)      framework_display='warp'      ;;
    esac
    framework="$fw"
    framework_version=$(cargo_lock_version "$fw")
    break
  fi
done

has_tokio=false
tokio_version=''
grep -Eq '^tokio[[:space:]]*=' "$toml" 2>/dev/null && has_tokio=true
$has_tokio && tokio_version=$(cargo_lock_version "tokio")

orm=''
orm_version=''
for o in sqlx diesel; do
  if grep -Eq "^${o}[[:space:]]*=" "$toml" 2>/dev/null; then
    orm="$o"; break
  fi
done
[[ -n "$orm" ]] && orm_version=$(cargo_lock_version "$orm")

# nextest: lockfile dep OR config OR binary
has_nextest=false
nextest_version=''
if [[ -f "$PROJ/Cargo.lock" ]] && grep -q '"cargo-nextest"' "$PROJ/Cargo.lock" 2>/dev/null; then
  has_nextest=true
elif [[ -f "$PROJ/.config/nextest.toml" ]]; then
  has_nextest=true
elif command -v cargo-nextest > /dev/null 2>&1; then
  has_nextest=true
fi
$has_nextest && nextest_version=$(cargo_lock_version "cargo-nextest")

# clippy: rust-toolchain.toml component OR binary
has_clippy=false
if [[ -f "$PROJ/rust-toolchain.toml" ]] && grep -q 'clippy' "$PROJ/rust-toolchain.toml" 2>/dev/null; then
  has_clippy=true
elif command -v cargo-clippy > /dev/null 2>&1; then
  has_clippy=true
fi

_bl_out=$(
  # ── Segments (canonical slot order) ───────────────────────────────────────────
  # Slot 1: Runtime
  rust_seg="${FG_ACCENT}${IC_RUST} ${FG_TEXT}Rust"
  [[ -n "$edition" ]] && rust_seg+=" ${FG_ACCENT}${edition}"
  $is_workspace && rust_seg+=" ${FG_ACCENT}${IC_WORKSPACE}${FG_TEXT} workspace"
  add_seg "$rust_seg"

  # Slot 3: Framework
  if [[ -n "$framework" ]]; then
    fw_seg="${FG_ACCENT}${IC_WEB} ${FG_TEXT}${framework_display}"
    [[ -n "$framework_version" ]] && fw_seg+=" ${FG_ACCENT}v${framework_version}"
    add_seg "$fw_seg"
  fi

  # Slot 5: Testing
  if $has_nextest; then
    nx_seg="${FG_ACCENT}${IC_TEST} ${FG_TEXT}nextest"
    [[ -n "$nextest_version" ]] && nx_seg+=" ${FG_ACCENT}v${nextest_version}"
    add_seg "$nx_seg"
  fi

  # Slot 6: Tooling
  $has_clippy \
    && add_seg "${FG_ACCENT}${IC_LINT} ${FG_TEXT}Clippy"
  if $has_tokio; then
    tokio_seg="${FG_ACCENT}${IC_RUNTIME} ${FG_TEXT}Tokio"
    [[ -n "$tokio_version" ]] && tokio_seg+=" ${FG_ACCENT}v${tokio_version}"
    add_seg "$tokio_seg"
  fi
  if [[ -n "$orm" ]]; then
    orm_seg="${FG_ACCENT}${IC_DB} ${FG_TEXT}${orm}"
    [[ -n "$orm_version" ]] && orm_seg+=" ${FG_ACCENT}v${orm_version}"
    add_seg "$orm_seg"
  fi

  (( ${#_sc[@]} == 0 )) && exit 0
  flush "$_bar_gradient"
)
if [[ "$_bl_ttl" -gt 0 ]]; then
  bl_cache_write "$_bl_cache" "$_bl_out"
fi
printf '%s' "$_bl_out"
