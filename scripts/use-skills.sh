#!/usr/bin/env bash
set -euo pipefail

# Changes which skill sets are installed into the local harness directories.
#
#   scripts/use-skills.sh                        print the active sets, one per line
#   scripts/use-skills.sh pocock pclaude ...     make exactly these sets active, in order
#   scripts/use-skills.sh +addy -gcp             add or remove sets from the active list
#   scripts/use-skills.sh all                    make every set active
#
# Sets (see scripts/skill-sets.sh):
#   - pocock:   skills/engineering, skills/productivity, skills/in-progress
#   - addy:     skills/addy (addyosmani/agent-skills, plus its agents)
#   - pclaude:  skills/pclaude (pstack ported to Claude Code, plus its agents)
#   - personal: skills/personal
#   - gcp:      skills/gcp
#   - android:  skills/android
# The default is `pocock personal gcp android`. peer-review/ and any other
# SKILL.md outside skills/ are always on; deprecated/ and misc/ are never
# linked. skills/pstack is not a set: it is Cursor's copy of pclaude.
#
# Order matters: when two active sets hold the same skill or agent name, the
# later set wins and the link scripts warn. `+set` appends to the end (or
# leaves a set already active where it is); `-set` removes it. Plain names and
# +/- edits cannot be mixed in one call.
#
# The list is persisted in the git-ignored .skill-set file at the repo root,
# so link-skills.sh, link-opencode-commands.sh and update-skills.sh all honour
# it. Changing it re-runs both link scripts, which add the new sets' skills and
# agents and remove the ones they own from sets no longer active.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=skill-sets.sh
. "$REPO/scripts/skill-sets.sh"

usage() {
  echo "usage: $(basename "$0") [set ... | +set|-set ... | all]" >&2
  echo "sets: $SKILL_SETS" >&2
  exit 1
}

if (( $# == 0 )); then
  active_skill_sets
  exit 0
fi

check_set() {
  is_skill_set "$1" && return 0
  if [ "$1" = pstack ]; then
    echo "error: pstack is no longer a set; it is Cursor-only. Use pclaude." >&2
  else
    echo "error: unknown skill set '$1'" >&2
  fi
  usage
}

edits=0 plain=0
for arg in "$@"; do
  case "$arg" in
    +*|-*) edits=1 ;;
    *) plain=1 ;;
  esac
done
if (( edits && plain )); then
  echo "error: give either a list of sets or +/- edits, not both" >&2
  usage
fi

new=()
if (( edits )); then
  # shellcheck disable=SC2207
  new=($(active_skill_sets))
  for arg in "$@"; do
    name="${arg#[+-]}"
    if [ "$name" = all ] && [ "${arg:0:1}" = + ]; then
      # shellcheck disable=SC2206
      for set_name in $SKILL_SETS; do
        case " ${new[*]} " in *" $set_name "*) ;; *) new+=("$set_name") ;; esac
      done
      continue
    fi
    check_set "$name"
    case "$arg" in
      +*)
        case " ${new[*]} " in *" $name "*) ;; *) new+=("$name") ;; esac
        ;;
      -*)
        kept=()
        for set_name in "${new[@]}"; do
          [ "$set_name" = "$name" ] || kept+=("$set_name")
        done
        new=("${kept[@]+"${kept[@]}"}")
        ;;
    esac
  done
else
  for arg in "$@"; do
    if [ "$arg" = all ]; then
      # shellcheck disable=SC2206
      for set_name in $SKILL_SETS; do
        case " ${new[*]-} " in *" $set_name "*) ;; *) new+=("$set_name") ;; esac
      done
      continue
    fi
    check_set "$arg"
    case " ${new[*]-} " in *" $arg "*) ;; *) new+=("$arg") ;; esac
  done
fi

if (( ${#new[@]} == 0 )); then
  echo "error: that would leave no skill set active" >&2
  exit 1
fi

write_skill_sets "${new[@]}"
echo "==> Active skill sets: ${new[*]}"

echo "==> Linking skills and agents..."
bash "$REPO/scripts/link-skills.sh"

echo "==> Generating OpenCode slash commands..."
bash "$REPO/scripts/link-opencode-commands.sh"

echo ""
echo "Done. A running Claude Code session picks this up live (run /reload-skills if a"
echo "skill is missing; restart only if ~/.claude/agents did not exist at session start)."
echo "Restart Cursor, Codex and OpenCode to pick up the new skill sets."
