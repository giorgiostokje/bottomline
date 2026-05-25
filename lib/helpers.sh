#!/usr/bin/env bash
# Shared helpers sourced by every Bottomline bar script.
# Source at the top of your bar (after the shebang and guard):
#   source "$BOTTOMLINE_LIB/helpers.sh"

# ── ANSI primitives ───────────────────────────────────────────────────────────
bg3()     { printf '\e[48;2;%d;%d;%dm' "$1" "$2" "$3"; }
fg3()     { printf '\e[38;2;%d;%d;%dm' "$1" "$2" "$3"; }
make_fg() { local r g b; read -r r g b <<< "$1"; fg3 "$r" "$g" "$b"; }

hex_to_rgb() {
  local h="${1#'#'}"
  [[ ${#h} -ne 6 ]] && printf '128 128 128' && return
  printf '%d %d %d' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}

link() { printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$1" "$2"; }

# ── Background gradient interpolation ─────────────────────────────────────────
expand_bg() {
  local cfg="$1" n_out="${2:-8}"
  local bg_type
  bg_type=$(printf '%s' "$cfg" | jq -r 'type' 2>/dev/null)
  case "$bg_type" in
    string)
      local hex; hex=$(printf '%s' "$cfg" | jq -r '.')
      printf '%s' "$hex" | awk -v n="$n_out" '{
        h=$0; printf "[";
        for(i=0;i<n;i++){if(i)printf ","; printf "\"" h "\""}
        printf "]"
      }'
      ;;
    array)
      printf '%s' "$cfg" | jq -r '.[]' | awk -v n_out="$n_out" '
        function h2d(h,   i,c,v) {
          v = 0
          for (i = 1; i <= length(h); i++) {
            c = substr(h, i, 1)
            if      (c ~ /[0-9]/) v = v*16 + c+0
            else if (c ~ /[a-f]/) v = v*16 + index("abcdef",c)+9
            else if (c ~ /[A-F]/) v = v*16 + index("ABCDEF",c)+9
          }
          return v
        }
        { colors[NR-1] = $0 }
        END {
          k = NR
          if (k == 0) {
            printf "["; for(i=0;i<n_out;i++){if(i)printf ","; printf "\"#0F0F0F\""}; printf "]"; exit
          }
          if (k == 1) {
            printf "["; for(i=0;i<n_out;i++){if(i)printf ","; printf "\"" colors[0] "\""} ; printf "]"; exit
          }
          printf "["
          for (i = 0; i < n_out; i++) {
            if (i) printf ","
            t   = (n_out > 1) ? i / (n_out - 1.0) : 0
            pos = t * (k - 1); seg = int(pos); if (seg >= k-1) seg = k-2; frac = pos - seg
            c1 = substr(colors[seg], 2); c2 = substr(colors[seg+1], 2)
            r = int(h2d(substr(c1,1,2)) + (h2d(substr(c2,1,2))-h2d(substr(c1,1,2)))*frac+0.5)
            g = int(h2d(substr(c1,3,2)) + (h2d(substr(c2,3,2))-h2d(substr(c1,3,2)))*frac+0.5)
            b = int(h2d(substr(c1,5,2)) + (h2d(substr(c2,5,2))-h2d(substr(c1,5,2)))*frac+0.5)
            printf "\"#%02X%02X%02X\"", r, g, b
          }
          printf "]"
        }
      '
      ;;
    *) printf '["#0F0F0F"]' ;;
  esac
}

# ── Segment engine ─────────────────────────────────────────────────────────────
declare -a _sc
seg()     { _sc+=("$1"); }
add_seg() { seg "$1"; }

