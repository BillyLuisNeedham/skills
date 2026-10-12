#!/usr/bin/env bash
set -euo pipefail

# NOTE: This is a dev-only script, intended for use by maintainers of this repo.
# It is not a supported installer. Modifications to it, or requests for
# modifications, will not be approved.
#
# Links every skill in the active skill set (see scripts/skill-sets.sh and
# scripts/use-skills.sh), plus the always-on buckets, into the local skill
# directories used by each agent harness:
#   - ~/.claude/skills: Claude Code (symlink)
#   - ~/.agents/skills: Codex and other Agent Skills-compatible harnesses (symlink)
#   - ~/.cursor/skills: Cursor (real copy, because its picker won't follow symlinks)
# The symlinked entries point into this repo, so a `git pull` is all that's
# needed to keep those installed skills up to date. Cursor's copies are
# refreshed by re-running this script.
#
# Vendored agents of the active set (skills/addy/agents/, skills/pstack/agents/)
# are symlinked into ~/.claude/agents the same way.
#
# Entries this script owns that belong to an inactive set are removed: symlinks
# pointing into this repo, and Cursor copies stamped with a .linked-from marker
# naming this repo (or, for older unstamped copies, named after a repo skill).
# Anything else in those directories is left alone.
#
# `deprecated/` is retired and `misc/` is kept around but rarely used and not
# promoted (see each bucket's own README): neither belongs in a daily-driver
# skill directory, so both are skipped, same as everywhere else non-promoted
# skills are kept out. `in-progress/` IS still linked under the `pocock` set:
# it's public on purpose, feedback wanted, and this local install is exactly
# where that loop runs.
# The find is deliberately rooted at $REPO, not $REPO/skills: peer-review/
# holds a SKILL.md at the repo root and must stay linked (it is always on).

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=skill-sets.sh
. "$REPO/scripts/skill-sets.sh"

CURSOR_DEST="$HOME/.cursor/skills"
DESTS=("$HOME/.claude/skills" "$HOME/.agents/skills" "$CURSOR_DEST")
AGENTS_DEST="$HOME/.claude/agents"
ACTIVE_SKILL_SET="$(active_skill_set)"

# Active repo skills as NUL-delimited SKILL.md paths, and their names (all repo
# skill names too, so stale Cursor copies can be told apart from user ones).
ACTIVE_SKILL_MDS=()
ALL_NAMES=""
ACTIVE_NAMES=""
while IFS= read -r -d '' skill_md; do
  dir="$(dirname "$skill_md")"
  name="$(basename "$dir")"
  ALL_NAMES="$ALL_NAMES$name"$'\n'
  if skill_path_active "$dir"; then
    ACTIVE_SKILL_MDS+=("$skill_md")
    ACTIVE_NAMES="$ACTIVE_NAMES$name"$'\n'
  fi
done < <(all_skill_mds)

echo "skill set: $ACTIVE_SKILL_SET"

guard_dest() {
  local dest="$1"
  if [ -L "$dest" ]; then
    local resolved
    resolved="$(readlink -f "$dest")"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "error: $dest is a symlink into this repo ($resolved)." >&2
        echo "Remove it (rm \"$dest\") and re-run; the script will recreate it as a real dir." >&2
        exit 1
        ;;
    esac
  fi
  mkdir -p "$dest"
}

link_skill() {
  local src="$1" name="$2"
  for dest in "${DESTS[@]}"; do
    local target="$dest/$name"
    if [ "$dest" = "$CURSOR_DEST" ]; then
      # Cursor's slash-command picker does not follow symlinks; it needs real
      # dirs. Drop any prior symlink/dir and copy so the picker sees the skill.
      rm -rf "$target"
      cp -R "$src" "$target"
      printf '%s\n' "$REPO" > "$target/.linked-from"
      echo "copied $name -> $src ($dest)"
    else
      if [ -e "$target" ] && [ ! -L "$target" ]; then
        rm -rf "$target"
      fi
      ln -sfn "$src" "$target"
      echo "linked $name -> $src ($dest)"
    fi
  done
}

