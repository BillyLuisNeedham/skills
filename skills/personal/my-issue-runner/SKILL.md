---
name: my-issue-runner
description: Generate a bespoke shell runner that works a queue of Issues unattended, one fresh orchestrator per Issue on the harness each Issue is assigned, halting at any Issue that needs a human. Use when Issues already exist and you want them worked without sitting there, or to regenerate an existing runner onto a newer engine.
---

Issues already exist. This skill writes the thing that runs them.

It generates two files into the directory holding a queue: `run.sh` and `AGENT.md`. Each job gets its
own pair. The engine inside them is identical every time; everything specific to the job is data the
interview supplies. **Never write Issues here.** A queue with no Issues in it is a reason to stop and
say so, not a reason to invent them.

This is the executor for what `to-tickets` produces.

## How the runner works

State lives on line 1 of each Issue file, so an interrupted run resumes:

```
<!-- state: id=NN blocked-by=01,04 status=ready -->
```

`status` is `ready`, `in-progress`, `done` or `checkpoint`. `blocked-by` is a comma list or `none`.
The runner takes the first Issue that is `ready` with every blocker `done`, sets it `in-progress`,
starts one orchestrator, then reads the marker back. `done` continues. `checkpoint` prints the
Issue's `## Brief` and stops. Anything else counts as a crash and also stops.

Each Issue runs on a **harness**: `claude`, `opencode`, or `cursor` (the `agent` CLI). The default
harness and model live in `~/.issue-runner`, which the runner reads every time it starts. A
per-Issue override lives in the runner's `assign_for` function.

## 1. Detect

Look these up. Asking for them wastes a question:

- how many Issues, and whether every one carries a line 1 state marker
- the `blocked-by` edges already written
- the repository's language and test framework
- the commit prefix in the last twenty commits
- which context files sit beside the Issues, and their names
- whether the worktree is clean
- whether `~/.issue-runner` exists, and its contents if it does
- which of `claude`, `opencode` and `agent` are on PATH

Report all eight back in one short brief and get it confirmed. If any Issue lacks a state marker, say
which and stop: the human adds them, or `to-tickets` writes the queue again.

## 2. Ask

Six questions, each with your recommendation attached:

1. Which skill or skills drive each Issue, and whether that differs per Issue
2. The default harness and model. If `~/.issue-runner` already exists, read it, confirm it, and skip
   this question. If it does not, ask once and write it: two lines, `harness=..` and `model=..`
3. Whether any Issue should run on a different harness or model than the default, and which
4. The subagent roster, and a model for each
5. Whether a reviewer exists, and what authority it has
6. What counts as a checkpoint on this job specifically

Recommend the orchestrator's own model for every subagent unless there is a reason to go smaller.
Delegating a skill to a cheaper model moves the substance of an Issue onto that model, which is the
thing the runner exists to avoid.

If a reviewer is wanted, recommend it check acceptance criteria only and never code quality, and that
a failure buy the orchestrator one fix attempt before the Issue becomes a checkpoint carrying the
disagreement in its brief. That bounds a weaker model's power to strand good work.

## 3. Check the drivers

For each skill named in answer 1, read its frontmatter. A skill carrying
`disable-model-invocation: true` can only be reached from the prompt, which is the one slot that
counts as the human typing, so **at most one such skill per Issue and it must be first**. Two is a
clash: name both, say which is blocked, and ask again.

In your own library `implement`, `triage`, `to-tickets`, `wayfinder` and
`thermo-nuclear-code-quality-review` all carry it. `tdd`, `code-review`, `diagnosing-bugs`,
`research`, `prototype`, `fits-the-codebase` and `resolving-merge-conflicts` do not.

Later skills in a chain run as subagents told to invoke them. That path is designed but unproven, so
put the weight of an Issue on the first driver rather than the tail of a chain.

Then check reachability per harness. The first driver goes in the prompt, so it must resolve as a
command on whatever harness the Issue is assigned:

- `claude` reaches every linked skill. Nothing to check.
- `opencode` only sees the stubs in `~/.config/opencode/command/`. If the driver's stub is missing,
  run `scripts/link-opencode-commands.sh` before generating.
- `cursor` only sees real copies in `~/.cursor/skills/`. If the driver's copy is missing, run
  `scripts/link-skills.sh` before generating.

The runner's preflight checks all of this again at every start. Getting it right here means the
first run does not stop for it.

## 4. Generate

Copy [`run.template.sh`](run.template.sh) and [`AGENT.template.md`](AGENT.template.md) into the
queue's directory as `run.sh` and `AGENT.md`. Fill in only what is below each CONFIG marker. The
engine above each marker is the same in every runner and that sameness is the point: leave it exactly
as it is.

Below the markers:

- `drivers_for`: the skills per Issue, from answer 1
- `assign_for`: one case arm per Issue that differs from the default, from answer 3. The default arm
  echoes an empty string, which means "use `~/.issue-runner`"
