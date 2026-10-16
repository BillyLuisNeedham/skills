#!/usr/bin/env bash
set -euo pipefail

# Self-contained test of scripts/pclaude-update.sh, render.mjs and
# scripts/pclaude-check.sh. Builds a fake upstream (a git repo with a pstack/
# folder), lets the update script clone it, and drives it through a first run,
# a clean three-way merge and a conflicting one. Touches nothing outside a temp
# dir: HOME points into it too.
#
#   scripts/pclaude/test.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$SCRIPT_DIR/.." && pwd)"
T="$(mktemp -d "${TMPDIR:-/tmp}/pclaude-test.XXXXXX")"
trap 'rm -rf "$T"' EXIT

export HOME="$T/home"
mkdir -p "$HOME" "$T/tmp"
export TMPDIR="$T/tmp"
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_NOSYSTEM=1

export PCLAUDE_UPSTREAM_URL="file://$T/origin"
export PCLAUDE_UPSTREAM_DIR="$T/clone"
export PCLAUDE_DIR="$T/target/skills/pclaude"
export PCLAUDE_CHECK_ALLOWLIST="$T/allow"
: > "$PCLAUDE_CHECK_ALLOWLIST"

pass=0 fail=0
ok() {
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); echo "  ok   $desc"
  else fail=$((fail + 1)); echo "  FAIL $desc"; fi
}
has() { grep -qF -- "$2" "$1"; }
lacks() { ! grep -qF -- "$2" "$1"; }

# write <path> <content>: a file in the fake upstream's working tree.
write() { mkdir -p "$(dirname "$T/origin/$1")"; printf '%s\n' "$2" > "$T/origin/$1"; }
commit() { git -C "$T/origin" add -A && git -C "$T/origin" commit -qm "$1"; git -C "$T/origin" rev-parse HEAD; }
commit_target() { git -C "$T/target" add -A && git -C "$T/target" commit -qm "$1"; }

# run_update <log> [args]: runs the update script, records its exit code.
run_update() {
  local log="$1"; shift
  rc=0
  "$SCRIPTS/pclaude-update.sh" "$@" > "$log" 2>&1 || rc=$?
}

# --- Fake upstream, commit A --------------------------------------------------

git init -q "$T/origin"
write pstack/LICENSE "MIT License

Copyright (c) 2026 Lauren Tan"
write pstack/README.md "Upstream readme, not ported."
write pstack/skills/how/SKILL.md "---
name: how
description: Explain how code works.
---

# How

