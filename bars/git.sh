#!/usr/bin/env bash
# Bottomline bar: Git enrichment bar
# Segments (in order): branch, worktree (if linked), changes, stash, ahead/behind, last commit.
# If git is not installed, renders a warning segment instead.

PROJ="${BOTTOMLINE_PROJECT_DIR:-}"
[[ -z "$PROJ" ]] && exit 0

source "$BOTTOMLINE_LIB/helpers.sh"

if [[ -z "${BOTTOMLINE_BAR_COLORS:-}" ]]; then
  FG_TEXT=$(make_fg "$(hex_to_rgb "#f0ddd8")")
  FG_ACCENT=$(make_fg "$(hex_to_rgb "#f05033")")
  _bar_gradient='["#1a0c08","#2e1610"]'
else
  _bar_gradient="$BOTTOMLINE_GRADIENT"
fi

case "$BOTTOMLINE_ICON_TYPE" in
  nerd)
    IC_BRANCH=$'\xee\x82\xa0'    # U+E0A0  nf-powerline-branch
    IC_WORKTREE=$'\xee\x9c\xa7'  # U+E727  nf-dev-git_branch
    IC_CHANGES=$'\xef\x81\x84'   # U+F044  nf-fa-pencil
    IC_STASH=$'\xef\x86\x87'     # U+F187  nf-fa-archive
    IC_COMMIT=$'\xef\x87\x9a'    # U+F1DA  nf-fa-history
    IC_WARN=$'\xef\x81\xb1'      # U+F071  nf-fa-warning
    IC_CLEAN=$'\xef\x80\x8c'     # U+F00C  nf-fa-check
    ;;
  emoji)
    IC_BRANCH='⎇'
    IC_WORKTREE='🌿'
    IC_CHANGES='✏️'
    IC_STASH='📦'
    IC_COMMIT='🕐'
    IC_WARN='⚠️'
    IC_CLEAN='✓'
    ;;
  *)
    IC_BRANCH='' IC_WORKTREE='' IC_CHANGES='' IC_STASH=''
    IC_COMMIT='' IC_WARN='' IC_CLEAN='✓'
    ;;
esac



# ── Git availability check ────────────────────────────────────────────────────
if ! command -v git > /dev/null 2>&1; then
  add_seg "${FG_WARN}${IC_WARN} ${FG_TEXT}git not installed"
  flush "$_bar_gradient"
  exit 0
fi

if ! git -C "$PROJ" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  exit 0
fi

# ── Branch ────────────────────────────────────────────────────────────────────
branch=$(git -C "$PROJ" symbolic-ref --short -q HEAD 2>/dev/null)
is_detached=false
if [[ -z "$branch" ]]; then
  is_detached=true
  branch=$(git -C "$PROJ" describe --tags --exact-match HEAD 2>/dev/null \
           || git -C "$PROJ" rev-parse --short HEAD 2>/dev/null)
  branch="${branch:-HEAD}"
fi

# ── Worktree ──────────────────────────────────────────────────────────────────
# A linked worktree has a .git FILE (not directory) at the repo root.
worktree_name=''
git_toplevel=$(git -C "$PROJ" rev-parse --show-toplevel 2>/dev/null)
if [[ -n "$git_toplevel" && -f "$git_toplevel/.git" ]]; then
  _gitdir=$(sed -n 's/^gitdir: //p' "$git_toplevel/.git" 2>/dev/null)
  [[ "$_gitdir" == *"/worktrees/"* ]] && worktree_name="${_gitdir##*/worktrees/}"
  unset _gitdir
fi

# ── Uncommitted changes + line stats ─────────────────────────────────────────
_git_status=$(git -C "$PROJ" status --porcelain 2>/dev/null)
change_count=0
stat_insertions=0
stat_deletions=0
if [[ -n "$_git_status" ]]; then
  change_count=$(printf '%s' "$_git_status" | grep -c '.')
  change_count=$(( change_count + 0 ))

  # Line stats for tracked modifications (staged + unstaged) vs HEAD
  while IFS=$'\t' read -r _ins _del _rest; do
    [[ "$_ins" =~ ^[0-9]+$ ]] || continue
    [[ "$_del" =~ ^[0-9]+$ ]] || continue
    stat_insertions=$(( stat_insertions + _ins ))
    stat_deletions=$(( stat_deletions + _del ))
  done < <(git -C "$PROJ" diff HEAD --numstat 2>/dev/null)

  # Line stats for untracked files — git diff doesn't include these
  while IFS= read -r _sl; do
    [[ "${_sl:0:2}" != '??' ]] && continue
    _entry="${_sl:3}"
    if [[ "$_entry" == */ ]]; then
      _dir_lines=$(find "$PROJ/${_entry%/}" -type f 2>/dev/null | while IFS= read -r _f; do
        awk 'END{print NR}' "$_f" 2>/dev/null || echo 0
      done | awk '{s+=$1} END{print s+0}')
      stat_insertions=$(( stat_insertions + ${_dir_lines:-0} ))
    else
      _file_lines=$(awk 'END{print NR}' "$PROJ/$_entry" 2>/dev/null || echo 0)
      stat_insertions=$(( stat_insertions + _file_lines ))
    fi
  done <<< "$_git_status"
