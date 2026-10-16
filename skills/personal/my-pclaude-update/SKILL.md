---
name: my-pclaude-update
description: Merge upstream pstack changes into skills/pclaude, resolve conflicts and check hits by translating the new text, and commit.
disable-model-invocation: true
---

`skills/pclaude/` is pstack ported to Claude Code. Billy edits it directly, and upstream changes arrive by three-way merge. `scripts/pclaude-update.sh` does the deterministic part. This skill does the rest: every conflict, flag and check hit the script leaves is **resolved** by translating upstream's new text into pclaude, until the check is clean and the result is committed.

Three sides appear in every merge:

- **ours** is the file in `skills/pclaude/`: earlier translations plus Billy's edits.
- **base** is upstream at the sha in `skills/pclaude/UPSTREAM`, rendered (renamed `pstack` to `pclaude`, laid out like pclaude, not translated).
- **theirs** is upstream at the new sha, rendered the same way.

The diff from base to theirs is upstream's **intent**. Ours is the frame it lands in.

Work in the repo this skill is linked from:

```sh
REPO="$(git -C "$(dirname "$(readlink -f ~/.claude/skills/my-pclaude-update/SKILL.md)")" rev-parse --show-toplevel)"
```

## 1. Preflight

Run `git -C "$REPO" status --porcelain -- skills/pclaude scripts/pclaude-check.allow`.

**Done:** the output is empty. Uncommitted work there belongs to Billy. Show it to him and ask whether to commit it first. Never stash or discard it.

## 2. Run the update

```sh
"$REPO/scripts/pclaude-update.sh"
```

Give it a timeout of several minutes: it pulls `~/repos/pstack` (creating the sparse clone on a first run) and `git archive` fetches blobs on demand. Keep the full output. Its exit code routes the next step:

- **0**: merged cleanly and the check passed. Go to step 5.
- **1**: something needs resolving. The summary lists `CONFLICTS`, `FLAGGED` and `CHECK FAILED` sections, and its last line gives the paths of the rendered `base` and `theirs` trees. Go to step 3.
- **2**: it refused and changed nothing. If the reason is conflict markers left by an earlier run, resolve them as in step 3 using `git diff` against the last commit, then run the update again. Any other reason goes to Billy as printed.

**Done:** you hold the exit code, the summary lists, and (on exit 1) the two tree paths.

## 3. Resolve

Read [translation.md](translation.md) now. It holds the resolution procedure and the translation rules every resolved line must follow.

Work through every item in the summary:

- **CONFLICTS**: each file has standard `<<<<<<< pclaude` / `>>>>>>> upstream` markers. Resolve every hunk as `translation.md` says.
- **added** and **updated**: these were copied from theirs untranslated. Translate them like conflict text. A new skill also gets the pclaude skill shape described in `translation.md`.
- **merged cleanly**: read the upstream part of each merge (`diff base/<file> theirs/<file>`) and translate it in place. A clean merge only means the lines did not overlap.
- **FLAGGED**, by kind:
  - *deleted upstream, still here*: if ours is identical to `base/<file>` and nothing in `skills/pclaude/` links to it, delete it. Otherwise keep it and put it to Billy in step 5.
  - *changed upstream but deleted here*: Billy or the port removed it on purpose. Leave it deleted and name the upstream change in the summary.
  - *binary changed on both sides, kept ours*: compare the two images. Take theirs only when ours is just upstream's older version.

Every decision the rules do not settle (an upstream rewrite of a passage Billy reworded, a feature with no Claude Code substitute) gets the default `translation.md` gives, and goes on the **judgment-call list** for step 5.

**Done:** every listed file is handled, and `rg -n '^(<{7}|={7}|>{7})( |$)' "$REPO/skills/pclaude"` prints nothing.

## 4. Check until clean

```sh
"$REPO/scripts/pclaude-check.sh"
```

Each hit prints as `path:line: [rule] text`. Fix it by translating the line, per `translation.md`. Allowlist a line in `scripts/pclaude-check.allow` only when the flagged text is meant to stay, in a block that opens with a `#` comment saying why (the file's header gives the format). Re-run after each round of fixes.

If anything under `skills/pclaude/` that has a `package.json` changed, run `bun test` in that directory too.

**Done:** the check exits 0 with zero hits, and every `bun test` you ran is green.

## 5. Summarise and commit

Read what upstream did with `git -C ~/repos/pstack log --oneline <old>..<new> -- pstack`, the two shas coming from the script's `pclaude merged upstream <old> -> <new>` line. A first run prints only the new sha, so its summary lists the files brought in instead of a commit range.

Write Billy a summary:

1. Upstream range and its commits, grouped by what they changed in plain words.
2. Per file: added, taken, merged, resolved or deleted, with one line on any translation that went beyond a mechanical substitution.
3. The judgment-call list: each call, what you chose, and why. Put the open ones (a flagged file kept, a passage you could not port) as numbered questions, each with your recommendation.
4. New skills or agents. They become reachable once `scripts/link-skills.sh` runs with the `pclaude` set active, followed by a Claude Code restart. Tell Billy, and leave running it to him.

Then commit on the current branch, staging only `skills/pclaude/` and `scripts/pclaude-check.allow`:

```sh
git -C "$REPO" add skills/pclaude scripts/pclaude-check.allow
git -C "$REPO" commit -m "Merge upstream pstack <old7>..<new7> into pclaude"
```

When upstream had nothing new and `git status` shows no change, say so and make no commit. Pushing is Billy's call.

**Done:** the summary is in front of Billy and the commit sha is in it, or he has been told there was nothing to merge.
