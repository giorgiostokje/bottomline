#!/usr/bin/env bash
# lib/usage.sh — session token totals from the transcript, read incrementally.
#
# Transcripts only grow, so each file's byte offset and running totals are
# cached; a refresh parses only the lines appended since the previous one.
# Totals span the main transcript and its subagent transcripts
# (<session>.jsonl → <session>/subagents/*.jsonl). Nothing is read unless an
# active segment needs the numbers.
#
# Inputs : transcript, ctx_from_payload, total_cost (set by lib/state.sh),
#          ACTIVE_SEGS via _bl_seg_active (lib/segments.sh),
#          BOTTOMLINE_CACHE_DIR (env, optional; defaults to /tmp)
# Outputs: sum_in, sum_out, sum_cache_read, sum_cache_create, web_searches,
#          ctx_used (only when the payload lacks context_window.total_input_tokens)
# Exports: bl_read_usage (public entry)

# shellcheck disable=SC2034  # output vars consumed by lib/segments.sh
# shellcheck disable=SC2154  # vars set by lib/state.sh

# Folds transcript lines into per-file state. Each file arrives as a header line
# (\x1e + its current size + " " + {p, k, o, st} JSON), followed by bytes o..size
# plus a "\n" from bash, or by nothing when the file is unchanged. A chunk that
# ended with a newline therefore shows up with an empty final line; a
# non-empty final line may still be being written and only counts once it
# parses. Every other line is complete.
#
# Offsets come from the size bash measured, never from summing line lengths:
# jq -R turns invalid UTF-8 into U+FFFD, which would skew a byte count. Only an
# unfinished final line is measured in jq, and the skew there can only move the
# next read earlier, onto a line fragment that fails to parse and is skipped.
#
# st.t — [input, output, cache_read, cache_write, web_searches] totals
# st.r — [message.id, usage] of the last 32 messages. Claude Code repeats a
#        message's usage on every content-block line, the last one final, so a
#        repeated id replaces its earlier usage instead of adding to it.
# st.c — context tokens (input + cache read + cache write) of the file's
#        latest assistant message
#
# Output: one tab-separated line "ctx in out cache_read cache_write searches",
# then one cache line per file: path \x1f dev:inode \x1f offset \x1f JSON.
# shellcheck disable=SC2016  # a jq program, not shell expansions
_BL_USAGE_JQ='
  def u5: [(.input_tokens // 0), (.output_tokens // 0),
           (.cache_read_input_tokens // 0), (.cache_creation_input_tokens // 0),
           (.server_tool_use.web_search_requests // 0)];
  def add5($a; $b): [range(5) as $i | $a[$i] + $b[$i]];
  def sub5($a; $b): [range(5) as $i | $a[$i] - $b[$i]];
  def apply($j):
    if ($j | type) == "object" and $j.type == "assistant" and $j.message.usage != null then
      ($j.message.usage | u5) as $u | $j.message.id as $id
      | .st.c = ($u[0] + $u[2] + $u[3])
      | if $id == null then .st.t = add5(.st.t; $u)
        else ([.st.r[][0]] | index($id)) as $x
          | if $x == null then .st.t = add5(.st.t; $u) | .st.r = (.st.r + [[$id, $u]])[-32:]
            else .st.t = add5(sub5(.st.t; .st.r[$x][1]); $u) | .st.r[$x][1] = $u
            end
        end
    else . end;
  def mid($l):
    if $l | contains("\"usage\"") then apply(try ($l | fromjson) catch null) else . end;
  def last($l):
    if $l == "" then .o = .s
    else (try ($l | fromjson) catch null) as $j
      | if $j == null then .o = ([.s - ($l | utf8bytelength), .o] | max)
        else apply($j) | .o = .s end
    end;
  def fin: if has("h") then last(.h) | del(.h) else . end;
  def cur(f): if (.f | length) > 0 then .f[(.f | length) - 1] |= f else . end;
  reduce inputs as $l ({f: []};
    if $l | startswith("\u001e") then
      ($l[1:] | index(" ")) as $i
      | cur(fin)
      | .f += [$l[$i + 2:] | fromjson | .s = ($l[1:$i + 1] | tonumber)
               | .st //= {t: [0,0,0,0,0], r: [], c: 0}]
    else
      cur(if has("h") then mid(.h) else . end | .h = $l)
    end)
  | cur(fin) | .f as $f
  | (reduce $f[].st.t as $t ([0,0,0,0,0]; add5(.; $t))) as $tot
  | ([$f[0].st.c // 0] + $tot | map(floor | tostring) | join("\t")),
    ($f[] | "\(.p)\u001f\(.k)\u001f\(.o)\u001f\(del(.s) | tojson)")
'

_bl_usage_needed() {
  _bl_seg_active tokens_in && return 0
  _bl_seg_active tokens_out && return 0
  [[ -z "$total_cost" ]] && _bl_seg_active cost && return 0
  [[ -z "$ctx_from_payload" ]] && _bl_seg_active context && return 0
  return 1
}

# Writes the jq input stream described above, from the _up_* plan arrays.
# Reads exactly up to the size stat reported, so appends racing this refresh
# are left for the next one.
_bl_usage_stream() {
  local i
  for ((i = 0; i < ${#_up_hdr[@]}; i++)); do
    printf '\036%s %s\n' "${_up_size[i]}" "${_up_hdr[i]}"
    (( _up_from[i] < 0 )) && continue
    tail -c "+$(( _up_from[i] + 1 ))" "${_up_path[i]}" 2>/dev/null \
      | head -c "$(( _up_size[i] - _up_from[i] ))"
    printf '\n'
  done
}

bl_read_usage() {
  sum_in=0; sum_out=0; sum_cache_read=0; sum_cache_create=0; web_searches=0
  [[ -n "$transcript" && -f "$transcript" ]] || return 0
  _bl_usage_needed || return 0

  local -a files=("$transcript") subs=()
  local subdir="${transcript%.jsonl}/subagents"
  [[ -d "$subdir" ]] && { shopt -s nullglob; subs=("$subdir"/*.jsonl); shopt -u nullglob; }
  files+=("${subs[@]}")

  # "dev:inode size path" per file, main transcript first. GNU stat first: BSD
  # stat rejects -c with no output, while GNU's -f means something else.
  local stats
  stats=$(stat -c '%d:%i %s %n' "${files[@]}" 2>/dev/null)
  [[ -z "$stats" ]] && stats=$(stat -f '%d:%i %z %N' "${files[@]}" 2>/dev/null)
  [[ -z "$stats" ]] && return 0

  local cache_dir="${BOTTOMLINE_CACHE_DIR:-/tmp}" sid="${transcript##*/}"
  local cache="$cache_dir/bl_usage_${sid%.jsonl}.tsv"

  # Previous state, in the order it was written (the same order as $stats).
  local -a c_path=() c_key=() c_off=() c_hdr=()
  local p k o h n=0
  if [[ -f "$cache" ]]; then
    while IFS=$'\x1f' read -r p k o h; do
      c_path[n]=$p; c_key[n]=$k; c_off[n]=$o; c_hdr[n]=$h; n=$((n + 1))
    done < "$cache"
  else
    find "$cache_dir" -maxdepth 1 -name 'bl_usage_*.tsv' -mtime +7 -delete 2>/dev/null
  fi

  _up_hdr=(); _up_path=(); _up_from=(); _up_size=()
  local key size path i m cursor=0 changed='' esc
  while read -r key size path; do
    [[ -z "$path" ]] && continue
    m=-1
    if [[ "${c_path[cursor]:-}" == "$path" ]]; then
      m=$cursor
    else
      for ((i = 0; i < n; i++)); do [[ "${c_path[i]}" == "$path" ]] && { m=$i; break; }; done
    fi
    (( m >= 0 )) && cursor=$((m + 1))

    i=${#_up_hdr[@]}
    _up_path[i]=$path; _up_size[i]=$size
    if (( m >= 0 )) && [[ "${c_key[m]}" == "$key" && "${c_off[m]}" =~ ^[0-9]+$ ]] \
       && (( c_off[m] <= size )); then
      _up_hdr[i]=${c_hdr[m]}
      if (( c_off[m] == size )); then _up_from[i]=-1; else _up_from[i]=${c_off[m]}; changed=1; fi
    else
      # New, replaced (different inode) or truncated: read from the start.
      esc=${path//\\/\\\\}; esc=${esc//\"/\\\"}
      _up_hdr[i]="{\"p\":\"$esc\",\"k\":\"$key\",\"o\":0}"
      _up_from[i]=0; changed=1
    fi
  done <<< "$stats"
  (( ${#_up_hdr[@]} != n )) && changed=1  # a file disappeared

  local out
  out=$(_bl_usage_stream | jq -nRr "$_BL_USAGE_JQ" 2>/dev/null)
  unset _up_hdr _up_path _up_from _up_size
  # A failed pass most likely means a damaged cache: drop it so the next
  # refresh starts over instead of failing the same way.
  [[ -z "$out" ]] && { rm -f "$cache" 2>/dev/null; return 0; }

  local ctx
  IFS=$'\t' read -r ctx sum_in sum_out sum_cache_read sum_cache_create web_searches <<< "${out%%$'\n'*}"
  [[ -z "$ctx_from_payload" ]] && ctx_used=${ctx:-0}

  if [[ -n "$changed" && "$out" == *$'\n'* ]]; then
    printf '%s\n' "${out#*$'\n'}" > "$cache.$$" 2>/dev/null && mv -f "$cache.$$" "$cache" 2>/dev/null
    rm -f "$cache.$$" 2>/dev/null
  fi
  return 0
}
