---
name: my-issue-runner
description: Generate a bespoke shell runner that works a queue of Issues unattended, one fresh orchestrator per Issue, halting at any Issue that needs a human. Use when Issues already exist and you want them worked without sitting there, or to regenerate an existing runner onto a newer engine.
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

## 1. Detect

Look these up. Asking for them wastes a question:

- how many Issues, and whether every one carries a line 1 state marker
- the `blocked-by` edges already written
- the repository's language and test framework
- the commit prefix in the last twenty commits
- which context files sit beside the Issues, and their names
- whether the worktree is clean

Report all six back in one short brief and get it confirmed. If any Issue lacks a state marker, say
which and stop: the human adds them, or `to-tickets` writes the queue again.

## 2. Ask

Six questions, each with your recommendation attached:

1. Which skill or skills drive each Issue, and whether that differs per Issue
2. The orchestrator's model
3. The subagent roster, and a model for each
4. Whether a reviewer exists, and what authority it has
5. A spend cap per Issue, or none
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

## 4. Generate

Copy [`run.template.sh`](run.template.sh) and [`AGENT.template.md`](AGENT.template.md) into the
queue's directory as `run.sh` and `AGENT.md`. Fill in only what is below each CONFIG marker. The
engine above each marker is the same in every runner and that sameness is the point: leave it exactly
as it is.

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

- macOS ships bash 3.2, where an empty array expansion aborts under `set -u`. Hence
  `${A[@]+"${A[@]}"}`.
- `--max-budget-usd` passed empty caps spend at zero, so the flag is built conditionally.
- GNU and BSD `sed -i` disagree, which `sedi()` normalises.
- `claude -p` waits three seconds for stdin that never comes, so stdin is closed.
- `auto` is the only permission mode that works unattended. `acceptEdits` still gates shell commands
  and a gated command in an unattended run fails rather than waits.
- An interrupt returns the Issue to `ready` and leaves a note on it.
- Exit codes: 0 finished, 1 preflight refusal, 2 checkpoint, 3 no status set.

---

## Guide

For the human. Written in Simplified Technical English.

### What you get

Two files in the directory that holds your Issues. `run.sh` does the work. `AGENT.md` tells each
agent what the job is.

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

### How it stops

The runner stops for four reasons.

- All of the Issues are done. The exit code is 0.
- The repository is not clean, or the queue is not there. The exit code is 1.
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
