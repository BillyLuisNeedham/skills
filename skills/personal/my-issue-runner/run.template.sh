#!/usr/bin/env bash
#
# Issue runner.
#
# Works a queue of Issues. One orchestrator per Issue, then it exits. The next
# orchestrator starts fresh. State lives on line 1 of each Issue file, so an
# interrupted run picks up where it stopped.
#
#   ./run.sh              work the queue until it halts
#   ./run.sh status       print the board, change nothing
#   ./run.sh next         print which Issue would run next
#   ./run.sh reset NN     put Issue NN back to ready
#
# Exit codes:
#   0  the queue finished, or nothing is runnable
#   1  a preflight refusal, such as a dirty worktree
#   2  an Issue reached a checkpoint and needs you
#   3  an Issue ended without setting its own status
#
# Environment overrides:
#   RUNNER_BUDGET_USD   spend cap per Issue   (default: none)
#   RUNNER_MAX_ISSUES   safety stop           (default: set below the marker)
#
# Everything above the CONFIG marker is the engine. It is identical in every
# runner /my-issue-runner generates, and that sameness is the point: leave it
# alone. To pick up a newer engine, run the skill again on this directory. It
# replaces above the marker and leaves your config below it untouched.
#
# engine-version: 1.0.0
#
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------- helpers

# macOS sed and GNU sed disagree about -i. Normalise.
sedi() { if sed --version >/dev/null 2>&1; then sed -i "$@"; else sed -i '' "$@"; fi; }

field()   { grep -m1 -oE "$2=[^ ]+" "$1" | head -1 | cut -d= -f2-; }
status()  { field "$1" status; }
blocks()  { field "$1" "blocked-by"; }
file_of() { ls "$ISSUES_DIR"/"$1"-*.md 2>/dev/null | head -1; }
id_of()   { basename "$1" | cut -d- -f1; }

set_status() { sedi "1s/status=[a-z-]*/status=$2/" "$1"; }

# Append a note to an Issue. A stop must always leave a trace in the Issue
# itself, not only in the log, because the Issue is what the next agent reads.
# Used when the agent cannot be relied on to have written its own brief.
note_issue() {
  local f="$1" log="$2" reason="$3"
  {
    printf '\n---\n\n## Brief, written by the runner\n\n'
    printf '%s\n\n' "$reason"
    printf -- '- Stopped: %s\n' "$(date '+%Y-%m-%d %H:%M')"
    printf -- '- Log: `%s`\n' "${log#"$REPO"/}"
    printf -- '- Working tree at the stop:\n\n'
    printf '```\n'
    git -C "$REPO" status --short 2>&1 | head -20
    printf '```\n'
    if [ -s "$log" ]; then
      printf '\nLast lines of the log:\n\n```\n'
      tail -n 25 "$log" 2>/dev/null
      printf '```\n'
    fi
    printf '\nNothing above is confirmed. Read the log before you trust any part of this Issue.\n'
  } >> "$f"
}

