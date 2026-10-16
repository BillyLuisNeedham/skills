#!/usr/bin/env bash
set -euo pipefail

# Read-only views of the skill sets, for the /king skill.
#
#   king.sh sets           every set: active marker, position, skill and agent
#                          counts, one-line description
#   king.sh skills <set>   the skills (and agents) in one set, with each
#                          skill's description
#   king.sh repo           the repo root this script lives in
#
# Changing sets is scripts/use-skills.sh; this script never writes anything.

REPO="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
# shellcheck source=../scripts/skill-sets.sh
. "$REPO/scripts/skill-sets.sh"

set_description() {
  case "$1" in
    pocock) echo "Matt Pocock's upstream skills: engineering, productivity and in-progress" ;;
    addy) echo "Addy Osmani's agent skills, slash commands and agents (synced)" ;;
    pclaude) echo "pstack ported to Claude Code, plus its agents" ;;
    personal) echo "Billy's own my-* skills and vendored third-party skills" ;;
    gcp) echo "Google Cloud skills (synced from google/skills)" ;;
    android) echo "Android skills (synced from android/skills)" ;;
  esac
}

# Every SKILL.md and agent file with the set it belongs to, as
# `set<TAB>kind<TAB>path` lines, classified once.
classify_all() {
  local path
  while IFS= read -r -d '' path; do
    printf '%s\tskill\t%s\n' "$(skill_path_set "$(dirname "$path")")" "$path"
  done < <(all_skill_mds)
  while IFS= read -r -d '' path; do
    printf '%s\tagent\t%s\n' "$(skill_path_set "$path")" "$path"
  done < <(all_agent_mds)
}

# Prints the paths of kind $2 (skill or agent) in set $1, one per line.
paths_of() {
  awk -F'\t' -v set="$1" -v kind="$2" '$1 == set && $2 == kind { print $3 }' <<<"$CLASSIFIED"
}

# Prints the frontmatter description of the SKILL.md at $1, on one line.
skill_description() {
  awk '
    NR == 1 && $0 == "---" { fm = 1; next }
    fm && $0 == "---" { exit }
    fm && /^description:/ { sub(/^description:[ ]*/, ""); gsub(/^["'\'']|["'\'']$/, ""); print; exit }
  ' "$1"
}

cmd_sets() {
  local active set pos i n_skills n_agents mark
  active="$(active_skill_sets | tr '\n' ' ')"
  CLASSIFIED="$(classify_all)"
  echo "Active, in order (later wins a name clash): $active"
  echo
  printf '%-3s %-9s %6s %6s  %s\n' "" set skills agents description
  for set in $SKILL_SETS; do
    pos="" i=0
    for s in $active; do
      i=$((i + 1))
      [ "$s" = "$set" ] && pos="$i"
    done
    mark="${pos:+#$pos}"
    n_skills="$(paths_of "$set" skill | command grep -c . || true)"
    n_agents="$(paths_of "$set" agent | command grep -c . || true)"
    printf '%-3s %-9s %6s %6s  %s\n' "$mark" "$set" "$n_skills" "$n_agents" "$(set_description "$set")"
  done
  echo
  echo "Always on, outside every set:"
  while IFS= read -r skill_md; do
    echo "  $(basename "$(dirname "$skill_md")")"
  done < <(paths_of always skill)
}

cmd_skills() {
  local set="${1:-}" skill_md agent_md
  if ! is_skill_set "$set"; then
    echo "error: unknown skill set '$set' (sets: $SKILL_SETS)" >&2
    exit 1
  fi
  CLASSIFIED="$(classify_all)"
  echo "$set: $(set_description "$set")"
  echo
  while IFS= read -r skill_md; do
    [ -n "$skill_md" ] || continue
    printf -- '- %s: %s\n' "$(basename "$(dirname "$skill_md")")" "$(skill_description "$skill_md")"
  done < <(paths_of "$set" skill)
  local agents
  agents="$(paths_of "$set" agent)"
  if [ -n "$agents" ]; then
    echo
    echo "Agents:"
    while IFS= read -r agent_md; do
      printf -- '- %s\n' "$(basename "$agent_md" .md)"
    done <<<"$agents"
  fi
}

case "${1:-}" in
  sets) cmd_sets ;;
  skills) shift; cmd_skills "$@" ;;
  repo) echo "$REPO" ;;
  *) echo "usage: $(basename "$0") sets | skills <set> | repo" >&2; exit 1 ;;
esac
