#!/usr/bin/env bash
# Sync skills from mattpocock + android + gcp + vendored third-party skills into this fork.
# Idempotent: re-run any time to refresh.
#
# What it does:
#   1. Pulls mattpocock/skills (upstream) into this fork.
#   2. Clones android/skills and copies each skill dir into skills/android/ with
#      `android-` prefix.
#   3. Clones google/skills and copies each skill dir into skills/gcp/ with
#      `gcp-` prefix.
#   4. Vendors individual third-party skills into skills/personal/, overwriting
#      each one every run: thermo-nuclear-code-quality-review from cursor/plugins,
#      and show-me from humanlayer/skills.
#   5. Removes any previously-synced skill that no longer exists upstream, plus
#      legacy flat gcp-*/android-* dirs left at the repo root by older syncs.
#   6. Regenerates skills/gcp/README.md and skills/android/README.md.
#   7. On a directory collision that we don't recognise as previously-synced,
#      prompts (o)verwrite / (s)kip / (a)bort.
#   8. Links every skill in the repo (except deprecated/) into ~/.claude/skills,
#      ~/.agents/skills and ~/.cursor/skills via scripts/link-skills.sh.
#   9. Generates an OpenCode slash-command stub per skill via
#      scripts/link-opencode-commands.sh (no-op if OpenCode isn't installed).
#  10. Commits and pushes to origin.

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

  mkdir -p "$REPO_DIR/skills/$prefix"

  while IFS= read -r -d '' skill_md; do
    local skill_dir skill_name target_name target
    skill_dir="$(dirname "$skill_md")"
    skill_name="$(basename "$skill_dir")"
    target_name="$prefix-$skill_name"
    target="$REPO_DIR/skills/$prefix/$target_name"

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
    if (( found == 0 )); then
      if [[ -d "$REPO_DIR/skills/$prefix/$old" ]]; then
        echo "    - $old (stale, removed)"
        rm -rf "$REPO_DIR/skills/$prefix/$old"
      fi
      if [[ -d "$REPO_DIR/$old" ]]; then
        echo "    - $old (legacy flat dir, removed)"
        rm -rf "$REPO_DIR/$old"
      fi
    fi
  done <<<"$previously_synced"

  # One-time migration cleanup, safe to keep permanently: sweep any remaining
  # flat `$prefix-*` dirs at the repo root left over from the pre-bucket layout.
  local legacy
  for legacy in "$REPO_DIR"/"$prefix"-*; do
    [[ -d "$legacy" ]] || continue
    echo "    - $(basename "$legacy") (legacy flat dir, removed)"
    rm -rf "$legacy"
  done

  write_manifest "$prefix" "${newly_synced[@]+"${newly_synced[@]}"}"

  regenerate_bucket_readme "$prefix" "$repo_url"
}

# Prints the first sentence of a SKILL.md frontmatter `description`, folded
# onto one line with quotes stripped and long sentences truncated sensibly.
# Prints nothing if the field is absent.
skill_first_sentence() {
  awk '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
    BEGIN { dq = sprintf("%c", 34); sq = sprintf("%c", 39) }
    NR == 1 { if ($0 !~ /^---[ \t\r]*$/) exit; next }
    /^(---|\.\.\.)[ \t\r]*$/ { exit }
    !capturing && /^description:/ {
      val = trim(substr($0, 13))
      if (val ~ /^[|>][0-9+-]*$/) val = ""   # block scalar header; body follows
      capturing = 1
      next
    }
    capturing {
      # Continuation lines are indented (or blank); anything at column 0 is the
      # next key.
      if ($0 ~ /^[ \t]/ || trim($0) == "") {
        line = trim($0)
        if (line != "") val = (val == "" ? line : val " " line)
        next
      }
      capturing = 0
    }
    END {
      gsub(/[\t\r]/, " ", val)
      gsub(/ +/, " ", val)
      val = trim(val)

      n = length(val)
      if (n >= 2) {
        first = substr(val, 1, 1); last = substr(val, n, 1)
        if (first == dq && last == dq) {
          val = substr(val, 2, n - 2)
        } else if (first == sq && last == sq) {
          val = substr(val, 2, n - 2)
        }
      }

      # First sentence: cut at the first period followed by whitespace.
      if (match(val, /\. [^ ]/)) val = substr(val, 1, RSTART)
      # Sensible truncation for one-sentence descriptions.
      if (length(val) > 200) val = trim(substr(val, 1, 197)) "..."
      print val
    }
  ' "$1"
}

# Regenerates skills/<label>/README.md: a flat list, one line per skill, linking
# to its SKILL.md with the first sentence of its frontmatter description.
# Generated by this script; do not hand-edit.
regenerate_bucket_readme() {
  local label="$1" repo_url="$2"
  local bucket_dir="$REPO_DIR/skills/$label"
  local readme="$bucket_dir/README.md"
  local title
  case "$label" in
    gcp) title="GCP" ;;
    android) title="Android" ;;
    *) title="$label" ;;
  esac

  {
    echo "# $title skills"
    echo ""
    echo "Skills synced from upstream ($repo_url), not promoted in the plugin. This file is generated by \`update-skills.sh\`; do not hand-edit."
    echo ""
    local skill_md name desc
    for skill_md in "$bucket_dir"/*/SKILL.md; do
      [[ -e "$skill_md" ]] || continue
      name="$(basename "$(dirname "$skill_md")")"
      desc="$(skill_first_sentence "$skill_md")"
      if [[ -z "$desc" ]]; then
        echo "- [$name](./$name/SKILL.md)"
      else
        echo "- [$name](./$name/SKILL.md): $desc"
      fi
    done
  } > "$readme"
  echo "    wrote skills/$label/README.md"
}

# Vendor a single named skill from a third-party repo into skills/personal/,
# keeping its original name. Overwrites the target each run, so local edits to
# a vendored skill are destroyed on the next sync.
sync_single_skill() {
  local repo_url="$1" skill_subpath="$2"
  local skill_name target
  skill_name="$(basename "$skill_subpath")"
  target="$REPO_DIR/skills/personal/$skill_name"

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
  echo "    + skills/personal/$skill_name"
}

cd "$REPO_DIR"

ensure_remote upstream "https://github.com/mattpocock/skills.git"

echo "==> Fetching upstream (mattpocock/skills)..."
git fetch --quiet upstream main

echo "==> Merging upstream/main..."
git merge --no-edit upstream/main

sync_source "android" "https://github.com/android/skills.git"
sync_source "gcp"     "https://github.com/google/skills.git" "skills"

sync_single_skill "https://github.com/cursor/plugins.git" "cursor-team-kit/skills/thermo-nuclear-code-quality-review"
sync_single_skill "https://github.com/humanlayer/skills.git" "plugins/show-me/skills/show-me"

echo "==> Linking skills to ~/.claude/skills, ~/.agents/skills and ~/.cursor/skills..."
bash "$REPO_DIR/scripts/link-skills.sh"

echo "==> Generating OpenCode slash commands..."
bash "$REPO_DIR/scripts/link-opencode-commands.sh"

echo "==> Committing and pushing fork..."
git add -A
if git diff --cached --quiet; then
  echo "    (no changes to commit)"
else
  git commit -m "Sync skills: mattpocock + android + gcp + cursor + humanlayer"
  git push origin main
fi

echo ""
echo "Done."
