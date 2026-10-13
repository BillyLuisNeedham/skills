#!/usr/bin/env bash
# Merge a branch forward through the stacked PR branches above it, without
# rewriting history. Merges run on detached HEADs in a scratch worktree, the
# gate runs at each changed tip, and local branch refs move (fast-forward only)
# only after every gate passes. Pushing is left to the caller.
#
# Usage: stack-forward.sh [options] <branch>
#   --dry-run              print the plan and change nothing (reads origin with ls-remote)
#   --chain a,b,c          take the stack from this list (a sits on <branch>) instead of gh
#   --edges FILE           take the stack from FILE, one "parent child" pair per line
#   --repo DIR             repository to work in (default: current directory)
#   --gate CMD             gate run at each changed tip
#                          (default: ./gradlew testDebugUnitTest assembleDebug)
#   --no-gate              skip the gate (testing the script only)
#   --local-properties F   copied into the scratch worktree before the gate
#                          (default: /Users/billy.needham/repos/android-app/local.properties)
#
# Exit codes: 0 done or nothing to do, 1 merge conflict, 2 preflight problem,
# 3 gate failed, 4 usage error, 5 ref update failed.
#
# Written for the macOS system bash (3.2): no associative arrays.

set -uo pipefail

DRY_RUN=0
CHAIN=""
EDGES_FILE=""
REPO_DIR="$PWD"
GATE="./gradlew testDebugUnitTest assembleDebug"
RUN_GATE=1
LOCAL_PROPS="/Users/billy.needham/repos/android-app/local.properties"
ROOT=""
ZERO=0000000000000000000000000000000000000000

die() { echo "stack-forward: $*" >&2; exit 4; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --chain) CHAIN="${2:?--chain needs a value}"; shift ;;
    --edges) EDGES_FILE="${2:?--edges needs a file}"; shift ;;
    --repo) REPO_DIR="${2:?--repo needs a dir}"; shift ;;
    --gate) GATE="${2:?--gate needs a command}"; shift ;;
    --no-gate) RUN_GATE=0 ;;
    --local-properties) LOCAL_PROPS="${2:?--local-properties needs a file}"; shift ;;
    -h|--help) sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) [ -z "$ROOT" ] || die "one branch only"; ROOT="$1" ;;
  esac
  shift
done
[ -n "$ROOT" ] || die "usage: stack-forward.sh [--dry-run] [--chain a,b,c | --edges FILE] <branch>"

