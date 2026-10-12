# shellcheck shell=bash
# Sourced by link-skills.sh, link-opencode-commands.sh and use-skills.sh; not
# run directly. Expects REPO to be set to the repo root before sourcing.
#
# A **skill set** is a switchable group of skill buckets. Exactly one set (or
# `all`) is active at a time, persisted in the git-ignored $REPO/.skill-set
# file and changed with scripts/use-skills.sh:
#   - pocock: skills/engineering, skills/productivity, skills/in-progress
#   - addy:   skills/addy
#   - pstack: skills/pstack
#   - all:    all three
# Some buckets are always on whatever the set: skills/gcp, skills/android,
# skills/personal, plus any SKILL.md outside skills/ (e.g. peer-review/).
# skills/deprecated is never linked, and neither is skills/misc unless the
# caller asks for it (link-opencode-commands.sh has always stubbed misc/).

SKILL_SET_FILE="$REPO/.skill-set"
SKILL_SETS="pocock addy pstack all"
DEFAULT_SKILL_SET="pocock"

# Prints the active skill set, falling back to the default when the state file
# is missing, empty, or holds something unrecognised.
active_skill_set() {
  local set=""
  [ -f "$SKILL_SET_FILE" ] && set="$(tr -d '[:space:]' <"$SKILL_SET_FILE")"
  case " $SKILL_SETS " in
    *" $set "*) [ -n "$set" ] && { echo "$set"; return; } ;;
  esac
  echo "$DEFAULT_SKILL_SET"
}

# Prints the set a skill (or agent) path belongs to: one of the switchable set
# names, `always`, `misc`, or `never`.
skill_path_set() {
  case "$1" in
    "$REPO"/skills/deprecated/*|"$REPO"/skills/*/deprecated/*) echo never ;;
    "$REPO"/skills/misc/*) echo misc ;;
    "$REPO"/skills/engineering/*|"$REPO"/skills/productivity/*|"$REPO"/skills/in-progress/*) echo pocock ;;
    "$REPO"/skills/addy/*) echo addy ;;
    "$REPO"/skills/pstack/*) echo pstack ;;
    *) echo always ;;
  esac
}

# True if the skill dir (or agent file) at $1 should be installed under the
# active set. Pass `include-misc` as $2 to treat misc/ as always on. Callers
# looping over many paths can set ACTIVE_SKILL_SET once to skip re-reading the
# state file on every call.
skill_path_active() {
  local belongs active
  belongs="$(skill_path_set "$1")"
  active="${ACTIVE_SKILL_SET:-$(active_skill_set)}"
  case "$belongs" in
    always) return 0 ;;
    never) return 1 ;;
    misc) [ "${2:-}" = "include-misc" ] ;;
    *) [ "$active" = "all" ] || [ "$active" = "$belongs" ] ;;
  esac
}

# Prints every SKILL.md in the repo, NUL-delimited, skipping node_modules and
# .git. Callers filter with skill_path_active.
all_skill_mds() {
  find "$REPO" -name SKILL.md \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -print0
}

# Prints every vendored agent file (skills/<bucket>/agents/*.md), NUL-delimited.
all_agent_mds() {
  find "$REPO/skills" -mindepth 3 -maxdepth 3 -path '*/agents/*.md' \
    -not -name SKILL.md -not -name README.md -print0
}
