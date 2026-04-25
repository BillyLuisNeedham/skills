#!/usr/bin/env bash
# Sync skills from mattpocock + android + gcp into this fork.
# Idempotent — re-run any time to refresh.
#
# What it does:
#   1. Pulls mattpocock/skills (upstream) into this fork.
#   2. Clones android/skills and copies each skill dir flat with `android-` prefix.
#   3. Clones google/skills and copies each skill dir flat (under skills/) with `gcp-` prefix.
#   4. Removes any previously-synced skill that no longer exists upstream.
#   5. On a directory collision that we don't recognise as previously-synced,
#      prompts (o)verwrite / (s)kip / (a)bort.
#   6. Commits and pushes to origin.

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

cd "$REPO_DIR"

ensure_remote upstream "https://github.com/mattpocock/skills.git"

echo "==> Fetching upstream (mattpocock/skills)..."
git fetch --quiet upstream main

echo "==> Merging upstream/main..."
git merge --no-edit upstream/main

sync_source "android" "https://github.com/android/skills.git"
sync_source "gcp"     "https://github.com/google/skills.git" "skills"

echo "==> Committing and pushing fork..."
git add -A
if git diff --cached --quiet; then
  echo "    (no changes to commit)"
else
  git commit -m "Sync skills: mattpocock + android + gcp"
  git push origin main
fi

echo ""
echo "Done."
