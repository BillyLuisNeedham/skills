#!/usr/bin/env bash
set -euo pipefail

# Links every skill in this repo (SKILL.md, excluding deprecated/) to
# ~/.claude/skills and ~/.cursor/skills for local agents.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
CURSOR_DEST="$HOME/.cursor/skills"
DESTS=("$HOME/.claude/skills" "$CURSOR_DEST")

# Names of current (non-deprecated) repo skills, one per line.
repo_skill_names() {
  find "$REPO" -name SKILL.md \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/deprecated/*' \
    -print0 | while IFS= read -r -d '' skill_md; do
      basename "$(dirname "$skill_md")"
    done
}
VALID_NAMES="$(repo_skill_names)"

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
      resolved="$(readlink -f "$target" 2>/dev/null || true)"
      case "$resolved" in
        "$REPO"/skills/deprecated/*|"$REPO"/skills/*/deprecated/*)
          rm "$target"
          echo "removed deprecated $name ($dest)"
          ;;
        "$REPO"/*)
          if [[ ! -f "$resolved/SKILL.md" ]]; then
            rm "$target"
            echo "removed orphan $name ($dest)"
          fi
          ;;
      esac
    elif [[ "$dest" = "$CURSOR_DEST" && -d "$target" && -f "$target/SKILL.md" ]]; then
      # Cursor copies are real dirs, not symlinks: stale if the name is no
      # longer a current repo skill. Restrict to dirs holding a SKILL.md so we
      # never touch unrelated Cursor content.
      if ! grep -qxF "$name" <<<"$VALID_NAMES"; then
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

while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  link_skill "$src" "$name"
done < <(
  find "$REPO" -name SKILL.md \
    -not -path '*/node_modules/*' \
    -not -path '*/.git/*' \
    -not -path '*/deprecated/*' \
    -print0
)
