# shellcheck shell=bash
# Sourced by link-skills.sh, link-opencode-commands.sh and use-skills.sh; not
# run directly. Expects REPO to be set to the repo root before sourcing.
#
# A **skill set** is a switchable group of skill buckets. Every bucket under
# skills/ belongs to one set:
#   - pocock:   skills/engineering, skills/productivity, skills/in-progress
#   - addy:     skills/addy
#   - pclaude:  skills/pclaude
#   - personal: skills/personal
#   - gcp:      skills/gcp
#   - android:  skills/android
# Several sets can be active at once. The active list is kept in the
# git-ignored $REPO/.skill-set file, one set per line, in order, and changed
# with scripts/use-skills.sh. With no file the default list is
# `pocock personal gcp android`.
#
# Order matters when two active sets hold a skill (or agent) with the same
# name. Both are still considered, the set listed later wins, and the link
# scripts print a warning naming both copies and the one they linked.
#
# Some paths sit outside the sets:
#   - any SKILL.md outside skills/ (peer-review/, king/) is always on
#   - an unknown bucket under skills/ is treated as always on
#   - skills/deprecated is never linked
#   - skills/misc is never linked unless the caller asks for it
#     (link-opencode-commands.sh has always stubbed misc/)
#   - skills/pstack is the synced Cursor copy of pclaude. It is not a set and
#     is never linked into Claude Code. It is copied into ~/.cursor/skills
#     while pclaude is active, taking pclaude's place in the order.
#   - skills/pclaude is never copied into ~/.cursor/skills.
#
# Each consumer picks a target, which decides what counts as installed:
#   - claude:   ~/.claude/skills, ~/.agents/skills, ~/.claude/agents
#   - cursor:   ~/.cursor/skills
#   - opencode: the claude target plus skills/misc
#
# Legacy files: before sets stacked, .skill-set held one word (pocock, addy,
# pstack or all) and personal, gcp and android were always on. A file with no
# header line holding exactly one of those words is read the old way, so
# `pocock` means `pocock personal gcp android`, `pstack` maps to pclaude, and
# `all` means every set. use-skills.sh always writes the header line, which is
# how a deliberate one-set list (`use-skills.sh pocock`) stays one set.

SKILL_SET_FILE="$REPO/.skill-set"
SKILL_SETS="pocock addy pclaude personal gcp android"
DEFAULT_SKILL_SETS="pocock personal gcp android"
SKILL_SET_HEADER="# Active skill sets, one per line, later wins on a name clash. Written by scripts/use-skills.sh."

# True if $1 is a selectable set name.
is_skill_set() {
  case " $SKILL_SETS " in
    *" $1 "*) [ -n "$1" ] ;;
    *) return 1 ;;
  esac
}

# Prints the active sets, one per line, in order: deduplicated, `all`
# expanded, unknown names dropped with a warning on stderr. Falls back to the
# default when the state file is missing, empty, or holds nothing usable.
active_skill_sets() {
  local words="" header=0 line word out="" n=0
  if [ -f "$SKILL_SET_FILE" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in
        "$SKILL_SET_HEADER") header=1; continue ;;
        \#*) continue ;;
      esac
      for word in $line; do
        words="$words $word"
        n=$((n + 1))
      done
    done <"$SKILL_SET_FILE"
  fi

  if (( ! header && n == 1 )); then
    case "${words# }" in
      pocock|addy) words="${words# } personal gcp android" ;;
      pstack) words="pclaude personal gcp android" ;;
    esac
  fi

  for word in $words; do
    if [ "$word" = all ]; then
      for word in $SKILL_SETS; do
        case " $out " in *" $word "*) ;; *) out="$out $word" ;; esac
      done
    elif is_skill_set "$word"; then
      case " $out " in *" $word "*) ;; *) out="$out $word" ;; esac
    else
      echo "warning: ignoring unknown skill set '$word' in $SKILL_SET_FILE" >&2
    fi
  done

  [ -n "$out" ] || out="$DEFAULT_SKILL_SETS"
  printf '%s\n' $out
}

# Writes the given sets to the state file, header first, one per line.
write_skill_sets() {
  { printf '%s\n' "$SKILL_SET_HEADER"; printf '%s\n' "$@"; } >"$SKILL_SET_FILE"
}