flush() {
  local gradient_json="$1"
  local n=${#_sc[@]}
  (( n == 0 )) && return
  local expanded i hex
  expanded=$(expand_bg "$gradient_json" "$n")
  declare -a fr fg fb
  for ((i=0; i<n; i++)); do
    hex=$(printf '%s' "$expanded" | jq -r ".[$i]" 2>/dev/null)
    [[ -z "$hex" ]] && hex='#0F0F0F'
    read -r fr[$i] fg[$i] fb[$i] <<< "$(hex_to_rgb "$hex")"
  done
  for ((i=0; i<n; i++)); do
    local r=${fr[$i]} g=${fg[$i]} b=${fb[$i]}
    printf '%s' "$(bg3 "$r" "$g" "$b") ${B}${_sc[$i]}$(bg3 "$r" "$g" "$b") "
    if (( i + 1 < n )); then
      printf '%s' "$(fg3 "$r" "$g" "$b")$(bg3 "${fr[$((i+1))]}" "${fg[$((i+1))]}" "${fb[$((i+1))]}")${SEP}"
    else
      printf '%s' "${R}$(fg3 "$r" "$g" "$b")${SEP}${R}"
    fi
  done
}

# ── Cache helpers ─────────────────────────────────────────────────────────────

# Compute the cache file path for a bar.
# Usage: bl_cache_path <bar_name> <ttl_mins> <discriminator> [file1 file2 ...]
# <discriminator> is any opaque string that uniquely identifies this bar instance
# (e.g. a project dir path, or a "team:api_key" compound key). It is MD5-hashed
# and never appears in the filename.
# Trailing file paths are hashed by mtime; a changed or created/deleted file
# produces a different path (cache miss) even within the same TTL bucket.
# BOTTOMLINE_CACHE_DIR overrides the cache directory (default: /tmp).
bl_cache_path() {
  local name="$1" ttl="${2:-5}" proj="$3"
  shift 3
  local bucket projhash fingerprint cache_dir
  cache_dir="${BOTTOMLINE_CACHE_DIR:-/tmp}"
  bucket=$(( $(date +%s) / (ttl * 60) ))
  projhash=$(printf '%s' "$proj" | (md5sum 2>/dev/null || md5) | cut -c1-8)
  fingerprint=$(bl_mtime_fingerprint "$@")
  printf '%s/bl_%s_%s_%s_%s.txt' "$cache_dir" "$name" "$projhash" "$fingerprint" "$bucket"
}

# Write rendered output to cache and clean up stale entries for this bar+project.
# Usage: bl_cache_write <cache_file> <output>
# No-ops when output is empty so bars that produce nothing don't cache a blank.
bl_cache_write() {
  local cache_file="$1" output="$2"
  if [[ -z "$output" ]]; then return; fi
  # Use bash noclobber (set -C) so the redirect uses O_CREAT|O_EXCL — the kernel
  # guarantees only one concurrent render creates the file, preventing multiple
  # renders from each fetching fresh data and displaying different results.
  # Language-bar output is deterministic, so losers can safely display their own
  # computed output without re-reading; only the winner runs cleanup.
  local stem; stem="${cache_file%_*_*.txt}"
  local cache_dir; cache_dir=$(dirname "$cache_file")
  if (set -C; printf '%s' "$output" > "$cache_file") 2>/dev/null; then
    find -L "$cache_dir" -maxdepth 1 -name "${stem##*/}_*_*.txt" \
      ! -name "$(basename "$cache_file")" -print0 2>/dev/null | xargs -0 rm -f 2>/dev/null
  fi
}

# Compute an 8-char hex fingerprint from the mtimes of the given files.
# Missing or non-file paths contribute "0" so their creation triggers a miss.
# Usage: bl_mtime_fingerprint [file1 file2 ...]
bl_mtime_fingerprint() {
  local mtimes=''
  for f in "$@"; do
    if [[ -f "$f" ]]; then
      # Try GNU stat first (-c '%Y'), then BSD/macOS stat (-f '%m').
      # Order matters: GNU stat accepts -f but interprets it as "filesystem status",
      # causing -f '%m' to print the mount point (not mtime) and exit 0, which
      # would make the BSD branch unreachable on Linux.
      mtimes+=$(stat -c '%Y' "$f" 2>/dev/null || stat -f '%m' "$f" 2>/dev/null || printf '0')
      mtimes+=$'\n'
    else
      mtimes+=$'0\n'
    fi
  done
  printf '%s' "$mtimes" | (md5sum 2>/dev/null || md5) | cut -c1-8
}

# ── Convenience variables from BOTTOMLINE_* env vars ─────────────────────────
R="$BOTTOMLINE_RESET"
B="$BOTTOMLINE_BOLD"
SEP="$BOTTOMLINE_SEP"
# shellcheck disable=SC2034  # used by scripts that source this file
FG_TEXT=$(make_fg   "$(hex_to_rgb "$BOTTOMLINE_TEXT_HEX")")
# shellcheck disable=SC2034
FG_ACCENT=$(make_fg "$(hex_to_rgb "$BOTTOMLINE_ACCENT_HEX")")
# shellcheck disable=SC2034
FG_WARN=$(make_fg   "$(hex_to_rgb "${BOTTOMLINE_WARN_HEX:-#f4a261}")")
# shellcheck disable=SC2034
FG_CRIT=$(make_fg   "$(hex_to_rgb "${BOTTOMLINE_DANGER_HEX:-#e05a4e}")")
