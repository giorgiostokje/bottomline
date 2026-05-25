#!/usr/bin/env bash
# lib/ansi.sh — pure ANSI/RGB/segment primitives. No env-var reads. Mutates: _sc array.
#
# Functions: bg3, fg3, make_fg, hex_to_rgb, link, expand_bg, seg, flush, add_seg
# Global state: declare -a _sc (accumulator for seg/flush)
# flush reads: R, B, SEP (must be set by caller)

bg3() { printf '\e[48;2;%d;%d;%dm' "$1" "$2" "$3"; }
fg3() { printf '\e[38;2;%d;%d;%dm' "$1" "$2" "$3"; }

hex_to_rgb() {
  local h="${1#'#'}"
  [[ ${#h} -ne 6 ]] && printf '128 128 128' && return
  printf '%d %d %d' "$((16#${h:0:2}))" "$((16#${h:2:2}))" "$((16#${h:4:2}))"
}

make_fg() { local r g b; read -r r g b <<< "$1"; fg3 "$r" "$g" "$b"; }

link() { printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$1" "$2"; }

expand_bg() {
  local cfg="$1" n_out="${2:-8}"
  local bg_type
  bg_type=$(printf '%s' "$cfg" | jq -r 'type' 2>/dev/null)

  case "$bg_type" in
    string)
      local hex; hex=$(printf '%s' "$cfg" | jq -r '.')
      printf '%s' "$hex" | awk -v n="$n_out" '{ h=$0; printf "["; for(i=0;i<n;i++){if(i)printf ","; printf "\"" h "\""} printf "]" }'
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
          if (k == 0) { printf "["; for(i=0;i<n_out;i++){if(i)printf ","; printf "\"#0F0F0F\""}; printf "]"; exit }
          if (k == 1) { printf "["; for(i=0;i<n_out;i++){if(i)printf ","; printf "\"" colors[0] "\""} ; printf "]"; exit }
          printf "["
          for (i = 0; i < n_out; i++) {
            if (i) printf ","
            t   = (n_out > 1) ? i / (n_out - 1.0) : 0
            pos = t * (k - 1)
            seg = int(pos); if (seg >= k-1) seg = k-2
            frac = pos - seg
            c1 = substr(colors[seg],   2)
            c2 = substr(colors[seg+1], 2)
            r = int(h2d(substr(c1,1,2)) + (h2d(substr(c2,1,2)) - h2d(substr(c1,1,2))) * frac + 0.5)
            g = int(h2d(substr(c1,3,2)) + (h2d(substr(c2,3,2)) - h2d(substr(c1,3,2))) * frac + 0.5)
            b = int(h2d(substr(c1,5,2)) + (h2d(substr(c2,5,2)) - h2d(substr(c1,5,2))) * frac + 0.5)
            printf "\"#%02X%02X%02X\"", r, g, b
          }
          printf "]"
        }
      '
      ;;
    *)
      awk -v n_out="$n_out" 'BEGIN { printf "["; for(i=0;i<n_out;i++){if(i)printf ","; printf "\"#0F0F0F\""} printf "]" }'
      ;;
  esac
}

declare -a _sc
seg()     { _sc+=("$1"); }
add_seg() { seg "$1"; }

flush() {
  local gradient_json="$1"
  local n=${#_sc[@]}
  (( n == 0 )) && return
  local expanded i hex r g b
  expanded=$(expand_bg "$gradient_json" "$n")
  declare -a fr fg fb
  for ((i=0; i<n; i++)); do
    hex=$(printf '%s' "$expanded" | jq -r ".[$i]" 2>/dev/null)
    [[ -z "$hex" ]] && hex='#0F0F0F'
    read -r fr[$i] fg[$i] fb[$i] <<< "$(hex_to_rgb "$hex")"
  done
  for ((i=0; i<n; i++)); do
    r=${fr[$i]} g=${fg[$i]} b=${fb[$i]}
    printf '%s' "$(bg3 "$r" "$g" "$b") ${B}${_sc[$i]}$(bg3 "$r" "$g" "$b") "
    if (( i + 1 < n )); then
      printf '%s' "$(fg3 "$r" "$g" "$b")$(bg3 "${fr[$((i+1))]}" "${fg[$((i+1))]}" "${fb[$((i+1))]}")${SEP}"
    else
      printf '%s' "${R}$(fg3 "$r" "$g" "$b")${SEP}${R}"
    fi
  done
}