# Prints the set a skill (or agent) path belongs to: one of the set names,
# `pstack`, `always`, `misc`, or `never`.
skill_path_set() {
  case "$1" in
    "$REPO"/skills/deprecated/*|"$REPO"/skills/*/deprecated/*) echo never ;;
    "$REPO"/skills/misc/*) echo misc ;;
    "$REPO"/skills/engineering/*|"$REPO"/skills/productivity/*|"$REPO"/skills/in-progress/*) echo pocock ;;
    "$REPO"/skills/addy/*) echo addy ;;
    "$REPO"/skills/pclaude/*) echo pclaude ;;
    "$REPO"/skills/personal/*) echo personal ;;
    "$REPO"/skills/gcp/*) echo gcp ;;
    "$REPO"/skills/android/*) echo android ;;
    "$REPO"/skills/pstack/*) echo pstack ;;
    *) echo always ;;
  esac
}

# Prints the clash rank of the path at $1 for target $2 (claude, cursor or
# opencode), or fails if the path is not installed there. Rank 0 is for paths
# outside the sets; an active set ranks by its 1-based position in the active
# list, so a higher rank wins a clash. Callers looping over many paths should
# set ACTIVE_SKILL_SETS (space-separated) once to skip re-reading the file.
skill_path_rank() {
  local belongs target="$2" active i=0 set
  belongs="$(skill_path_set "$1")"
  active="${ACTIVE_SKILL_SETS:-$(active_skill_sets | tr '\n' ' ')}"
  case "$belongs" in
    always) echo 0; return 0 ;;
    never) return 1 ;;
    misc) [ "$target" = opencode ] && { echo 0; return 0; }; return 1 ;;
    pstack) [ "$target" = cursor ] || return 1; belongs=pclaude ;;
    pclaude) [ "$target" = cursor ] && return 1 ;;
  esac
  for set in $active; do
    i=$((i + 1))
    [ "$set" = "$belongs" ] && { echo "$i"; return 0; }
  done
  return 1
}

# True if the path at $1 is installed for target $2.
skill_path_active() {
  skill_path_rank "$1" "$2" >/dev/null
}

# Reads `rank<TAB>name<TAB>path` lines and prints the winning path for each
# name, one per line: the highest rank wins, and among equal ranks the later
# line wins. Each clash prints a warning on stderr naming both copies and the
# one kept. $1 labels the warnings with the target.
pick_winners() {
  local label="$1"
  awk -F'\t' '{ printf "%s\t%08d\t%s\t%s\n", $1, NR, $2, $3 }' |
    sort -t "$(printf '\t')" -k1,1n -k2,2n |
    awk -F'\t' -v label="$label" '
      {
        if ($3 in win) {
          printf "warning: name clash (%s): %s is in %s and %s; linked %s (the later set wins)\n",
            label, $3, win[$3], $4, $4 > "/dev/stderr"
        } else {
          order[++n] = $3
        }
        win[$3] = $4
      }
      END { for (i = 1; i <= n; i++) print win[order[i]] }
    '
}

# Prints the winning skill dir for every skill name installed for target $1,
# one per line. Clashes are warned about on stderr.
winning_skill_dirs() {
  local target="$1" skill_md dir rank
  while IFS= read -r -d '' skill_md; do
    dir="$(dirname "$skill_md")"
    rank="$(skill_path_rank "$dir" "$target")" || continue
    printf '%s\t%s\t%s\n' "$rank" "$(basename "$dir")" "$dir"
  done < <(all_skill_mds) | pick_winners "$target skills"
}

# Prints the winning agent file for every agent name installed for target $1,
# one per line. Clashes are warned about on stderr.
winning_agent_mds() {
  local target="$1" agent_md rank
  while IFS= read -r -d '' agent_md; do
    rank="$(skill_path_rank "$agent_md" "$target")" || continue
    printf '%s\t%s\t%s\n' "$rank" "$(basename "$agent_md")" "$agent_md"
  done < <(all_agent_mds) | pick_winners "$target agents"
}

# Prints every SKILL.md in the repo, NUL-delimited, skipping node_modules and
# .git. Sorted, so equal-rank ties resolve the same way on every run. Pruned by
# name, not matched by path: a git worktree can live under .git/ itself, and a
# '*/.git/*' path filter would then drop every skill.
all_skill_mds() {
  find "$REPO" \( -name .git -o -name node_modules \) -prune \
    -o -name SKILL.md -print0 | sort -z
}

# Prints every vendored agent file (skills/<bucket>/agents/*.md), NUL-delimited.
all_agent_mds() {
  find "$REPO/skills" -mindepth 3 -maxdepth 3 -path '*/agents/*.md' \
    -not -name SKILL.md -not -name README.md -print0 | sort -z
}
