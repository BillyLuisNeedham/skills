#!/usr/bin/env bash
set -euo pipefail

# Brings upstream pstack changes into skills/pclaude/ by three-way merge.
#
#   scripts/pclaude-update.sh [--no-pull] [--to <rev>] [--allow-dirty]
#
#   --no-pull      merge what the clone already has; skip `git pull`
#   --to <rev>     merge upstream at <rev> instead of the clone's HEAD
#   --allow-dirty  run even when skills/pclaude/ has uncommitted changes
#
# Upstream is a sparse clone of cursor/plugins limited to pstack/, at
# ~/repos/pstack. It is created on the first run. skills/pclaude/UPSTREAM holds
# the upstream sha the bucket was last merged from.
#
# Steps:
#   1. Pull the clone.
#   2. Render `base` (upstream at the UPSTREAM sha) and `theirs` (upstream at
#      the new sha) with scripts/pclaude/render.mjs, which maps pstack's layout
#      onto pclaude's and renames every pstack reference to pclaude.
#   3. Merge per file, with `ours` the current file in skills/pclaude/:
#      - changed upstream, edited here: `git merge-file`; a clean merge applies,
#        a conflicting one is left with standard conflict markers
#      - changed upstream, untouched here: theirs is copied
#      - new upstream: added (merged against an empty base if a file of that
#        name already exists here)
#      - deleted upstream: flagged, never removed
#      - changed upstream but deleted here: flagged, not re-added
#      - binary files that changed on both sides: flagged, ours kept
#      Files only Billy added are never touched.
#   4. Copy pstack/LICENSE to skills/pclaude/LICENSE.
#   5. Run scripts/pclaude-check.sh.
#   6. Write the new sha to skills/pclaude/UPSTREAM. It is written even when
#      the check fails or a merge conflicts. It records what has been merged,
#      so the next run's base is right.
#
# First run (no UPSTREAM file): base is empty, so theirs is copied in as the
# initial pclaude.
#
# Exits 0 when everything merged cleanly and the check passed. Exits 1 when a
# conflict, a flag or a check hit needs a human; the summary at the end says
# which, and the rendered base and theirs trees are kept for reference.
#
# Overrides, for tests: PCLAUDE_UPSTREAM_URL, PCLAUDE_UPSTREAM_DIR, PCLAUDE_DIR.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
UPSTREAM_URL="${PCLAUDE_UPSTREAM_URL:-https://github.com/cursor/plugins.git}"
CLONE_DIR="${PCLAUDE_UPSTREAM_DIR:-$HOME/repos/pstack}"
PCLAUDE_DIR="${PCLAUDE_DIR:-$REPO_DIR/skills/pclaude}"
SUBDIR="pstack"

pull=1
to_rev="HEAD"
allow_dirty=0
while (( $# > 0 )); do
  case "$1" in
    --no-pull) pull=0 ;;
    --to) to_rev="${2:?--to needs a revision}"; shift ;;
    --allow-dirty) allow_dirty=1 ;;
    -h|--help) sed -n '4,10p' "$0"; exit 0 ;;
    *) echo "pclaude-update: unknown argument $1" >&2; exit 2 ;;
  esac
  shift
done

die() { echo "pclaude-update: $*" >&2; exit 2; }

# --- 1. The clone -------------------------------------------------------------

if [[ ! -d "$CLONE_DIR/.git" ]]; then
  echo "==> Creating the sparse clone $CLONE_DIR ($SUBDIR/ of $UPSTREAM_URL)"
  mkdir -p "$(dirname "$CLONE_DIR")"
  git clone --quiet --filter=blob:none --sparse "$UPSTREAM_URL" "$CLONE_DIR"
  git -C "$CLONE_DIR" sparse-checkout set "$SUBDIR"
elif (( pull )); then
  echo "==> Pulling $CLONE_DIR"
  git -C "$CLONE_DIR" pull --ff-only --quiet
fi

new_sha="$(git -C "$CLONE_DIR" rev-parse --verify "$to_rev^{commit}")" \
  || die "no commit $to_rev in $CLONE_DIR"

old_sha=""
if [[ -f "$PCLAUDE_DIR/UPSTREAM" ]]; then
  old_sha="$(head -n1 "$PCLAUDE_DIR/UPSTREAM" | tr -d '[:space:]')"
  git -C "$CLONE_DIR" cat-file -e "$old_sha^{commit}" 2>/dev/null \
    || die "UPSTREAM names $old_sha, which $CLONE_DIR does not have"
fi

# --- Safety -------------------------------------------------------------------

if [[ -d "$PCLAUDE_DIR" ]]; then
  if grep -rlI -E '^(<{7}|>{7})( |$)' "$PCLAUDE_DIR" >/dev/null 2>&1; then
    die "$PCLAUDE_DIR still has conflict markers from a previous run; resolve them first"
  fi
  if (( ! allow_dirty )) && git -C "$PCLAUDE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    && [[ -n "$(git -C "$PCLAUDE_DIR" status --porcelain -- .)" ]]; then
    die "$PCLAUDE_DIR has uncommitted changes; commit them first (or pass --allow-dirty)"
  fi
fi

# --- 2. Render base and theirs ------------------------------------------------

work="$(mktemp -d "${TMPDIR:-/tmp}/pclaude-update.XXXXXX")"