cd "$REPO_DIR" 2>/dev/null || die "no such dir $REPO_DIR"
git rev-parse --git-dir >/dev/null 2>&1 || die "$REPO_DIR is not a git repository"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/stack-forward.XXXXXX")"
SCRATCH=""
cleanup() {
  if [ -n "$SCRATCH" ] && [ -d "$SCRATCH" ]; then
    git -C "$SCRATCH" merge --abort >/dev/null 2>&1
    git worktree remove --force "$SCRATCH" >/dev/null 2>&1 || rm -rf "$SCRATCH"
    git worktree prune >/dev/null 2>&1
  fi
  rm -rf "$WORK"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

short() { printf '%s' "${1:0:9}"; }

# ---- 1. The stack, as "parent<TAB>child<TAB>pr" edges ------------------------
EDGES="$WORK/edges"
: > "$EDGES"
if [ -n "$CHAIN" ]; then
  prev="$ROOT"
  IFS=',' read -r -a chain_list <<< "$CHAIN"
  for b in "${chain_list[@]}"; do
    [ -n "$b" ] && printf '%s\t%s\t-\n' "$prev" "$b" >> "$EDGES" && prev="$b"
  done
elif [ -n "$EDGES_FILE" ]; then
  [ -f "$EDGES_FILE" ] || die "no such file $EDGES_FILE"
  awk 'NF >= 2 && $1 !~ /^#/ { print $1 "\t" $2 "\t-" }' "$EDGES_FILE" >> "$EDGES"
else
  command -v gh >/dev/null || die "gh not found; pass --chain or --edges"
  gh pr list --state open --limit 500 --json number,headRefName,baseRefName \
    --jq '.[] | [.baseRefName, .headRefName, (.number | tostring)] | @tsv' > "$EDGES" \
    || { echo "stack-forward: gh pr list failed" >&2; exit 2; }
fi

# Depth-first walk from ROOT, parent before child. ORDER lines: child parent pr depth.
ORDER="$WORK/order"
: > "$ORDER"
walk() {
  local parent="$1" depth="$2" child pr
  awk -F'\t' -v p="$parent" '$1 == p { print $2, $3 }' "$EDGES" | sort > "$WORK/kids.$depth"
  while read -r child pr; do
    if [ "$child" = "$ROOT" ] || awk -v c="$child" '$1 == c { f = 1 } END { exit !f }' "$ORDER"; then
      echo "stack-forward: $child appears twice in the stack (cycle or two parents)" >&2
      exit 2
    fi
    echo "$child $parent $pr $depth" >> "$ORDER"
    walk "$child" $((depth + 1)) || exit 2
  done < "$WORK/kids.$depth"
}
walk "$ROOT" 1 || exit 2

if [ ! -s "$ORDER" ]; then
  echo "Nothing stacked on $ROOT: no open PR has it as its base."
  exit 0
fi

ALL_BRANCHES="$ROOT $(awk '{ print $1 }' "$ORDER" | tr '\n' ' ')"
field() { awk -v b="$1" -v n="$2" '$1 == b { print $n }' "$ORDER"; }
is_leaf() { ! awk -v b="$1" '$2 == b { f = 1 } END { exit !f }' "$ORDER"; }

# ---- 2. Origin shas ------------------------------------------------------------
REMOTE="$WORK/remote"   # lines: branch sha
: > "$REMOTE"
if [ "$DRY_RUN" = 1 ]; then
  refs=""
  for b in $ALL_BRANCHES; do refs="$refs refs/heads/$b"; done
  # shellcheck disable=SC2086
  git ls-remote origin $refs | awk '{ sub("refs/heads/", "", $2); print $2, $1 }' > "$REMOTE" \
    || { echo "stack-forward: git ls-remote origin failed" >&2; exit 2; }
else
  specs=""
  for b in $ALL_BRANCHES; do specs="$specs +refs/heads/$b:refs/remotes/origin/$b"; done
  # shellcheck disable=SC2086
  git fetch -q origin $specs || { echo "stack-forward: git fetch failed" >&2; exit 2; }
  for b in $ALL_BRANCHES; do
    echo "$b $(git rev-parse -q --verify "refs/remotes/origin/$b^{commit}")" >> "$REMOTE"
  done
fi
origin_sha() { awk -v b="$1" '$1 == b { print $2 }' "$REMOTE"; }
have() { git cat-file -e "$1^{commit}" 2>/dev/null; }
ancestor() { git merge-base --is-ancestor "$1" "$2" 2>/dev/null; }
checked_out_at() {
  git worktree list --porcelain | awk -v r="branch refs/heads/$1" '
    /^worktree / { wt = substr($0, 10) } $0 == r { print wt }'
}

# ---- 3. Preflight --------------------------------------------------------------
PROBLEMS="$WORK/problems"
NOTES="$WORK/notes"
: > "$PROBLEMS"; : > "$NOTES"
LOCAL="$WORK/local"     # lines: branch local-sha-or-ZERO
: > "$LOCAL"
for b in $ALL_BRANCHES; do
  o="$(origin_sha "$b")"
  if [ -z "$o" ]; then echo "$b: not on origin" >> "$PROBLEMS"; continue; fi
  if ! have "$o"; then
    if [ "$DRY_RUN" = 1 ]; then
      echo "$b: origin is at $(short "$o"), which this clone has not fetched; a real run fetches it, or git fetch origin and dry-run again" >> "$NOTES"
    else
      echo "$b: origin is at $(short "$o") but that commit is missing after the fetch" >> "$PROBLEMS"
    fi
    continue
  fi
  l="$(git rev-parse -q --verify "refs/heads/$b^{commit}")"
  echo "$b ${l:-$ZERO}" >> "$LOCAL"
  if [ -n "$l" ] && ! ancestor "$l" "$o"; then
    if ancestor "$o" "$l"; then
      echo "$b: local branch is $(git rev-list --count "$o..$l") commit(s) ahead of origin; push them first" >> "$PROBLEMS"
    else
      echo "$b: local branch has diverged from origin" >> "$PROBLEMS"
    fi
  fi
  if [ "$b" != "$ROOT" ]; then
    wt="$(checked_out_at "$b")"
    [ -n "$wt" ] && echo "$b: checked out in $wt" >> "$PROBLEMS"
  fi
done
local_sha() { awk -v b="$1" '$1 == b { print $2 }' "$LOCAL"; }

# ---- 4. Plan (dry run) ---------------------------------------------------------
if [ "$DRY_RUN" = 1 ]; then
  echo "Stack above $ROOT (origin $(short "$(origin_sha "$ROOT")")), parent before child:"
  CHANGES="$WORK/changes"; UNKNOWN="$WORK/unknown"
  : > "$CHANGES"; : > "$UNKNOWN"
  while read -r child parent pr depth; do
    indent="$(printf '%*s' $((depth * 2)) '')"
    label="$child"; [ "$pr" != "-" ] && label="$child (#$pr)"
    c="$(origin_sha "$child")"; p="$(origin_sha "$parent")"
    if [ -z "$c" ] || [ -z "$p" ] || ! have "$c" || ! have "$p" || grep -qx "$parent" "$UNKNOWN"; then
      verdict="unknown, see notes"; echo "$child" >> "$UNKNOWN"
    elif grep -qx "$parent" "$CHANGES" || ! ancestor "$p" "$c"; then
      verdict="merge $parent"; echo "$child" >> "$CHANGES"
    else
      verdict="up to date"
    fi
    tip=""; is_leaf "$child" && tip="  [tip: gate here]"
    echo "${indent}${label} at $(short "$c"): ${verdict}${tip}"
  done < "$ORDER"
  if [ -s "$NOTES" ]; then
    echo; echo "Notes:"; sed 's/^/  /' "$NOTES"
  fi
  if [ -s "$PROBLEMS" ]; then
    echo; echo "Problems that would stop a real run:"; sed 's/^/  /' "$PROBLEMS"
  fi
  echo; echo "Dry run: nothing fetched, merged, built or pushed."
  exit 0
fi

if [ -s "$PROBLEMS" ]; then
  echo "Stopped before merging anything:" >&2
  sed 's/^/  /' "$PROBLEMS" >&2
  exit 2
fi

# ---- 5. Merge forward on detached HEADs ----------------------------------------
SCRATCH="$WORK/wt"
git worktree add -q --detach "$SCRATCH" "$(origin_sha "$ROOT")" >/dev/null 2>&1 \
  || { SCRATCH=""; echo "stack-forward: could not create scratch worktree" >&2; exit 2; }

NEW="$WORK/new"         # lines: branch new-sha result
echo "$ROOT $(origin_sha "$ROOT") root" > "$NEW"
new_sha() { awk -v b="$1" '$1 == b { print $2 }' "$NEW"; }
result_of() { awk -v b="$1" '$1 == b { print $3 }' "$NEW"; }

while read -r child parent pr depth; do
  c="$(origin_sha "$child")"; p="$(new_sha "$parent")"
  if ancestor "$p" "$c"; then
    echo "$child $c up-to-date" >> "$NEW"
    continue
  fi
  git -C "$SCRATCH" checkout -q --detach "$c" || { echo "stack-forward: checkout of $child failed" >&2; exit 2; }
  if ! git -C "$SCRATCH" merge -q --no-ff --no-edit -m "Merge branch '$parent' into $child" "$p" >"$WORK/merge.log" 2>&1; then
    files="$(git -C "$SCRATCH" diff --name-only --diff-filter=U)"
    git -C "$SCRATCH" merge --abort >/dev/null 2>&1
    echo "CONFLICT merging $parent into $child. Nothing was changed: no branch moved, nothing pushed." >&2
    if [ -n "$files" ]; then
      echo "Conflicting files:" >&2; echo "$files" | sed 's/^/  /' >&2
    else
      sed 's/^/  /' "$WORK/merge.log" >&2
    fi
    exit 1
  fi
  echo "$child $(git -C "$SCRATCH" rev-parse HEAD) merged" >> "$NEW"
done < "$ORDER"

report() {
  local b p n d label
  echo "Branch | parent | origin -> new | result"
  while read -r b p n d; do
    label="$b"; [ "$n" != "-" ] && label="$b (#$n)"
    echo "$label | $p | $(short "$(origin_sha "$b")") -> $(short "$(new_sha "$b")") | $(result_of "$b")"
  done < "$ORDER"
}

if ! grep -q ' merged$' "$NEW"; then
  report
  echo
  echo "Every branch already contains its parent. Nothing to gate or push."
  exit 0
fi

# ---- 6. Gate at each changed tip -----------------------------------------------
GATES="$WORK/gates"
: > "$GATES"
if [ "$RUN_GATE" = 1 ]; then
  while read -r child parent pr depth; do
    is_leaf "$child" || continue
    [ "$(result_of "$child")" = "merged" ] || continue
    git -C "$SCRATCH" checkout -q --detach "$(new_sha "$child")"
    [ -f "$LOCAL_PROPS" ] && cp "$LOCAL_PROPS" "$SCRATCH/local.properties"
    log="${TMPDIR:-/tmp}/stack-forward-gate-$(echo "$child" | tr '/' '-')-$$.log"
    echo "Gate at $child ($(short "$(new_sha "$child")")): $GATE" >&2
    if (cd "$SCRATCH" && export AGENT_BUILD_LOCK=1 && eval "$GATE") >"$log" 2>&1; then
      echo "$child passed" >> "$GATES"
    else
      echo "$child FAILED" >> "$GATES"
      report
      echo
      echo "GATE FAILED at $child. No branch moved, nothing to push. Last 40 lines of $log:"
      tail -n 40 "$log"
      exit 3
    fi
  done < "$ORDER"
else
  echo "gate skipped (--no-gate)" >> "$GATES"
fi

# ---- 7. Fast-forward the local branches ----------------------------------------
while read -r child parent pr depth; do
  [ "$(result_of "$child")" = "merged" ] || continue
  wt="$(checked_out_at "$child")"
  if [ -n "$wt" ]; then
    echo "stack-forward: $child was checked out in $wt during the run; stopping before moving it." >&2
    exit 5
  fi
  if ! git update-ref -m "stack-forward: merge $parent into $child" \
      "refs/heads/$child" "$(new_sha "$child")" "$(local_sha "$child")"; then
    echo "stack-forward: could not move $child (it changed during the run). Branches above it are not moved." >&2
    exit 5
  fi
done < "$ORDER"

report
echo
echo "Gate:"; sed 's/^/  /' "$GATES"
echo
echo "Local branches moved. Push, one command each, parents first:"
while read -r child parent pr depth; do
  [ "$(result_of "$child")" = "merged" ] && echo "  git push origin $child"
done < "$ORDER"
exit 0
