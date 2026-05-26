#!/usr/bin/env bash
# Bottomline bar: Rust ecosystem bar
# Only renders when the project contains a Cargo.toml.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

bl_bar_init rust "#f0ddd8" "#d05a38" '["#1a0a04","#301508"]' "$PROJ/Cargo.toml" "$PROJ/Cargo.lock"

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

bl_icon_set IC_RUST      $'\xee\x9a\x8b' '🦀'  # U+E68B  nf-seti-rust
bl_icon_set IC_WORKSPACE $'\xef\x81\xae' '🗂'  # U+F06E  nf-fa-eye
bl_icon_set IC_WEB       $'\xef\x83\xac' '🌐'  # U+F0EC  nf-fa-exchange (web framework)
bl_icon_set IC_TEST      $'\xef\x81\x80' '🧪'  # U+F040  nf-fa-pencil (test runner)
bl_icon_set IC_RUNTIME   $'\xef\x83\xa4' '⚡'  # U+F0E4  nf-fa-tachometer (async runtime)
bl_icon_set IC_DB        $'\xef\x87\x80' '🗄'  # U+F1C0  nf-fa-database (ORM)
bl_icon_set IC_LINT      $'\xef\x80\x8c' '✓'   # U+F00C  nf-fa-check (linter)
bl_icon_set IC_CLI       $'\xef\x84\xa1' '⌨'    # U+F121  nf-fa-terminal (CLI framework)
bl_icon_set IC_PROTO     $'\xef\x80\xa2' '📡'   # U+F022  nf-fa-broadcast (gRPC)


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

has_tonic=false
tonic_version=''
grep -Eq '^tonic[[:space:]]*=' "$toml" 2>/dev/null && has_tonic=true
$has_tonic && tonic_version=$(cargo_lock_version "tonic")

has_clap=false
clap_version=''
grep -Eq '^clap[[:space:]]*=' "$toml" 2>/dev/null && has_clap=true
$has_clap && clap_version=$(cargo_lock_version "clap")

has_sqlx=false
sqlx_version=''
grep -Eq '^sqlx[[:space:]]*=' "$toml" 2>/dev/null && has_sqlx=true
$has_sqlx && sqlx_version=$(cargo_lock_version "sqlx")

has_diesel=false
diesel_version=''
grep -Eq '^diesel[[:space:]]*=' "$toml" 2>/dev/null && has_diesel=true
$has_diesel && diesel_version=$(cargo_lock_version "diesel")

has_seaorm=false
seaorm_version=''
grep -Eq '^sea-orm[[:space:]]*=' "$toml" 2>/dev/null && has_seaorm=true
$has_seaorm && seaorm_version=$(cargo_lock_version "sea-orm")

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

# ── Segments (canonical slot order) ───────────────────────────────────────────
# Slot 1: Runtime
rust_seg="${FG_ACCENT}${IC_RUST} ${FG_TEXT}Rust"
[[ -n "$edition" ]] && rust_seg+=" ${FG_ACCENT}${edition}"
$is_workspace && rust_seg+=" ${FG_ACCENT}${IC_WORKSPACE}${FG_TEXT} workspace"
add_seg "$rust_seg"

# Slot 3: Framework
[[ -n "$framework" ]] && bl_version_seg "$IC_WEB" "$framework_display" "$framework_version"
$has_clap && bl_version_seg "$IC_CLI" Clap "$clap_version"

# Slot 4: Add-ons
$has_tokio && bl_version_seg "$IC_RUNTIME" Tokio "$tokio_version"
$has_tonic && bl_version_seg "$IC_PROTO" Tonic "$tonic_version"

# Slot 5: Testing
$has_nextest && bl_version_seg "$IC_TEST" nextest "$nextest_version"

# Slot 6: Tooling
$has_clippy && bl_version_seg "$IC_LINT" Clippy ""
$has_sqlx && bl_version_seg "$IC_DB" sqlx "$sqlx_version"
$has_diesel && bl_version_seg "$IC_DB" diesel "$diesel_version"
$has_seaorm && bl_version_seg "$IC_DB" SeaORM "$seaorm_version"

bl_bar_finish "$_bar_gradient"
