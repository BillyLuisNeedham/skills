#!/usr/bin/env bash
set -euo pipefail

# Checks the pclaude bucket for anything left over from Cursor or pstack.
#
#   scripts/pclaude-check.sh [pclaude-dir]
#
# Defaults to skills/pclaude/ in this repo. Prints one line per hit and exits
# 1 when there is any. It fails on:
#   - Cursor-isms: grok, AskQuestion, .cursor, .mdc, deslop, control-ui,
#     control-cli, Cursor `Task` tool wording, cursor-team-kit, `mode: true`,
#     api2.cursor.sh, the word Cursor, and `reminder:` frontmatter (plus
#     `mode:` and `icon:` in a SKILL.md's frontmatter)
#   - any `pstack` left in the text (not `upstack`)
#   - names of the skills that are not ported (make-bot-ui, setup-pstack)
#   - conflict markers left by scripts/pclaude-update.sh
#   - a relative markdown link to a file that does not exist, a
#     `~/.claude/skills/pclaude-...` or `skills/pclaude/...` path that does not
#     exist, a `pclaude-<name>` that is neither a skill nor an agent, and a
#     `pclaude-principles/<name>` with no leaf file
# docs/ is checked like everything else. LICENSE and UPSTREAM are skipped.
#
# To accept a flagged line, add it to scripts/pclaude-check.allow with a
# comment saying why. The format is described at the top of that file.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PCLAUDE_DIR="${1:-${PCLAUDE_DIR:-$REPO_DIR/skills/pclaude}}"
ALLOWLIST="${PCLAUDE_CHECK_ALLOWLIST:-$SCRIPT_DIR/pclaude-check.allow}"

exec node "$SCRIPT_DIR/pclaude/check.mjs" "$PCLAUDE_DIR" "$ALLOWLIST"
