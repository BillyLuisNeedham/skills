#!/usr/bin/env bash
# Sync skills from mattpocock + android + gcp + addy + pstack + vendored
# third-party skills into this fork.
# Idempotent: re-run any time to refresh.
#
# What it does:
#   1. Pulls mattpocock/skills (upstream) into this fork.
#   2. Clones android/skills and copies each skill dir into skills/android/ with
#      `android-` prefix.
#   3. Clones google/skills and copies each skill dir into skills/gcp/ with
#      `gcp-` prefix.
#   4. Clones addyosmani/agent-skills into skills/addy/ (`addy-` prefix) and the
#      pstack plugin from cursor/plugins into skills/pstack/ (`pstack-` prefix),
#      copying each one's agents into skills/<bucket>/agents/ and rewriting
#      references to the bucket's own skills and agents to the prefixed names.
#      Shared docs addy's skills link to outside their own dir (its top-level
#      references/) are copied into each linking skill and the links rewritten.
#   5. Vendors individual third-party skills into skills/personal/, overwriting
#      each one every run: thermo-nuclear-code-quality-review from cursor/plugins,
#      and the six Effective HTML skills from plannotator/effective-html (patched
#      to be user-invoked after each copy).
#   6. Removes any previously-synced skill that no longer exists upstream, plus
#      legacy flat gcp-*/android-* dirs left at the repo root by older syncs.
#   7. Regenerates each synced bucket's README.md (gcp, android, addy, pstack).
#   8. On a directory collision that we don't recognise as previously-synced,
#      prompts (o)verwrite / (s)kip / (a)bort.
#   9. Links the active skill set (see scripts/use-skills.sh) plus the always-on
#      buckets into ~/.claude/skills, ~/.agents/skills and ~/.cursor/skills, and
#      the active set's agents into ~/.claude/agents, via scripts/link-skills.sh.
#      Inactive sets stay unlinked.
#  10. Generates an OpenCode slash-command stub per active skill via
#      scripts/link-opencode-commands.sh (no-op if OpenCode isn't installed).
#  11. Commits and pushes to origin.

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

# sync_source <prefix> <repo_url> [subpath] [agents_subpath] [shared_refs_subpath]
# Copies every skill dir (one holding a SKILL.md) under <subpath> of the repo
# into skills/<prefix>/<prefix>-<name>/. With [agents_subpath], also copies
# each <agents_subpath>/*.md into skills/<prefix>/agents/<prefix>-<name>.md,
# rewriting its frontmatter `name:` to the prefixed name (an agent is
# addressed by that field, not its file name). The agents/ dir holds no
# SKILL.md, so the manifest, stale sweep, README skill list and link-skills.sh
# all pass over it; it is wiped and re-copied every run. With
# [shared_refs_subpath], pulls the shared docs skills link to there into each
# skill (see vendor_shared_refs).
sync_source() {
  local prefix="$1" repo_url="$2"
  local subpath="${3:-}" agents_subpath="${4:-}" shared_refs_subpath="${5:-}"

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

  if [[ -n "$agents_subpath" ]]; then
    sync_agents "$prefix" "$clone_dir/$agents_subpath"
  fi

  if [[ -n "$shared_refs_subpath" ]]; then
    vendor_shared_refs "$prefix" "$clone_dir/$shared_refs_subpath" "$shared_refs_subpath"
  fi

  regenerate_bucket_readme "$prefix" "$repo_url"
}

# vendor_shared_refs <prefix> <src_dir> <subpath>
# Upstream skills sit at <repo>/skills/<name>/ and link to shared docs at the
# repo's top level as ../../<subpath>/<file> (one more ../ per level deeper the
# linking file sits). A skill is installed as a symlink to, or a copy of, its
# own dir, so a link out of that dir dangles. For each skill, copies every such
# file it actually links to into its own references/ dir and rewrites the link
# to resolve from the file holding it (`references/<file>` from SKILL.md,
# `<file>` from inside references/). Upstream's own references/ files are left
# alone: a name clash with one that differs is reported and its link kept.
# Idempotent: a rewritten link no longer escapes the skill dir, so never
# matches again.
vendor_shared_refs() {
  local prefix="$1" src_dir="$2" subpath="$3"
  local skill_dir md slashes up name src dest rel
  for skill_dir in "$REPO_DIR/skills/$prefix"/"$prefix"-*/; do
    skill_dir="${skill_dir%/}"
    while IFS= read -r -d '' md; do
      slashes="${md#"$skill_dir"/}"
      slashes="${slashes//[!\/]/}"
      up="$(printf '../%.0s' $(seq 1 $(( ${#slashes} + 2 ))))$subpath/"
      while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        src="$src_dir/$name"
        dest="$skill_dir/references/$name"
        if [[ ! -f "$src" ]]; then
          echo "    ! $(basename "$skill_dir"): $up$name not found upstream (link kept)" >&2
          continue
        fi
        if [[ -e "$dest" ]] && ! cmp -s "$src" "$dest"; then
          echo "    ! $(basename "$skill_dir"): references/$name already exists and differs (link kept)" >&2
          continue
        fi
        mkdir -p "$skill_dir/references"
        cp "$src" "$dest"
        rel="$(realpath -m --relative-to="$(dirname "$md")" "$dest")"
        UP="$up" NAME="$name" REL="$rel" perl -pi -e \
          's{(?<![./])\Q$ENV{UP}$ENV{NAME}\E(?![A-Za-z0-9._-])}{$ENV{REL}}g' "$md"
        echo "    ~ $(basename "$skill_dir"): vendored $subpath/$name"
      done < <(UP="$up" perl -ne \
        'print "$1\n" while m{(?<![./])\Q$ENV{UP}\E([A-Za-z0-9._-]+\.md)(?![A-Za-z0-9._-])}g' "$md" | sort -u)
    done < <(find "$skill_dir" -type f -name '*.md' -print0)
  done
}