Line one stays the same.
Then run \`/why\`, or use the **why** skill, or read [why](../why/SKILL.md).
Ground it per [Fix Root Causes](../principle-fix-root-causes/SKILL.md).
The \`poteto-agent\` delegate does the digging.
Line six stays the same."
write pstack/skills/why/SKILL.md "---
name: why
description: Find why code is shaped the way it is.
---

# Why

Read [the guide](../../docs/guide/01-setup.md) and pstack's notes."
write pstack/skills/why/references/old.md "An old reference."
write pstack/skills/poteto-help/SKILL.md "---
name: poteto-help
description: Help with pstack.
---

Start at /poteto-help or \`/poteto-mode\`, then read [poteto-mode](../poteto-mode/SKILL.md)."
write pstack/skills/poteto-mode/SKILL.md "---
name: poteto-mode
description: The main mode.
---

Babysit an upstack PR. Run \`node pstack/skills/poteto-mode/scripts/check.mjs\`.
Then poteto-mode's playbooks apply.
Read \`git show origin/main:pstack/skills/<each other leaf skill the program uses>\`."
write pstack/skills/poteto-mode/scripts/check.mjs "// check: pstack/skills/poteto-mode/scripts/check.mjs"
chmod +x "$T/origin/pstack/skills/poteto-mode/scripts/check.mjs"
write pstack/skills/principle-fix-root-causes/SKILL.md "---
name: principle-fix-root-causes
description: Fix root causes.
---

Prove it per [Prove It Works](../principle-prove-it-works/SKILL.md)."
write pstack/skills/principle-prove-it-works/SKILL.md "---
name: principle-prove-it-works
description: Prove it works.
---

Run it."
write pstack/skills/make-bot-ui/SKILL.md "---
name: make-bot-ui
---"
write pstack/skills/setup-pstack/SKILL.md "---
name: setup-pstack
---"
write pstack/agents/poteto-agent.md "---
name: poteto-agent
description: Delegate for /poteto-mode runs.
---

Read the **how** skill first."
write pstack/docs/guide/01-setup.md "# Set up pstack

See [how](../../skills/how/SKILL.md) and ![diagram](images/flow.jpg)."
mkdir -p "$T/origin/pstack/docs/guide/images"
printf 'JPEG\0one' > "$T/origin/pstack/docs/guide/images/flow.jpg"
write automations/x.md "Outside pstack/, never cloned."
sha_a="$(commit A)"

# --- Render rules -------------------------------------------------------------

echo "render.mjs"
node "$SCRIPT_DIR/render.mjs" "$T/origin/pstack" "$T/render" >/dev/null
R="$T/render"
ok "skills go to pclaude-<name>/" test -f "$R/pclaude-how/SKILL.md"
ok "poteto-help becomes pclaude-help" test -f "$R/pclaude-help/SKILL.md"
ok "principles become pclaude-principles/<name>.md leaves" test -f "$R/pclaude-principles/fix-root-causes.md"
ok "agents go to agents/pclaude-<name>.md" test -f "$R/agents/pclaude-poteto-agent.md"
ok "docs/guide goes to docs/" test -f "$R/docs/01-setup.md"
ok "binary image copied byte for byte" cmp "$R/docs/images/flow.jpg" "$T/origin/pstack/docs/guide/images/flow.jpg"
ok "make-bot-ui is not ported" test ! -e "$R/pclaude-make-bot-ui"
ok "setup-pstack is not ported" test ! -e "$R/pclaude-setup-pstack"
ok "README and LICENSE are not rendered" test ! -e "$R/README.md" -a ! -e "$R/LICENSE"
ok "skill name: frontmatter renamed" has "$R/pclaude-how/SKILL.md" "name: pclaude-how"
ok "pclaude-help name: frontmatter" has "$R/pclaude-help/SKILL.md" "name: pclaude-help"
ok "agent name: frontmatter renamed" has "$R/agents/pclaude-poteto-agent.md" "name: pclaude-poteto-agent"
ok "principle leaf keeps its name:" has "$R/pclaude-principles/fix-root-causes.md" "name: principle-fix-root-causes"
ok "slash command in backticks" has "$R/pclaude-how/SKILL.md" '`/pclaude-why`'
ok "bold single-word skill name" has "$R/pclaude-how/SKILL.md" "**pclaude-why**"
ok "sibling skill link re-pointed" has "$R/pclaude-how/SKILL.md" "[why](../pclaude-why/SKILL.md)"
ok "principle link from a skill" has "$R/pclaude-how/SKILL.md" "(../pclaude-principles/fix-root-causes.md)"
ok "principle link between leaves" has "$R/pclaude-principles/fix-root-causes.md" "(prove-it-works.md)"
ok "backticked agent name" has "$R/pclaude-how/SKILL.md" '`pclaude-poteto-agent`'
ok "link from a skill into docs" has "$R/pclaude-why/SKILL.md" "(../docs/01-setup.md)"
ok "link from docs into a skill" has "$R/docs/01-setup.md" "(../pclaude-how/SKILL.md)"
ok "relative image link left alone" has "$R/docs/01-setup.md" "(images/flow.jpg)"
ok "bare /poteto-help becomes /pclaude-help" has "$R/pclaude-help/SKILL.md" "Start at /pclaude-help or \`/pclaude-poteto-mode\`"
ok "bare hyphenated name" has "$R/pclaude-poteto-mode/SKILL.md" "Then pclaude-poteto-mode's playbooks"
ok "plain-text upstream path" has "$R/pclaude-poteto-mode/SKILL.md" "node skills/pclaude/pclaude-poteto-mode/scripts/check.mjs"
ok "path in a code file" has "$R/pclaude-poteto-mode/scripts/check.mjs" "skills/pclaude/pclaude-poteto-mode/scripts/check.mjs"
ok "placeholder skill path with spaces" has "$R/pclaude-poteto-mode/SKILL.md" "origin/main:skills/pclaude/pclaude-<each other leaf skill the program uses>\`"
ok "executable bit kept" test -x "$R/pclaude-poteto-mode/scripts/check.mjs"
ok "prose pstack renamed" has "$R/pclaude-why/SKILL.md" "pclaude's notes"
ok "upstack untouched" has "$R/pclaude-poteto-mode/SKILL.md" "an upstack PR"
ok "no pstack left in the render" sh -c "! grep -rIiE '(^|[^a-z])pstack' '$R'"

# --- First run ----------------------------------------------------------------

echo "first run"
git init -q "$T/target"
run_update "$T/first.log"
ok "first run exits 0" test "$rc" -eq 0
ok "creates the clone" test -d "$T/clone/.git"
ok "clone is sparse, limited to pstack/" sh -c "[ \"\$(git -C '$T/clone' sparse-checkout list)\" = pstack ]"
ok "clone has no automations/ checked out" test ! -e "$T/clone/automations"
ok "copies theirs in" cmp "$PCLAUDE_DIR/pclaude-how/SKILL.md" "$R/pclaude-how/SKILL.md"
ok "writes UPSTREAM with the sha" sh -c "[ \"\$(cat '$PCLAUDE_DIR/UPSTREAM')\" = '$sha_a' ]"
ok "copies LICENSE verbatim" cmp "$PCLAUDE_DIR/LICENSE" "$T/origin/pstack/LICENSE"
ok "reports first-run mode" has "$T/first.log" "First run: no UPSTREAM"
ok "runs the check" has "$T/first.log" "pclaude-check: clean"
commit_target "first port"

# --- Clean merge: upstream B, local edit, pull --------------------------------

echo "clean three-way merge"
sed -i 's/^Line one stays the same\.$/Line one, edited in pclaude./' "$PCLAUDE_DIR/pclaude-how/SKILL.md"
printf '# Billy notes\n' > "$PCLAUDE_DIR/NOTES.md"
commit_target "local edits"
sed -i 's/^Line six stays the same\.$/Line six, changed upstream./' "$T/origin/pstack/skills/how/SKILL.md"
printf '\nUpstream added a line to why.\n' >> "$T/origin/pstack/skills/why/SKILL.md"
write pstack/skills/teach/SKILL.md "---
name: teach
description: Teach.
---

Blend the **how** and **why** skills."
printf 'JPEG\0two' > "$T/origin/pstack/docs/guide/images/flow.jpg"
sha_b="$(commit B)"
run_update "$T/clean.log"
H="$PCLAUDE_DIR/pclaude-how/SKILL.md"
ok "clean merge exits 0" test "$rc" -eq 0
ok "pulls the clone to B" sh -c "[ \"\$(git -C '$T/clone' rev-parse HEAD)\" = '$sha_b' ]"
ok "keeps the local edit" has "$H" "Line one, edited in pclaude."
ok "applies the upstream edit" has "$H" "Line six, changed upstream."
ok "no conflict markers" lacks "$H" "<<<<<<<"
ok "lists the file as merged cleanly" has "$T/clean.log" "pclaude-how/SKILL.md"
ok "takes an upstream change to an untouched file" has "$PCLAUDE_DIR/pclaude-why/SKILL.md" "Upstream added a line to why."
ok "adds a new upstream skill, renamed" has "$PCLAUDE_DIR/pclaude-teach/SKILL.md" "**pclaude-how** and **pclaude-why**"
ok "takes an upstream-only binary change" cmp "$PCLAUDE_DIR/docs/images/flow.jpg" "$T/origin/pstack/docs/guide/images/flow.jpg"
ok "leaves a local-only file alone" has "$PCLAUDE_DIR/NOTES.md" "# Billy notes"
ok "UPSTREAM moves to B" sh -c "[ \"\$(cat '$PCLAUDE_DIR/UPSTREAM')\" = '$sha_b' ]"
commit_target "merge B"

# --- Conflicts and flags: upstream C ------------------------------------------

echo "conflicting merge"
sed -i 's/^Line one, edited in pclaude\.$/Line one, edited again in pclaude./' "$H"
rm "$PCLAUDE_DIR/agents/pclaude-poteto-agent.md"
commit_target "more local edits"
sed -i 's/^Line one stays the same\.$/Line one, rewritten upstream./' "$T/origin/pstack/skills/how/SKILL.md"
git -C "$T/origin" rm -q pstack/skills/why/references/old.md
printf '\nUpstream changed the agent.\n' >> "$T/origin/pstack/agents/poteto-agent.md"
sha_c="$(commit C)"
run_update "$T/conflict.log"
ok "conflicting merge exits 1" test "$rc" -eq 1
ok "leaves the ours marker" has "$H" "<<<<<<< pclaude"
ok "keeps both sides" sh -c "grep -qF 'Line one, edited again in pclaude.' '$H' && grep -qF 'Line one, rewritten upstream.' '$H'"
ok "leaves the theirs marker" has "$H" ">>>>>>> upstream ${sha_c:0:7}"
ok "still applies the non-conflicting upstream edit" has "$H" "Line six, changed upstream."
ok "reports the conflict" has "$T/conflict.log" "CONFLICTS (resolve the markers)"
ok "flags an upstream deletion" has "$T/conflict.log" "deleted upstream, still here (remove it if that is right): pclaude-why/references/old.md"
ok "does not remove the deleted file" test -f "$PCLAUDE_DIR/pclaude-why/references/old.md"
ok "flags an upstream change to a locally deleted file" has "$T/conflict.log" "changed upstream but deleted here, not re-added: agents/pclaude-poteto-agent.md"
ok "does not re-add the locally deleted file" test ! -e "$PCLAUDE_DIR/agents/pclaude-poteto-agent.md"
ok "the check fails on the conflict markers" has "$T/conflict.log" "[conflict-marker]"
ok "UPSTREAM still moves to C" sh -c "[ \"\$(cat '$PCLAUDE_DIR/UPSTREAM')\" = '$sha_c' ]"
ok "keeps the rendered trees for the resolver" has "$T/conflict.log" "rendered trees kept for reference"
commit_target "merge C with conflicts"
run_update "$T/rerun.log" --no-pull
ok "refuses to run over unresolved markers" test "$rc" -eq 2
ok "says why it refused" has "$T/rerun.log" "still has conflict markers"

# --- Refuses a dirty tree -----------------------------------------------------

echo "dirty tree"
sed -i '/^<<<<<<< /d; /^=======$/d; /^>>>>>>> /d; /^Line one, rewritten upstream\.$/d' "$H"
sed -i '/pclaude-poteto-agent/d' "$H"
commit_target "resolve"
printf 'uncommitted\n' >> "$PCLAUDE_DIR/NOTES.md"
run_update "$T/dirty.log" --no-pull
ok "refuses uncommitted changes" test "$rc" -eq 2
run_update "$T/dirty2.log" --no-pull --allow-dirty
ok "--allow-dirty runs it (nothing to merge, exit 0)" test "$rc" -eq 0

# --- The check ----------------------------------------------------------------

echo "pclaude-check"
C="$T/checkdir"
mkdir -p "$C/pclaude-how" "$C/pclaude-principles" "$C/agents" "$C/docs"
printf -- '---\nname: pclaude-how\n---\nRead [why](../pclaude-why/SKILL.md).\n' > "$C/pclaude-how/SKILL.md"
printf 'Prove it.\n' > "$C/pclaude-principles/prove-it-works.md"
printf 'Fine: [how](../pclaude-how/SKILL.md), pclaude-principles/prove-it-works.md, ~/.claude/skills/pclaude-how/SKILL.md, skills/pclaude/docs/a.md, skills/pclaude/pclaude-<each leaf>/SKILL.md, the cursor location, endCursor.\n' > "$C/docs/a.md"
cat > "$C/docs/bad.md" <<'EOF'
Use grok-4.7-xhigh-fast for code.
Ask with AskQuestion.
Rules live in ~/.cursor/rules/x.mdc.
Run deslop on the diff.
Drive it with control-ui or control-cli.
Spawn one `Task` call, then the Task tool again.
From cursor-team-kit.
Set mode: true.
Calls api2.cursor.sh.
Open Cursor.
Still says pstack.
Run setup-pstack or make-bot-ui.
Read ~/.claude/skills/pclaude-nope/SKILL.md and skills/pclaude/missing.md.
Use pclaude-nope and pclaude-principles/missing.
An upstack PR is fine.
See https://cursor.com/docs and https://github.com/cursor/plugins.
Package @cursor-skill/tools, CURSOR_AUTOMATION_ID, author === "cursor".
EOF
printf -- '---\nname: pclaude-x\nreminder: x\nicon: x\n---\n' > "$C/pclaude-how/extra.md"
printf '<<<<<<< pclaude\n' > "$C/docs/markers.md"
: > "$T/empty-allow"
rc=0; PCLAUDE_CHECK_ALLOWLIST="$T/empty-allow" "$SCRIPTS/pclaude-check.sh" "$C" > "$T/check.log" 2>&1 || rc=$?
ok "check exits 1 on hits" test "$rc" -eq 1
for rule in cursor:grok cursor:AskQuestion cursor:.cursor cursor:.mdc cursor:deslop cursor:control-ui \
  cursor:control-cli cursor:Task-tool cursor:cursor-team-kit cursor:mode-true cursor:api2.cursor.sh \
  cursor:Cursor pstack unported-skill dangling-link dangling-path unknown-skill unknown-principle \
  cursor:reminder-frontmatter conflict-marker cursor:cursor.com cursor:cursor-name; do
  ok "flags [$rule]" has "$T/check.log" "[$rule]"
done
ok "flags both Task wordings" sh -c "[ \$(grep -c 'docs/bad.md:6: \[cursor:Task-tool\]' '$T/check.log') -eq 2 ]"
ok "dangling link names the target" has "$T/check.log" "pclaude-how/SKILL.md:4: [dangling-link] ../pclaude-why/SKILL.md"
ok "mode:/icon: only flagged in SKILL.md frontmatter" lacks "$T/check.log" "[cursor:icon-frontmatter]"
ok "flags both cursor links" sh -c "[ \$(grep -c 'docs/bad.md:16: \[cursor:cursor.com\]' '$T/check.log') -eq 2 ]"
ok "flags all three cursor names" sh -c "[ \$(grep -c 'docs/bad.md:17: \[cursor:cursor-name\]' '$T/check.log') -eq 3 ]"
ok "upstack is not flagged" lacks "$T/check.log" "bad.md:15:"
ok "valid links, paths and names pass" lacks "$T/check.log" "docs/a.md"
cat > "$T/allow-ok" <<'EOF'
# Test: allow the word on line 10 only.
docs/*.md	Open Cursor.
EOF
rc=0; PCLAUDE_CHECK_ALLOWLIST="$T/allow-ok" "$SCRIPTS/pclaude-check.sh" "$C" > "$T/check2.log" 2>&1 || rc=$?
ok "an allowlisted line is not reported" lacks "$T/check2.log" "bad.md:10:"
ok "other hits still reported" has "$T/check2.log" "bad.md:11: [pstack]"
printf 'docs/*.md\tOpen Cursor.\n' > "$T/allow-bad"
rc=0; PCLAUDE_CHECK_ALLOWLIST="$T/allow-bad" "$SCRIPTS/pclaude-check.sh" "$C" > "$T/check3.log" 2>&1 || rc=$?
ok "an entry without a comment is an error" has "$T/check3.log" "entry has no comment above it"
printf '# reason\n**/SKILL.md\tnever matches\n' > "$T/allow-unused"
rm "$C/docs/bad.md" "$C/docs/markers.md" "$C/pclaude-how/extra.md"
printf -- '---\nname: pclaude-how\n---\nRead [principle](../pclaude-principles/prove-it-works.md).\n' > "$C/pclaude-how/SKILL.md"
rc=0; PCLAUDE_CHECK_ALLOWLIST="$T/allow-unused" "$SCRIPTS/pclaude-check.sh" "$C" > "$T/check4.log" 2>&1 || rc=$?
ok "a clean tree passes" test "$rc" -eq 0
ok "an unused entry is a warning" has "$T/check4.log" "warning: allowlist line 2: unused entry"

echo
echo "$pass passed, $fail failed"
(( fail == 0 ))