fi
unset _git_status

# ── Stash count ───────────────────────────────────────────────────────────────
_stash_out=$(git -C "$PROJ" stash list 2>/dev/null)
stash_count=0
if [[ -n "$_stash_out" ]]; then
  stash_count=$(printf '%s' "$_stash_out" | grep -c '.')
  stash_count=$(( stash_count + 0 ))
fi
unset _stash_out

# ── Ahead/behind tracking branch ─────────────────────────────────────────────
ahead=0 behind=0 has_upstream=false
ab_raw=$(git -C "$PROJ" rev-list --count --left-right "@{upstream}...HEAD" 2>/dev/null)
if [[ -n "$ab_raw" && "$ab_raw" == *$'\t'* ]]; then
  has_upstream=true
  behind=${ab_raw%%$'\t'*}
  ahead=${ab_raw##*$'\t'}
  [[ "$behind" =~ ^[0-9]+$ ]] || behind=0
  [[ "$ahead"  =~ ^[0-9]+$ ]] || ahead=0
fi

# ── Last commit ───────────────────────────────────────────────────────────────
commit_info=$(git -C "$PROJ" log -1 --format="%an|%ar" 2>/dev/null)
commit_author="${commit_info%%|*}"
commit_author="${commit_author%% *}"  # first name only
commit_time_raw="${commit_info##*|}"

shorten_rel_time() {
  printf '%s' "$1" | awk '{
    if      ($0 ~ /a few seconds|just now/) print "now"
    else if ($0 ~ /^a minute/)              print "1m"
    else if ($0 ~ /minutes/)                { match($0, /[0-9]+/); print substr($0,RSTART,RLENGTH) "m" }
    else if ($0 ~ /^an hour/)               print "1h"
    else if ($0 ~ /hours/)                  { match($0, /[0-9]+/); print substr($0,RSTART,RLENGTH) "h" }
    else if ($0 ~ /^a day/)                 print "1d"
    else if ($0 ~ /days/)                   { match($0, /[0-9]+/); print substr($0,RSTART,RLENGTH) "d" }
    else if ($0 ~ /^a week/)                print "1w"
    else if ($0 ~ /weeks/)                  { match($0, /[0-9]+/); print substr($0,RSTART,RLENGTH) "w" }
    else if ($0 ~ /^a month/)               print "1mo"
    else if ($0 ~ /months/)                 { match($0, /[0-9]+/); print substr($0,RSTART,RLENGTH) "mo" }
    else if ($0 ~ /^a year/)                print "1y"
    else if ($0 ~ /years/)                  { match($0, /[0-9]+/); print substr($0,RSTART,RLENGTH) "y" }
    else print $0
  }'
}
commit_time=$(shorten_rel_time "$commit_time_raw")

# ── Segments ──────────────────────────────────────────────────────────────────

# Branch — warning color when in detached HEAD state
if $is_detached; then
  add_seg "${FG_WARN}${IC_BRANCH} ${FG_TEXT}${branch}"
else
  add_seg "${FG_ACCENT}${IC_BRANCH} ${FG_TEXT}${branch}"
fi

# Worktree — only shown when inside a linked worktree
[[ -n "$worktree_name" ]] && add_seg "${FG_ACCENT}${IC_WORKTREE} ${FG_TEXT}${worktree_name}"

# Changes — always shown; warning when dirty, accent when clean
if (( change_count == 0 )); then
  add_seg "${FG_ACCENT}${IC_CLEAN} ${FG_TEXT}clean"
else
  add_seg "${FG_ACCENT}${IC_CHANGES} ${FG_TEXT}+${stat_insertions} ${FG_ACCENT}-${stat_deletions}"
fi

# Stash — icon · count · label
if (( stash_count > 0 )); then
  stash_label='stash'
  (( stash_count != 1 )) && stash_label='stashes'
  add_seg "${FG_ACCENT}${IC_STASH} ${FG_ACCENT}${stash_count} ${FG_TEXT}${stash_label}"
fi

# Ahead/behind — only shown when tracking a remote and not fully in sync
if $has_upstream && (( ahead > 0 || behind > 0 )); then
  ab_seg=''
  if (( ahead > 0 )); then
    ab_seg+="${FG_ACCENT}↑${FG_TEXT}${ahead}"
  fi
  if (( behind > 0 )); then
    [[ -n "$ab_seg" ]] && ab_seg+=' '
    ab_seg+="${FG_WARN}↓${FG_TEXT}${behind}"
  fi
  add_seg "$ab_seg"
fi

# Last commit — author first name and abbreviated age
if [[ -n "$commit_author" && -n "$commit_time" ]]; then
  add_seg "${FG_ACCENT}${IC_COMMIT} ${FG_TEXT}${commit_author} ${FG_ACCENT}·${FG_TEXT} ${commit_time}"
fi

(( ${#_sc[@]} == 0 )) && exit 0
flush "$_bar_gradient"