- `AGENTS` and `ROSTER_TEXT`: the roster as JSON for claude, and the same roster as plain words for
  the prompt, from answer 4. Keep the two in step
- `AGENT.md`'s config sections: context files, commit prefix, this job's constraints, which Issues
  are expected to stop

`chmod +x run.sh`.

## 5. Verify, then stop

Run `./run.sh status` and `./run.sh next`. Both must print a sane board and a sane frontier before you
hand over. They spend nothing.

Then stop. The human reads the two files and commits them. Never start the queue on their behalf.

## Regenerating onto a newer engine

Run the skill again on a directory that already has a bundle. Replace everything above each CONFIG
marker, leave everything below untouched, print the old and the new `engine-version`, and say once
that the engine was overwritten. Do not offer to merge hand-edits above a marker: the reason to
regenerate is a fixed bug, and keeping the old engine keeps the bug.

## What the engine already handles

Leave these alone rather than rediscovering them:

- GNU and BSD `sed -i` disagree, which `sedi()` normalises.
- Every harness's non-interactive mode waits on stdin that never comes, so stdin is closed.
- `auto` (claude), `--auto` (opencode) and `--force --trust` (cursor) are the permission modes that
  work unattended. Anything gentler gates a shell command, and a gated command in an unattended run
  fails rather than waits.
- opencode does not expand a slash command inside a `run` message. The driver goes through
  `--command` with the bare skill name, and the Issue path and the glued instructions become the
  message, which opencode passes to the command as its arguments.
- The prompt leads with the driver skill and glues `AGENT.md`, the chain and the roster behind it,
  because opencode and cursor have no flag for standing instructions. Proven end-to-end on opencode.
  On claude the same shape relies on the CLI passing everything after the command name, newlines
  included, as the skill's arguments; on cursor, on `agent -p` expanding a leading slash command at
  all. Treat the first run on each as a proving flight.
- The roster reaches non-claude harnesses as words only. opencode and cursor dispatch whatever agents
  the user's own config defines under those names.
- There is no spend cap. No harness except claude ever supported one, and it was removed rather than
  kept as a claude-only lie.
- The cursor launch line is written from Cursor's CLI docs and has not run on a real queue. Treat the
  first cursor run as a proving flight.
- An interrupt returns the Issue to `ready` and leaves a note on it.
- Exit codes: 0 finished, 1 preflight refusal, 2 checkpoint, 3 no status set.

---

## Guide

For the human. Written in Simplified Technical English.

### What you get

Two files in the directory that holds your Issues. `run.sh` does the work. `AGENT.md` tells each
agent what the job is.

Each Issue runs on a harness: Claude Code, OpenCode, or Cursor's agent CLI. Your usual harness and
model live in `~/.issue-runner`. Edit that one file to change the default for every queue. To run
one Issue on something different, edit its line in `assign_for` inside `run.sh`.

### How to start

Make sure that all of your work is committed. The runner does not start if the repository has changes
to tracked files. This is deliberate. An unattended agent can put your changes into a commit that
says it is the work of an Issue.

Then run one of these:

```
./run.sh              work the queue until it stops
./run.sh status       show the board. This changes nothing
./run.sh next         show which Issue is next. This changes nothing
./run.sh reset NN     put Issue NN back to ready
```

Before it starts, the runner checks that every unfinished Issue has a harness and a model, that each
harness it will use is installed, and that each harness can reach the skill that drives its Issue.
A failure stops the run with a message that says what to fix. This is deliberate. These are the
failures that would otherwise stop the queue hours in.

### How it stops

The runner stops for four reasons.

- All of the Issues are done. The exit code is 0.
- The repository is not clean, or the queue is not there, or a preflight check failed. The exit code
  is 1.
- An Issue needs you. The exit code is 2. The runner prints the brief for that Issue.
- An agent stopped and did not set its status. The exit code is 3. The runner writes a note on the
  Issue and tells you which log to read.

A stop at a checkpoint is correct behaviour. Approximately one half of a real queue stops this way.

### What to do at a checkpoint

Read the brief. It tells you what the agent did, what you must do, and what comes next. Do your part.
Then run `./run.sh reset NN` and start the queue again.

### If you stop the runner yourself

Press Ctrl-C. The runner puts the Issue back to `ready` and writes a note on it. Read that note
before you start the queue again. The work is part done, and the agent did not commit it.

### What it does not do

The runner makes commits. It does not push, and it does not open a pull request. You do those, after
you have read the log.

There is no spend cap. An unattended run spends until the queue stops.

The OpenCode harness is proven end-to-end on a real queue. The Claude harness carried over from the
old engine but its glued-prompt shape has not run since the change. The Cursor harness is not yet
proven: its launch line comes from Cursor's documentation, not from a real run. The first time you
send an Issue to either, watch it.
