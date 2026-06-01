#!/usr/bin/env bash
# Sync skills from mattpocock + android + gcp into this fork.
# Idempotent — re-run any time to refresh.
#
# What it does:
#   1. Pulls mattpocock/skills (upstream) into this fork.
#   2. Clones android/skills and copies each skill dir flat with `android-` prefix.
#   3. Clones google/skills and copies each skill dir flat (under skills/) with `gcp-` prefix.
#   4. Pulls the thermo-nuclear-code-quality-review skill from cursor/plugins into
#      skills/engineering/, overwriting it each run.
#   5. Removes any previously-synced skill that no longer exists upstream.
#   6. On a directory collision that we don't recognise as previously-synced,
#      prompts (o)verwrite / (s)kip / (a)bort.
#   7. Links every skill in the repo (except deprecated/) into
#      ~/.claude/skills and ~/.cursor/skills via scripts/link-skills.sh.
#   8. Commits and pushes to origin.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

ensure_remote() {
  local name="$1" url="$2"
  if ! git -C "$REPO_DIR" remote get-url "$name" &>/dev/null; then
    git -C "$REPO_DIR" remote add "$name" "$url"
    echo "Added remote: $name -> $url"
  fi
}

read_manifest() {
  local f="$REPO_DIR/.skills-sync-$1.list"
  [[ -f "$f" ]] && cat "$f" || true
}

write_manifest() {
  local src="$1"; shift
  local f="$REPO_DIR/.skills-sync-$src.list"
  if (( $# > 0 )); then
    printf "%s\n" "$@" | sort > "$f"
  else
    : > "$f"
  fi
}

prompt_collision() {
  local target="$1"
  echo "" >&2
  echo "Collision: $target exists and is not tracked as previously-synced." >&2
  while true; do
    read -rp "  (o)verwrite / (s)kip / (a)bort? " choice
    case "${choice,,}" in
      o) return 0 ;;
      s) return 1 ;;
      a) exit 1 ;;
    esac
  done
}

sync_source() {
  local prefix="$1" repo_url="$2"
  local subpath="${3:-}"

  echo "==> Syncing '$prefix' skills from $repo_url"
  local clone_dir="$TMP_DIR/$prefix"
  git clone --depth 1 --quiet "$repo_url" "$clone_dir"

  local search_root="$clone_dir"
  [[ -n "$subpath" ]] && search_root="$clone_dir/$subpath"

  local previously_synced
  previously_synced="$(read_manifest "$prefix")"

  local -a newly_synced=()

  while IFS= read -r -d '' skill_md; do
    local skill_dir skill_name target_name target
    skill_dir="$(dirname "$skill_md")"
    skill_name="$(basename "$skill_dir")"
    target_name="$prefix-$skill_name"
    target="$REPO_DIR/$target_name"

    if [[ -e "$target" ]]; then
      if ! grep -qx "$target_name" <<<"$previously_synced"; then
        if ! prompt_collision "$target"; then
          continue
        fi
      fi
      rm -rf "$target"
    fi

    cp -r "$skill_dir" "$target"
    echo "    + $target_name"
    newly_synced+=("$target_name")
  done < <(find "$search_root" -name SKILL.md -print0)

  while IFS= read -r old; do
    [[ -z "$old" ]] && continue
    local found=0
    for new in "${newly_synced[@]+"${newly_synced[@]}"}"; do
      [[ "$new" == "$old" ]] && { found=1; break; }
    done
    if (( found == 0 )) && [[ -d "$REPO_DIR/$old" ]]; then
      echo "    - $old (stale, removed)"
      rm -rf "$REPO_DIR/$old"
    fi
  done <<<"$previously_synced"

  write_manifest "$prefix" "${newly_synced[@]+"${newly_synced[@]}"}"
}

# Sync a single named skill into skills/engineering/, keeping its original name.
# Overwrites the target each run so we always pull the latest version.
sync_personal_skill() {
  local repo_url="$1" skill_subpath="$2"
  local skill_name target
  skill_name="$(basename "$skill_subpath")"
  target="$REPO_DIR/skills/engineering/$skill_name"

  echo "==> Syncing personal skill '$skill_name' from $repo_url"
  local clone_dir="$TMP_DIR/personal-$skill_name"
  git clone --depth 1 --quiet "$repo_url" "$clone_dir"

  local src="$clone_dir/$skill_subpath"
  if [[ ! -d "$src" ]]; then
    echo "    ! source path not found: $skill_subpath (skipping)" >&2
    return 0
  fi

  rm -rf "$target"
  cp -r "$src" "$target"
  echo "    + skills/engineering/$skill_name"
}

cd "$REPO_DIR"

ensure_remote upstream "https://github.com/mattpocock/skills.git"

echo "==> Fetching upstream (mattpocock/skills)..."
git fetch --quiet upstream main

echo "==> Merging upstream/main..."
git merge --no-edit upstream/main

sync_source "android" "https://github.com/android/skills.git"
sync_source "gcp"     "https://github.com/google/skills.git" "skills"

sync_personal_skill "https://github.com/cursor/plugins.git" "cursor-team-kit/skills/thermo-nuclear-code-quality-review"

echo "==> Linking skills to ~/.claude/skills and ~/.cursor/skills..."
bash "$REPO_DIR/scripts/link-skills.sh"

echo "==> Committing and pushing fork..."
git add -A
if git diff --cached --quiet; then
  echo "    (no changes to commit)"
else
  git commit -m "Sync skills: mattpocock + android + gcp + cursor"
  git push origin main
fi

echo ""
echo "Done."