# render <sha> <dest>: upstream pstack/ at <sha>, renamed into pclaude's layout.
render() {
  local sha="$1" dest="$2" raw="$work/raw-$1"
  mkdir -p "$raw"
  git -C "$CLONE_DIR" archive "$sha" "$SUBDIR" | tar -x -C "$raw"
  node "$SCRIPT_DIR/pclaude/render.mjs" "$raw/$SUBDIR" "$dest"
}

if [[ -n "$old_sha" ]]; then
  echo "==> Rendering base at ${old_sha:0:12} and theirs at ${new_sha:0:12}"
  render "$old_sha" "$work/base"
else
  echo "==> First run: no UPSTREAM, so theirs at ${new_sha:0:12} becomes the initial pclaude"
  mkdir -p "$work/base"
fi
render "$new_sha" "$work/theirs"
: > "$work/empty"

# --- 3. Merge -----------------------------------------------------------------

is_binary() {
  case "$1" in
    *.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico|*.pdf) return 0 ;;
  esac
  perl -0777 -ne 'exit(/\0/ ? 0 : 1)' "$1"
}

added=() updated=() merged=() conflicts=() flags=()

# take <rel>: copy theirs over ours (mode included).
take() {
  mkdir -p "$(dirname "$PCLAUDE_DIR/$1")"
  cp -p "$work/theirs/$1" "$PCLAUDE_DIR/$1"
}

# merge3 <rel> <base-file>: git merge-file into ours, in place.
merge3() {
  local rel="$1" base="$2" rc=0
  local ours="$PCLAUDE_DIR/$rel" theirs="$work/theirs/$rel"
  if is_binary "$ours" || is_binary "$theirs"; then
    flags+=("binary changed on both sides, kept ours: $rel (theirs: $theirs)")
    return
  fi
  local base_label="empty base"
  [[ -n "$old_sha" && "$base" != "$work/empty" ]] && base_label="upstream ${old_sha:0:7}"
  git merge-file -L pclaude -L "$base_label" -L "upstream ${new_sha:0:7}" \
    "$ours" "$base" "$theirs" || rc=$?
  if (( rc == 0 )); then
    merged+=("$rel")
  elif (( rc > 0 && rc < 128 )); then
    conflicts+=("$rel ($rc conflict(s))")
  else
    die "git merge-file failed on $rel (exit $rc)"
  fi
}

mkdir -p "$PCLAUDE_DIR"
while IFS= read -r rel; do
  b="$work/base/$rel" t="$work/theirs/$rel" o="$PCLAUDE_DIR/$rel"
  if [[ -f "$t" && ! -f "$b" ]]; then
    if [[ ! -e "$o" ]]; then take "$rel"; added+=("$rel")
    elif ! cmp -s "$o" "$t"; then merge3 "$rel" "$work/empty"
    fi
  elif [[ -f "$t" && -f "$b" ]]; then
    cmp -s "$b" "$t" && continue
    if [[ ! -e "$o" ]]; then flags+=("changed upstream but deleted here, not re-added: $rel")
    elif cmp -s "$o" "$b"; then take "$rel"; updated+=("$rel")
    elif ! cmp -s "$o" "$t"; then merge3 "$rel" "$b"
    fi
  elif [[ -f "$b" && ! -f "$t" && -e "$o" ]]; then
    flags+=("deleted upstream, still here (remove it if that is right): $rel")
  fi
done < <( (cd "$work/base" && find . -type f; cd "$work/theirs" && find . -type f) \
  | sed 's|^\./||' | LC_ALL=C sort -u )

# --- 4. LICENSE ---------------------------------------------------------------

cp "$work/raw-$new_sha/$SUBDIR/LICENSE" "$PCLAUDE_DIR/LICENSE"

# --- 5. Check -----------------------------------------------------------------

echo "==> Checking $PCLAUDE_DIR"
check_rc=0
"$SCRIPT_DIR/pclaude-check.sh" "$PCLAUDE_DIR" || check_rc=$?

# --- 6. UPSTREAM --------------------------------------------------------------

echo "$new_sha" > "$PCLAUDE_DIR/UPSTREAM"

# --- Summary ------------------------------------------------------------------

list() {
  local label="$1"; shift
  (( $# > 0 )) || return 0
  echo "$label ($#):"
  printf '    %s\n' "$@"
}
echo
echo "==> pclaude merged upstream ${old_sha:+${old_sha:0:12} -> }${new_sha:0:12}"
list "  added" ${added[@]+"${added[@]}"}
list "  updated (untouched here, taken from upstream)" ${updated[@]+"${updated[@]}"}
list "  merged cleanly" ${merged[@]+"${merged[@]}"}
list "  CONFLICTS (resolve the markers)" ${conflicts[@]+"${conflicts[@]}"}
list "  FLAGGED (needs a decision)" ${flags[@]+"${flags[@]}"}

status=0
(( ${#conflicts[@]} + ${#flags[@]} > 0 )) && status=1
(( check_rc != 0 )) && { echo "  CHECK FAILED: see the hits above"; status=1; }
if (( status )); then
  echo "  rendered trees kept for reference: $work/base and $work/theirs"
  exit 1
fi
rm -rf "$work"
echo "  clean"
