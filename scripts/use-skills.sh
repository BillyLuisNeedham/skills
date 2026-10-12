#!/usr/bin/env bash
set -euo pipefail

# Switches which skill set is installed into the local harness directories.
#
#   scripts/use-skills.sh                         print the active set
#   scripts/use-skills.sh pocock|addy|pstack|all  switch to that set
#
# Sets (see scripts/skill-sets.sh):
#   - pocock: skills/engineering, skills/productivity, skills/in-progress (default)
#   - addy:   skills/addy (addyosmani/agent-skills, plus its agents)
#   - pstack: skills/pstack (cursor/plugins pstack, plus its agents)
#   - all:    all three
# skills/gcp, skills/android, skills/personal and peer-review/ are always on;
# deprecated/ and misc/ are never linked.
#
# The choice is persisted in the git-ignored .skill-set file at the repo root,
# so link-skills.sh, link-opencode-commands.sh and update-skills.sh all honour
# it. Switching re-runs both link scripts, which add the new set's skills and
# agents and remove the ones they own from the old set.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=skill-sets.sh
. "$REPO/scripts/skill-sets.sh"

if (( $# == 0 )); then
  active_skill_set
  exit 0
fi

set_name="$1"
case " $SKILL_SETS " in
  *" $set_name "*) ;;
  *)
    echo "usage: $(basename "$0") [${SKILL_SETS// /|}]" >&2
    exit 1
    ;;
esac

printf '%s\n' "$set_name" > "$SKILL_SET_FILE"
echo "==> Active skill set: $set_name"

echo "==> Linking skills and agents..."
bash "$REPO/scripts/link-skills.sh"

echo "==> Generating OpenCode slash commands..."
bash "$REPO/scripts/link-opencode-commands.sh"

echo ""
echo "Done. Restart Claude Code (and any other open harness) to pick up the '$set_name' skill set."