prune_stale() {
  local dest="$1"
  for target in "$dest"/*; do
    [[ -e "$target" || -L "$target" ]] || continue
    local name resolved
    name="$(basename "$target")"
    if [[ -L "$target" ]]; then
      # Plain readlink, not -f/-m: we link with absolute repo paths, so the
      # stored value is already what we want to match, and reading it does not
      # require the target to still exist. -f returns nothing once the target is
      # gone, and -m is GNU-only (it fails outright on macOS) — either way
      # `resolved` ends up empty and orphan links survive forever.
      resolved="$(readlink "$target" 2>/dev/null || true)"
      case "$resolved" in
        "$REPO"/skills/deprecated/*|"$REPO"/skills/*/deprecated/*)
          rm "$target"
          echo "removed deprecated $name ($dest)"
          ;;
        "$REPO"/skills/misc/*)
          rm "$target"
          echo "removed misc $name ($dest)"
          ;;
        "$REPO"/*)
          if [[ ! -f "$resolved/SKILL.md" ]]; then
            rm "$target"
            echo "removed orphan $name ($dest)"
          elif ! skill_path_active "$resolved"; then
            rm "$target"
            echo "removed inactive $name ($dest)"
          fi
          ;;
      esac
    elif [[ "$dest" = "$CURSOR_DEST" && -d "$target" && -f "$target/SKILL.md" ]]; then
      # Cursor copies are real dirs, not symlinks: stale if the name is not an
      # active repo skill. Restrict to dirs holding a SKILL.md that this script
      # owns: stamped with a .linked-from marker naming this repo, or (older
      # copies made before the marker existed) unstamped but named after a repo
      # skill. Dirs whose marker points outside this repo belong to another
      # repo's linker (e.g. agent-console's scripts/link-skills.sh), and
      # unstamped dirs with unknown names are the user's own: both are left
      # alone.
      local from="" owned=0
      if [ -f "$target/.linked-from" ]; then
        from="$(cat "$target/.linked-from")"
      fi
      case "$from" in
        "$REPO"|"$REPO"/*) owned=1 ;;
        "") grep -qxF "$name" <<<"$ALL_NAMES" && owned=1 ;;
      esac
      if (( owned )) && ! grep -qxF "$name" <<<"$ACTIVE_NAMES"; then
        rm -rf "$target"
        echo "removed stale $name ($dest)"
      fi
    fi
  done
  for name in github-triage triage-issue; do
    local target="$dest/$name"
    if [ -L "$target" ]; then
      rm "$target"
      echo "removed alias $name ($dest)"
    fi
  done
}

for dest in "${DESTS[@]}"; do
  guard_dest "$dest"
  prune_stale "$dest"
done

for skill_md in "${ACTIVE_SKILL_MDS[@]}"; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  link_skill "$src" "$name"
done

# Agents: symlink the active set's vendored agents into ~/.claude/agents and
# drop symlinks into this repo that are inactive or dangling. Regular files
# there are the user's own and are never touched.
mkdir -p "$AGENTS_DEST"
for target in "$AGENTS_DEST"/*; do
  [[ -L "$target" ]] || continue
  resolved="$(readlink "$target" 2>/dev/null || true)"
  case "$resolved" in
    "$REPO"/*)
      if [[ ! -f "$resolved" ]] || ! skill_path_active "$resolved"; then
        rm "$target"
        echo "removed agent $(basename "$target") ($AGENTS_DEST)"
      fi
      ;;
  esac
done
while IFS= read -r -d '' agent_md; do
  skill_path_active "$agent_md" || continue
  target="$AGENTS_DEST/$(basename "$agent_md")"
  if [[ -e "$target" && ! -L "$target" ]]; then
    echo "skipped agent $(basename "$agent_md"): $target is not a symlink ($AGENTS_DEST)" >&2
    continue
  fi
  ln -sfn "$agent_md" "$target"
  echo "linked agent $(basename "$agent_md") -> $agent_md ($AGENTS_DEST)"
done < <(all_agent_mds)
