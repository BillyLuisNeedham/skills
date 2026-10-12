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
#      addy's Claude Code slash commands (.claude/commands/*.md) become
#      user-invoked skills (addy-build, addy-spec, ...). In every synced
#      bucket, relative links that leave a skill or agent are re-pointed at the
#      renamed sibling or at the upstream file on GitHub.
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

# sync_source <prefix> <repo_url> [subpath] [agents_subpath] [shared_refs_subpath] [commands_subpath]
# Copies every skill dir (one holding a SKILL.md) under <subpath> of the repo
# into skills/<prefix>/<prefix>-<name>/. With [agents_subpath], also copies
# each <agents_subpath>/*.md into skills/<prefix>/agents/<prefix>-<name>.md,
# rewriting its frontmatter `name:` to the prefixed name (an agent is
# addressed by that field, not its file name). The agents/ dir holds no
# SKILL.md, so the manifest, stale sweep, README skill list and link-skills.sh
# all pass over it; it is wiped and re-copied every run. With
# [shared_refs_subpath], pulls the shared docs skills link to there into each
# skill (see vendor_shared_refs). With [commands_subpath], turns each Claude
# Code slash command there into a user-invoked skill (see command_to_skill),
# tracked in the manifest like any other synced skill. Finally, relative links
# that leave a skill or agent are re-pointed (see rewrite_escaping_links).
sync_source() {
  local prefix="$1" repo_url="$2"
  local subpath="${3:-}" agents_subpath="${4:-}" shared_refs_subpath="${5:-}"
  local commands_subpath="${6:-}"

  echo "==> Syncing '$prefix' skills from $repo_url"
  local clone_dir="$TMP_DIR/$prefix"
  git clone --depth 1 --quiet "$repo_url" "$clone_dir"

  local search_root="$clone_dir"
  [[ -n "$subpath" ]] && search_root="$clone_dir/$subpath"

  local previously_synced
  previously_synced="$(read_manifest "$prefix")"

  local -a newly_synced=()
  # Local path (relative to the bucket) <TAB> upstream path (relative to the
  # clone) of everything copied, for rewrite_escaping_links.
  local link_map="$TMP_DIR/$prefix.map"
  : > "$link_map"

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
    printf '%s\t%s\n' "$target_name" "${skill_dir#"$clone_dir"/}" >> "$link_map"
  done < <(find "$search_root" -name SKILL.md -print0)

  if [[ -n "$commands_subpath" ]]; then
    local cmd_md cmd_name
    for cmd_md in "$clone_dir/$commands_subpath"/*.md; do
      [[ -e "$cmd_md" ]] || continue
      cmd_name="$(basename "$cmd_md" .md)"
      target_name="$prefix-$cmd_name"
      target="$REPO_DIR/skills/$prefix/$target_name"
      if printf '%s\n' "${newly_synced[@]+"${newly_synced[@]}"}" | grep -qxF "$target_name"; then
        echo "    ! command /$cmd_name clashes with upstream skill $target_name (command skipped)" >&2
        continue
      fi
      if [[ -e "$target" ]]; then
        if ! grep -qx "$target_name" <<<"$previously_synced"; then
          if ! prompt_collision "$target"; then
            continue
          fi
        fi
        rm -rf "$target"
      fi
      command_to_skill "$prefix" "$cmd_md" "$target" "$commands_subpath/$cmd_name.md"
      echo "    + $target_name (from command /$cmd_name)"
      newly_synced+=("$target_name")
      printf '%s\t%s\n' "$target_name/SKILL.md" "$commands_subpath/$cmd_name.md" >> "$link_map"
    done
  fi

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
    sync_agents "$prefix" "$clone_dir/$agents_subpath" "$agents_subpath" "$link_map"
  fi

  if [[ -n "$shared_refs_subpath" ]]; then
    vendor_shared_refs "$prefix" "$clone_dir/$shared_refs_subpath" "$shared_refs_subpath"
  fi

  rewrite_escaping_links "$prefix" "$clone_dir" "$repo_url" "$link_map"

  regenerate_bucket_readme "$prefix" "$repo_url"
}

# command_to_skill <prefix> <command_md> <target_dir> <upstream_path>
# Turns an upstream Claude Code slash command (<repo>/.claude/commands/<cmd>.md)
# into the skill <target_dir>/SKILL.md: frontmatter `name: <cmd>` (unprefixed,
# like every synced skill; the dir carries the prefix) ahead of upstream's own
# keys, a generated marker that rewrite_bucket_refs keys on, and the body as
# upstream wrote it, with plugin-qualified skill references such as
# `agent-skills:spec-driven-development` turned into the prefixed skill name.
# `$ARGUMENTS` is left alone: Claude Code substitutes it in skills as it does
# in commands. The skill is then made user-invoked (a slash command is only
# ever fired by the human), with an agents/openai.yaml carrying the matching
# Codex policy.
command_to_skill() {
  local prefix="$1" src="$2" target="$3" upstream="$4"
  local cmd_name skills_dir skill_names=""
  cmd_name="$(basename "$src" .md)"
  skills_dir="$(dirname "$target")"
  local entry
  for entry in "$skills_dir"/"$prefix"-*/SKILL.md; do
    [[ -e "$entry" ]] || continue
    entry="$(basename "$(dirname "$entry")")"
    skill_names="$skill_names ${entry#"$prefix"-}"
  done
  mkdir -p "$target/agents"
  PREFIX="$prefix" NAME="$cmd_name" UPSTREAM="$upstream" SKILLS="$skill_names" perl -0777 -ne '
    my $fm = "";
    if (s/\A---\n(.*?\n)?---[ \t]*\n//s) { $fm = defined $1 ? $1 : ""; }
    $fm =~ s/^name:.*\n//mg;
    my @n = sort { length($b) <=> length($a) } grep { length } split / /, $ENV{SKILLS};
    if (@n) {
      my $alt = join "|", map { quotemeta } @n;
      s{(?<![A-Za-z0-9_-])[A-Za-z0-9_-]+:($alt)(?![A-Za-z0-9_-])}{$ENV{PREFIX}-$1}g;
    }
    print "---\nname: $ENV{NAME}\n$fm---\n";
    print "<!-- generated by update-skills.sh from upstream $ENV{UPSTREAM} -->\n";
    print;
  ' "$src" > "$target/SKILL.md"
  printf 'interface:\n  display_name: "%s"\n\npolicy:\n  allow_implicit_invocation: false\n' \
    "$prefix $cmd_name" > "$target/agents/openai.yaml"
  make_user_invoked "$prefix/$(basename "$target")" >/dev/null
}

# rewrite_escaping_links <prefix> <clone_dir> <repo_url> <link_map>
# A skill is installed as a symlink to, or a copy of, its own dir (an agent as
# a symlink to its own file), so a relative markdown link that leaves it, or
# that never resolved after the copy, is re-pointed using where the linking
# file sat upstream (<link_map>, written by sync_source):
#   - a target inside another skill or agent synced into this bucket becomes a
#     relative link to its renamed copy (e.g. `../pstack-arena/SKILL.md`)
#   - any other target that exists upstream becomes an absolute GitHub URL of
#     that file (blob) or dir (tree) on the branch that was cloned
#   - a target missing upstream too is reported and left as is
# Links that already resolve inside the linking skill or agent, and absolute
# or anchor-only links, are left alone. Runs after vendor_shared_refs, so the
# shared docs it vendors stay local, and before rewrite_bucket_refs, whose URL
# guard then leaves the new URLs alone.
rewrite_escaping_links() {
  local prefix="$1" clone_dir="$2" repo_url="$3" link_map="$4"
  local bucket_dir="$REPO_DIR/skills/$prefix"
  local web_base branch
  web_base="${repo_url%.git}"
  branch="$(git -C "$clone_dir" rev-parse --abbrev-ref HEAD)"
  [[ -s "$link_map" ]] || return 0
  find "$bucket_dir" -type f -name '*.md' -not -path "$bucket_dir/README.md" -print0 \
    | BUCKET="$bucket_dir" CLONE="$clone_dir" MAP="$link_map" WEB="$web_base/blob/$branch" \
      WEBTREE="$web_base/tree/$branch" xargs -0 perl -i -pe '
        BEGIN {
          use File::Spec;
          sub norm {
            my @out;
            for (split m{/}, shift) {
              next if $_ eq "" || $_ eq ".";
              if ($_ eq "..") { return undef unless @out; pop @out } else { push @out, $_ }
            }
            return "/" . join "/", @out;
          }
          sub under { my ($p, $root) = @_; $p eq $root || index($p, "$root/") == 0 }
          @map = ();
          open my $fh, "<", $ENV{MAP} or die "$ENV{MAP}: $!";
          while (<$fh>) {
            chomp; my ($loc, $up) = split /\t/;
            my $l = "$ENV{BUCKET}/$loc";
            # A file entry (agent, generated command skill) is rooted at the
            # file itself, or at its skill dir for a generated SKILL.md.
            my $root = -d $l ? $l : ($loc =~ m{/SKILL\.md$} ? (File::Spec->splitpath($l))[1] =~ s{/$}{}r : $l);
            push @map, { loc => $l, up => "$ENV{CLONE}/$up", root => $root };
          }
          close $fh;
        }
        if ($. == 1) {
          my $f = File::Spec->rel2abs($ARGV);
          ($entry) = grep { under($f, $_->{loc}) || ($_->{root} ne $_->{loc} && under($f, $_->{root})) } @map;
          $file = $f;
          $up_file = $entry ? $entry->{up} . substr($f, length($entry->{loc})) : undef;
          $up_file = $entry->{up} if $entry && $entry->{root} ne $entry->{loc} && $f eq $entry->{loc};
        }
        if ($entry) {
          s{(\]\()([^)\s]+)}{
            my ($pre, $t) = ($1, $2);
            my $out = $t;
            # Skip absolute, anchor-only and scheme links, and placeholders
            # such as `(url)` that name no path at all.
            unless ($t =~ m{^(?:[A-Za-z][A-Za-z0-9+.-]*:|#|/|<)} || $t !~ m{[./]}) {
              my ($path, $frag) = $t =~ m{^([^#]*)(#.*)?$};
              $frag //= "";
              my $dir = ($file =~ s{/[^/]*$}{}r);
              my $local = norm("$dir/$path");
              my $ok = defined $local && -e $local && grep { under($local, $_->{root}) } @map;
              unless ($ok) {
                my $updir = ($up_file =~ s{/[^/]*$}{}r);
                my $up = norm("$updir/$path");
                if (defined $up && under($up, $ENV{CLONE}) && -e $up) {
                  my ($hit) = grep { under($up, $_->{up}) } @map;
                  if ($hit) {
                    my $dest = $hit->{loc} . substr($up, length($hit->{up}));
                    $dest = $hit->{loc} if $hit->{root} ne $hit->{loc};
                    $out = File::Spec->abs2rel($dest, $dir) . $frag;
                  } else {
                    my $rel = substr($up, length($ENV{CLONE}) + 1);
                    $out = (-d $up ? $ENV{WEBTREE} : $ENV{WEB}) . "/$rel$frag";
                  }
                } else {
                  print STDERR "    ! " . File::Spec->abs2rel($file, $ENV{BUCKET}) . ": link $t resolves nowhere (kept)\n";
                }
              }
            }
            "$pre$out";
          }ge;
        }
        close ARGV if eof;
      '
  echo "    ~ re-pointed links leaving skills/$prefix/ skills and agents"
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
  local prefix="$1" src_dir="$2" agents_subpath="${3:-}" link_map="${4:-}"
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
    if [[ -n "$link_map" ]]; then
      printf '%s\t%s\n' "agents/$prefix-$name.md" "$agents_subpath/$name.md" >> "$link_map"
    fi
  done
}

# rewrite_bucket_refs <prefix> <repo_url> [keep_literal...]
# Rewrites references to a bucket's own skills and agents to their prefixed
# names, across every .md file in skills/<prefix>/ (SKILL.md, playbooks,
# references, agents). Run after each sync, since the sync re-copies the
# upstream files verbatim. Only these forms are touched, so plain prose words
# that happen to be skill names (pstack has `how`, `why`, `bro`, `tdd`) stay:
#   - `/name` as a slash command: preceded by start of line, whitespace, or one
#     of ( [ ` " ' and followed by anything but [A-Za-z0-9_/-], so `a/b` never
#     matches
#   - `name` wrapped in backticks, exactly
#   - ../name/ in a relative link, since the target dir was renamed
#   - a skills/name or agents/name.md path segment, so plain-text paths such
#     as skills/poteto-mode/playbooks/x.md name what is installed
#   - a bare whole-token name, only when it holds a hyphen
#     (spec-driven-development, code-reviewer): not preceded by a word
#     character, - / # or ., and not followed by a word character or -.
#     Single-word names are never rewritten bare.
# Skills generated from slash commands (command_to_skill) are matched only as
# `/name`, skills/name and ../name/: their names (build, test, plan) are too
# common to rewrite in backticks or bare.
# Frontmatter `name:` lines and http(s) URLs are skipped: skill names stay
# unprefixed, as for gcp/ and android/, sync_agents already prefixed the
# agents' ones, and URLs point at upstream. Each [keep_literal] is an exact
# upstream string left untouched wherever it appears, for the odd spot where a
# name is meant as a plain word (pstack's list of banned words includes `arena`).
# Idempotent: a prefixed reference is never a match for the bare name.
# Regenerates the bucket README afterwards so its descriptions match.
rewrite_bucket_refs() {
  local prefix="$1" repo_url="$2"
  shift 2
  local keep=""
  (( $# > 0 )) && keep="$(printf '%s\x1f' "$@")"
  local bucket_dir="$REPO_DIR/skills/$prefix"
  local -a names=() commands=() agents=()
  local entry name
  for entry in "$bucket_dir"/"$prefix"-*/SKILL.md "$bucket_dir"/agents/"$prefix"-*.md; do
    [[ -e "$entry" ]] || continue
    if [[ "$(basename "$entry")" == SKILL.md ]]; then
      name="$(basename "$(dirname "$entry")")"
      name="${name#"$prefix"-}"
      if grep -q '^<!-- generated by update-skills.sh from upstream ' "$entry"; then
        commands+=("$name")
      fi
    else
      name="$(basename "$entry" .md)"
      name="${name#"$prefix"-}"
      agents+=("$name")
    fi
    names+=("$name")
  done
  (( ${#names[@]} > 0 )) || return 0

  find "$bucket_dir" -type f -name '*.md' -not -path "$bucket_dir/README.md" -print0 \
    | PREFIX="$prefix" NAMES="${names[*]}" COMMANDS="${commands[*]+"${commands[*]}"}" \
      AGENTS="${agents[*]+"${agents[*]}"}" KEEP="$keep" xargs -0 perl -pi -e '
        BEGIN {
          sub alt {
            my @n = sort { length($b) <=> length($a) } @_;
            return qr/(?!)/ unless @n;
            my $a = join "|", map { quotemeta } @n;
            return qr/(?:$a)/;
          }
          my %cmd = map { $_ => 1 } split / /, $ENV{COMMANDS};
          my @all = split / /, $ENV{NAMES};
          my @named = grep { !$cmd{$_} } @all;
          $p = $ENV{PREFIX};
          $any = alt(@all);
          $named = alt(@named);
          $hyphenated = alt(grep { /-/ } @named);
          $agent = alt(split / /, $ENV{AGENTS});
          @keep = grep { length } split /\x1f/, $ENV{KEEP};
        }
        next if /^name:\s/;
        my @held;
        my $hold = sub { push @held, $_[0]; "\x00" . $#held . "\x00" };
        for my $k (@keep) { s/\Q$k\E/$hold->($k)/ge }
        s{(https?://[^\s<>()\[\]"\x27`]+)}{$hold->($1)}ge;
        s{(?<![^\s(\[`"\x27])/($any)(?![A-Za-z0-9_/-])}{/$p-$1}g;
        s{`($named)`}{`$p-$1`}g;
        s{(?<=\.\./)($any)(?=/)}{$p-$1}g;
        s{(?<![A-Za-z0-9_-])skills/($any)(?![A-Za-z0-9_-])}{skills/$p-$1}g;
        s{(?<![A-Za-z0-9_-])agents/($agent)(?=\.md)}{agents/$p-$1}g;
        s{(?<![A-Za-z0-9_/#.-])($hyphenated)(?![A-Za-z0-9_-])}{$p-$1}g;
        1 while s{\x00(\d+)\x00}{$held[$1]}g;
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

# make_user_invoked <bucket>/<skill>
# Make a vendored skill user-invoked (see .agents/invocation.md): add
# `disable-model-invocation: true` to its frontmatter and turn off
# `allow_implicit_invocation` in agents/openai.yaml. Run after each sync,
# since the sync re-copies the upstream files verbatim.
make_user_invoked() {
  local skill_dir="$REPO_DIR/skills/$1"
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
  echo "    ~ skills/$1 is user-invoked"
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
sync_source "addy"    "$ADDY_URL"   "skills"        "agents"        "references" ".claude/commands"
rewrite_bucket_refs "addy" "$ADDY_URL"
sync_source "pstack"  "$PSTACK_URL" "pstack/skills" "pstack/agents"
# Spots where a pstack skill name is a plain word: its eval playbook lists
# `arena` among words a candidate must never see, and technical-writing's
# description calls itself a technical-writing standard.
rewrite_bucket_refs "pstack" "$PSTACK_URL" \
  '`candidate`, or `arena`' \
  'Layered technical-writing standard'

sync_single_skill "https://github.com/cursor/plugins.git" "cursor-team-kit/skills/thermo-nuclear-code-quality-review"

EFFECTIVE_HTML_SKILLS=(html design-artifact html-wireframe html-prototype html-plan html-diagram)
sync_single_skill "https://github.com/plannotator/effective-html.git" "${EFFECTIVE_HTML_SKILLS[@]/#/skills/}"
for s in "${EFFECTIVE_HTML_SKILLS[@]}"; do make_user_invoked "personal/$s"; done

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
