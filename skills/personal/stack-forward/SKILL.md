---
name: stack-forward
description: Merge forward through stacked PR branches without rewriting history. Use after a fix lands on a branch with PRs stacked above it, or after the bottom PR of a stack squash-lands into its base.
---

Takes one branch in `Hostelworld-ms/android-app`: a feature branch a fix just landed on, or the project branch a PR just squash-landed into. Each step ends on its **Done:** line; stop and report to the user at any step that cannot reach it.

History is only ever added to: plain merges and fast-forward pushes. After a squash-land, GitHub retargets the next PR onto the project branch while that PR's branch still carries the landed commits; merging the project branch in clears them from the diff, and the merge is normally clean because the squash commit's tree matches.

`stack-forward.sh` (beside this file, at `~/.claude/skills/stack-forward/stack-forward.sh`) does all the local work in one process: it reads the stack from open PRs, merges each parent into each child (parent before child, fanning out depth first) on detached HEADs in a scratch worktree, runs the gate at each changed tip, and only then fast-forwards the local branches. It never touches your checkout or any other worktree, removes its scratch worktree on every exit, and pushes nothing. Run it from any checkout of the repo, or pass `--repo <dir>`.

## 1. Plan

```sh
~/.claude/skills/stack-forward/stack-forward.sh --dry-run <branch>
```

It prints the stack as a tree, which branches need a merge, and which are tips. It changes nothing: it reads origin with `git ls-remote` and fetches nothing.

**Done:** the tree matches the stack you expect, and the output lists no problems. Each problem is a stop: a branch checked out in another worktree, or a local branch that is ahead of or diverged from origin. Report them to the user rather than moving or deleting branches yourself. A "not fetched" note is fine; the real run fetches.

## 2. Merge and gate

Run the same command without `--dry-run`, with `run_in_background: true`, and wait for it to finish. The gate is `./gradlew testDebugUnitTest assembleDebug` at each tip, and agent Gradle builds queue behind a machine-wide lock, so a wait of many minutes is normal.

Exit codes:

- **0**: done. Either every branch already contained its parent (nothing to push), or the gate passed and the local branches moved; the output ends with the push list.
- **1**: merge conflict. It names the branch and the conflicting files. Nothing moved.
- **2**: preflight problem, as in step 1. Nothing moved.
- **3**: gate failed at the named tip, with the log's last 40 lines. Nothing moved.
- **5**: a branch changed under the run. Branches before it in the report moved; the rest did not.

**Done:** exit 0. On any other exit, report the output to the user and stop: there is nothing to push.

## 3. Push

Pushing is outward-facing. Push only with standing approval: a pool ticket has it when its pool CONFIG grants pushing; otherwise show the user the report from step 2 and ask first.

Run each line of the push list as its own Bash call, exactly as printed, parents first:

```sh
git push origin <branch>
```

One plain command per call (no pipes, no `&&`, no `cd` prefix), because the auto-mode permission rules match single commands. Each push is a fast-forward. If one is rejected, origin moved during the run: stop, report it, and run this skill again.

**Done:** every branch in the push list pushed.

## 4. Report

Give the user one line per branch: old sha to new sha, merged or already up to date, the gate result at its tip, and pushed or not.
