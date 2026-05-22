#!/usr/bin/env bash
# Bottomline bar: Rust ecosystem bar
# Only renders when the project contains a Cargo.toml.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" || ! -f "$PROJ/Cargo.toml" ]] && exit 0

# shellcheck source=lib/helpers.sh
source "$BOTTOMLINE_LIB/helpers.sh"

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
for fw in actix-web axum rocket warp; do
  if grep -Eq "^${fw}[[:space:]]*=" "$toml" 2>/dev/null; then
    framework="$fw"; break
  fi
done

has_tokio=false
grep -Eq '^tokio[[:space:]]*=' "$toml" 2>/dev/null && has_tokio=true

orm=''
for o in sqlx diesel; do
  if grep -Eq "^${o}[[:space:]]*=" "$toml" 2>/dev/null; then
    orm="$o"; break
  fi
done

# nextest: lockfile dep OR config OR binary
has_nextest=false
if [[ -f "$PROJ/Cargo.lock" ]] && grep -q '"cargo-nextest"' "$PROJ/Cargo.lock" 2>/dev/null; then
  has_nextest=true
elif [[ -f "$PROJ/.config/nextest.toml" ]]; then
  has_nextest=true
elif command -v cargo-nextest > /dev/null 2>&1; then
  has_nextest=true
fi

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
[[ -n "$framework" ]] \
  && add_seg "${FG_ACCENT}${IC_WEB} ${FG_TEXT}${framework}"

# Slot 5: Testing
$has_nextest \
  && add_seg "${FG_ACCENT}${IC_TEST} ${FG_TEXT}nextest"

# Slot 6: Tooling
$has_tokio \
  && add_seg "${FG_ACCENT}${IC_RUNTIME} ${FG_TEXT}tokio"
[[ -n "$orm" ]] \
  && add_seg "${FG_ACCENT}${IC_DB} ${FG_TEXT}${orm}"
$has_clippy \
  && add_seg "${FG_ACCENT}${IC_LINT} ${FG_TEXT}clippy"

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