# An Issue is runnable when it is ready and every blocker is done.
runnable() {
  local f="$1" bb id bf
  [ "$(status "$f")" = "ready" ] || return 1
  bb="$(blocks "$f")"
  [ "$bb" = "none" ] && return 0
  for id in ${bb//,/ }; do
    bf="$(file_of "$id")"
    [ -n "$bf" ] || return 1
    [ "$(status "$bf")" = "done" ] || return 1
  done
  return 0
}

next_issue() {
  local f
  for f in "$ISSUES_DIR"/*.md; do
    if runnable "$f"; then echo "$f"; return 0; fi
  done
  return 1
}

board() {
  local f
  printf '%-4s %-12s %-14s %s\n' ID STATUS BLOCKED-BY ISSUE
  for f in "$ISSUES_DIR"/*.md; do
    printf '%-4s %-12s %-14s %s\n' \
      "$(id_of "$f")" "$(status "$f")" "$(blocks "$f")" \
      "$(basename "$f" .md | cut -d- -f2-)"
  done
}

# Tracked changes are refused: an unattended run would sweep them into a commit
# that claims to be an Issue's work. Untracked files only get a warning, because
# editor and tooling droppings are always there and refusing on them would make
# the runner unusable.
preflight() {
  [ -d "$ISSUES_DIR" ] || { echo "STOP: no Issue directory at $ISSUES_DIR" >&2; exit 1; }
  command -v claude >/dev/null || { echo "STOP: claude is not on PATH." >&2; exit 1; }
  if [ -n "$(git -C "$REPO" status --porcelain --untracked-files=no)" ]; then
    echo "STOP: the worktree has uncommitted changes to tracked files." >&2
    echo "      Commit or stash them, then start again." >&2
    git -C "$REPO" status --short --untracked-files=no >&2
    exit 1
  fi
  if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
    echo "runner: note, untracked files are present and an agent could commit them"
  fi
  mkdir -p "$LOGS"
}

# ---------------------------------------------------------------- the loop

main() {
  REPO="$(git -C "$DIR" rev-parse --show-toplevel)"
  LOGS="$DIR/runs"

  local budget max
  budget="${RUNNER_BUDGET_USD:-}"          # empty means no cap
  max="${RUNNER_MAX_ISSUES:-$MAX_ISSUES_DEFAULT}"

  case "${1:-run}" in
    status) board; exit 0 ;;
    next)
      if f="$(next_issue)"; then echo "$(id_of "$f")  $(basename "$f")";
      else echo "nothing runnable"; fi
      exit 0 ;;
    reset)
      f="$(file_of "${2:?usage: run.sh reset NN}")"
      [ -n "$f" ] || { echo "no Issue ${2}" >&2; exit 1; }
      set_status "$f" ready
      echo "Issue ${2} back to ready"; exit 0 ;;
  esac

  preflight

  # Only pass --max-budget-usd when one is set. Passing it empty caps at zero.
  local budget_label="none"
  BUDGET_ARGS=()
  if [ -n "$budget" ]; then
    BUDGET_ARGS=(--max-budget-usd "$budget")
    budget_label="\$$budget/Issue"
  fi

  echo "runner: model=$ORCHESTRATOR_MODEL perms=auto budget=$budget_label"
  echo

  # An interrupted Issue must not be left at in-progress with nothing written.
  # The runner only starts Issues that are ready, so that Issue would be skipped
  # for ever and its part-done state would be invisible.
  CURRENT_ISSUE=""
  CURRENT_LOG=""
  trap on_interrupt INT TERM

  local worked=0 issue id rel log final drivers driver rest chain
  while [ "$worked" -lt "$max" ]; do

    if ! issue="$(next_issue)"; then
      echo
      echo "No runnable Issue. Board:"
      board
      break
    fi

    id="$(id_of "$issue")"
    rel="${issue#"$REPO"/}"
    log="$LOGS/$id.log"

    # The first driver goes in the prompt, because the prompt is the only slot
    # that counts as the user typing and so the only one that can reach a skill
    # with disable-model-invocation. Any others are dispatched as subagents.
    drivers="$(drivers_for "$id")"
    driver="${drivers%% *}"
    rest=""
    [ "$drivers" != "$driver" ] && rest="${drivers#* }"

    chain=""
    if [ -n "$rest" ]; then
      chain="

Chain for this Issue. When the driver skill's work is done, dispatch these subagents in this order, one at a time, and act on what each returns: $rest."
    fi

    echo "──────────────────────────────────────────────────────────────"
    echo "Issue $id  $(basename "$issue")"
    echo "drivers  $drivers"
    echo "log      $log"
    echo "──────────────────────────────────────────────────────────────"

    set_status "$issue" in-progress
    CURRENT_ISSUE="$issue"
    CURRENT_LOG="$log"

    # stdin is closed deliberately. Left open, claude waits three seconds for
    # input that an unattended run will never send.
    ( cd "$REPO" && claude -p "/$driver $rel" \
        --model "$ORCHESTRATOR_MODEL" \
        --permission-mode auto \
        --append-system-prompt "$(cat "$DIR/AGENT.md")$chain" \
        --agents "$AGENTS" \
        ${BUDGET_ARGS[@]+"${BUDGET_ARGS[@]}"} \
        --output-format text </dev/null ) 2>&1 | tee "$log"

    final="$(status "$issue")"

    case "$final" in
      done)
        echo
        echo "✅ Issue $id done"
        worked=$((worked + 1))
        ;;
      checkpoint)
        # The agent should have written its own brief. If it set the status but
        # skipped the section, write one so the Issue is never a dead end.
        grep -q '^## Brief' "$issue" || note_issue "$issue" "$log" \
          "The agent stopped cleanly but did not write its own brief, so this note stands in for it."
        echo
        echo "🛑 Issue $id needs you. Stopping."
        echo
        sed -n '/^## Brief/,$p' "$issue"
        echo
        echo "When you have done your part:  ./run.sh reset $id"
        exit 2
        ;;
      *)
        set_status "$issue" checkpoint
        note_issue "$issue" "$log" \
          "The agent stopped without setting its own status, last seen as '$final'. It crashed, ran out of context, or was killed. It had no chance to write a brief or to commit."
        echo
        echo "🛑 Issue $id ended without setting its status (was '$final')."
        echo "   Treating as a checkpoint. A note is on the Issue. See $log."
        exit 3
        ;;
    esac
  done

  echo
  echo "Runner finished. Board:"
  board
}

on_interrupt() {
  trap - INT TERM
  if [ -n "$CURRENT_ISSUE" ] && [ "$(status "$CURRENT_ISSUE")" = "in-progress" ]; then
    set_status "$CURRENT_ISSUE" ready
    note_issue "$CURRENT_ISSUE" "$CURRENT_LOG" \
      "You interrupted this run. The work is part done at best, and the agent had no chance to write its own brief or to commit. The Issue is back to ready, so read this note and the working tree before you start the queue again."
    echo
    echo "🛑 interrupted. Issue $(id_of "$CURRENT_ISSUE") is back to ready and carries a note."
  else
    echo
    echo "🛑 interrupted."
  fi
  exit 130
}

# ================================================================ CONFIG
# Author everything below. One /my-issue-runner interview fills it in.

ISSUES_DIR="$DIR/issues"
MAX_ISSUES_DEFAULT=1
ORCHESTRATOR_MODEL="opus"

# Which skill or skills drive each Issue, in order. The first one is invoked as
# the prompt; the rest are dispatched as subagents. At most one skill carrying
# disable-model-invocation is allowed, and it must be first.
drivers_for() {
  case "$1" in
    *) echo "implement" ;;
  esac
}

# The subagent roster. A model given here is a ceiling by convention, not by
# enforcement: an orchestrator that passes its own override reaches past it.
# Every model defaults to the orchestrator's own, so delegating a skill never
# quietly downgrades the work.
AGENTS='{
  "recon": {
    "description": "Read-only reconnaissance. Finds where things live and what they currently do. Never edits.",
    "prompt": "You are a read-only reconnaissance agent. Answer with file paths, line numbers and short verbatim quotes. State plainly when something does not exist rather than guessing. Leave every file exactly as you found it.",
    "model": "haiku"
  }
}'

main "$@"