# Copies <src_dir>/*.md into skills/<prefix>/agents/ as <prefix>-<name>.md with
# the frontmatter `name:` prefixed to match. Replaces the whole agents/ dir, so
# an agent dropped upstream disappears here too.
sync_agents() {
  local prefix="$1" src_dir="$2"
  local dest="$REPO_DIR/skills/$prefix/agents"
  rm -rf "$dest"
  if [[ ! -d "$src_dir" ]]; then
    echo "    ! agents path not found: $src_dir (skipping)" >&2
    return 0
  fi
  mkdir -p "$dest"
  local src name target
  for src in "$src_dir"/*.md; do
    [[ -e "$src" ]] || continue
    name="$(basename "$src" .md)"
    target="$dest/$prefix-$name.md"
    cp "$src" "$target"
    PREFIX="$prefix" perl -0pi -e \
      's/\A(---\n(?:.*\n)*?)name:[ \t]*(?!\Q$ENV{PREFIX}\E-)(\S+)[ \t]*\n/$1name: $ENV{PREFIX}-$2\n/' "$target"
    echo "    + agents/$prefix-$name.md"
  done
}

# Rewrites references to a bucket's own skills and agents to their prefixed
# names, across every .md file in skills/<prefix>/ (SKILL.md, playbooks,
# references, agents). Run after each sync, since the sync re-copies the
# upstream files verbatim. Only these forms are touched, so plain prose words
# that happen to be skill names (pstack has `how`, `why`, `bro`, `tdd`) stay:
#   - `/name` as a slash command: preceded by start of line, whitespace, or one
#     of ( [ ` " ' and followed by anything but [A-Za-z0-9_/-], so paths like
#     `skills/tdd/` or `a/b` never match
#   - `name` wrapped in backticks, exactly
#   - ../name/ in a relative link, since the target dir was renamed
#   - bare principle-* tokens that are skill names (pstack's principle skills)
# Frontmatter `name:` lines are skipped: skill names stay unprefixed, as for
# gcp/ and android/, and sync_agents already prefixed the agents' ones.
# Idempotent: a prefixed reference is never a match for the bare name.
# Regenerates the bucket README afterwards so its descriptions match.
rewrite_bucket_refs() {
  local prefix="$1" repo_url="$2"
  local bucket_dir="$REPO_DIR/skills/$prefix"
  local -a names=()
  local entry
  for entry in "$bucket_dir"/"$prefix"-*/SKILL.md "$bucket_dir"/agents/"$prefix"-*.md; do
    [[ -e "$entry" ]] || continue
    if [[ "$(basename "$entry")" == SKILL.md ]]; then
      entry="$(basename "$(dirname "$entry")")"
    else
      entry="$(basename "$entry" .md)"
    fi
    names+=("${entry#"$prefix"-}")
  done
  (( ${#names[@]} > 0 )) || return 0

  find "$bucket_dir" -type f -name '*.md' -not -path "$bucket_dir/README.md" -print0 \
    | PREFIX="$prefix" NAMES="${names[*]}" xargs -0 perl -pi -e '
        BEGIN {
          my @n = sort { length($b) <=> length($a) } split / /, $ENV{NAMES};
          my $all = join "|", map { quotemeta } @n;
          my $principles = join "|", map { quotemeta } grep { /^principle-/ } @n;
          $p = $ENV{PREFIX};
          $any = qr/(?:$all)/;
          $pr = $principles eq "" ? qr/(?!)/ : qr/(?:$principles)/;
        }
        next if /^name:\s/;
        s{(?<![^\s(\[`"\x27])/($any)(?![A-Za-z0-9_/-])}{/$p-$1}g;
        s{`($any)`}{`$p-$1`}g;
        s{(?<=\.\./)($any)(?=/)}{$p-$1}g;
        s{(?<![A-Za-z0-9_/-])($pr)(?![A-Za-z0-9_-])}{$p-$1}g;
      '
  echo "    ~ rewrote own skill and agent references in skills/$prefix/"
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
    addy) title="Addy Osmani agent" ;;
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
    if compgen -G "$bucket_dir/agents/*.md" >/dev/null; then
      echo ""
      echo "## Agents"
      echo ""
      echo "Subagents synced alongside the skills into \`agents/\`; \`scripts/link-skills.sh\` links them into \`~/.claude/agents\` while this bucket's skill set is active."
      echo ""
      local agent_md
      for agent_md in "$bucket_dir"/agents/*.md; do
        name="$(basename "$agent_md" .md)"
        desc="$(skill_first_sentence "$agent_md")"
        if [[ -z "$desc" ]]; then
          echo "- [$name](./agents/$name.md)"
        else
          echo "- [$name](./agents/$name.md): $desc"
        fi
      done
    fi
  } > "$readme"
  echo "    wrote skills/$label/README.md"
}

# Vendor one or more named skills from a third-party repo into skills/personal/,
# keeping their original names. Clones the repo once. Overwrites each target
# every run, so local edits to a vendored skill are destroyed on the next sync.
sync_single_skill() {
  local repo_url="$1"
  shift
  local clone_dir
  clone_dir="$TMP_DIR/personal-$(basename "$repo_url" .git)"

  echo "==> Syncing personal skills from $repo_url"
  [[ -d "$clone_dir" ]] || git clone --depth 1 --quiet "$repo_url" "$clone_dir"

  local skill_subpath skill_name target src
  for skill_subpath in "$@"; do
    skill_name="$(basename "$skill_subpath")"
    target="$REPO_DIR/skills/personal/$skill_name"
    src="$clone_dir/$skill_subpath"
    if [[ ! -d "$src" ]]; then
      echo "    ! source path not found: $skill_subpath (skipping)" >&2
      continue
    fi

    rm -rf "$target"
    cp -r "$src" "$target"
    echo "    + skills/personal/$skill_name"
  done
}

# Make a vendored skill user-invoked (see .agents/invocation.md): add
# `disable-model-invocation: true` to its frontmatter and turn off
# `allow_implicit_invocation` in agents/openai.yaml. Run after each sync,
# since the sync re-copies the upstream files verbatim.
make_user_invoked() {
  local skill_dir="$REPO_DIR/skills/personal/$1"
  local skill_md="$skill_dir/SKILL.md" openai_yaml="$skill_dir/agents/openai.yaml"
  [[ -f "$skill_md" ]] || return 0

  if ! grep -q '^disable-model-invocation:' "$skill_md"; then
    perl -0pi -e 's/\A(---\n(?:.*\n)*?)---\n/$1disable-model-invocation: true\n---\n/' "$skill_md"
  fi

  if [[ -f "$openai_yaml" ]]; then
    if grep -q 'allow_implicit_invocation:' "$openai_yaml"; then
      perl -pi -e 's/allow_implicit_invocation:\s*true/allow_implicit_invocation: false/' "$openai_yaml"
    else
      printf '\npolicy:\n  allow_implicit_invocation: false\n' >> "$openai_yaml"
    fi
  fi
  echo "    ~ skills/personal/$1 is user-invoked"
}

cd "$REPO_DIR"

ensure_remote upstream "https://github.com/mattpocock/skills.git"

echo "==> Fetching upstream (mattpocock/skills)..."
git fetch --quiet upstream main

echo "==> Merging upstream/main..."
git merge --no-edit upstream/main

sync_source "android" "https://github.com/android/skills.git"
sync_source "gcp"     "https://github.com/google/skills.git" "skills"
ADDY_URL="https://github.com/addyosmani/agent-skills.git"
PSTACK_URL="https://github.com/cursor/plugins.git"
sync_source "addy"    "$ADDY_URL"   "skills"        "agents"        "references"
rewrite_bucket_refs "addy" "$ADDY_URL"
sync_source "pstack"  "$PSTACK_URL" "pstack/skills" "pstack/agents"
rewrite_bucket_refs "pstack" "$PSTACK_URL"

sync_single_skill "https://github.com/cursor/plugins.git" "cursor-team-kit/skills/thermo-nuclear-code-quality-review"

EFFECTIVE_HTML_SKILLS=(html design-artifact html-wireframe html-prototype html-plan html-diagram)
sync_single_skill "https://github.com/plannotator/effective-html.git" "${EFFECTIVE_HTML_SKILLS[@]/#/skills/}"
for s in "${EFFECTIVE_HTML_SKILLS[@]}"; do make_user_invoked "$s"; done

echo "==> Linking the active skill set ($(cat "$REPO_DIR/.skill-set" 2>/dev/null || echo pocock)) to ~/.claude/skills, ~/.agents/skills, ~/.cursor/skills and ~/.claude/agents..."
bash "$REPO_DIR/scripts/link-skills.sh"

echo "==> Generating OpenCode slash commands..."
bash "$REPO_DIR/scripts/link-opencode-commands.sh"

echo "==> Committing and pushing fork..."
git add -A
if git diff --cached --quiet; then
  echo "    (no changes to commit)"
else
  git commit -m "Sync skills: mattpocock + android + gcp + addy + pstack + cursor + effective-html"
  git push origin main
fi

echo ""
echo "Done."
