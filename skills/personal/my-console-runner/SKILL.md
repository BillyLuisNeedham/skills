---
name: my-console-runner
description: Point the Console at an existing ticket pool. Detects the pool's facts, interviews for the same six answers my-issue-runner asks, writes console.json and AGENT.md into the pool directory, then starts the Console server bound to that pool and opens the browser. Use when Issues already exist and you want to drive them from the Console instead of the terminal runner.
---

Issues already exist. This skill connects them to the Console.

It is the sibling of `my-issue-runner`: same detection, same interview, same pool on disk. Where
my-issue-runner writes `run.sh`, this skill writes `console.json` and `AGENT.md` into the pool
directory, then starts the Console server bound to that pool and opens the browser. **Never write
Issues here.** An empty or markerless pool is a reason to stop and say so, not a reason to invent
tickets.

The engine is one versioned copy, living at `~/repos/learning/ai-agent-graphs` (`engine/` for the
server, `ui/` for the Console). If that repo moves, update this line. The pool carries its own
config as data, so regenerating a pool's config never means copying engine code.

## How a Console run works

One server process per pool. Tickets whose blockers are all `done` run as one super-step, each in
its own git worktree, on the harness and model `console.json` assigns. Anything that needs a human
becomes an interrupt on that ticket's card: a checkpoint Brief, a merge-approval, a crash, a
deadlock, the final Review. Answering an interrupt resumes the pool. Line-1 state markers stay the
truth on disk, so a pool the Console drives remains drivable by `run.sh`.

## 0. Pointed at a configured pool

If the pool directory already holds `console.json` and `AGENT.md`, say so, show the config's
defaults and assignments, and ask one question: relaunch as-is, or re-interview. A relaunch goes
straight to step 5. A re-interview runs steps 1 to 4 and overwrites both files.

## 1. Detect

Look these up. Asking for them wastes a question:

- how many Issues sit in the pool's `issues/` directory, and whether every one carries a line 1
  state marker
- the `blocked-by` edges already written
- the repository's language and test framework
- the commit prefix in the last twenty commits
- which context files sit in the pool directory beside `issues/`, and their names
- whether the worktree is clean
- whether `~/.issue-runner` exists, and its contents if it does
- which of `claude`, `opencode` and `agent` are on PATH

Report all eight back in one short brief and get it confirmed. If the pool has no `issues/`
directory, no Issues in it, or any Issue without a state marker, say which and stop: the human
fixes the pool, or `to-tickets` writes it again. If the worktree is dirty, recommend committing
before launch: tickets commit to the current branch, and an unattended agent can sweep unrelated
changes into a commit that says it is the work of an Issue.

## 2. Ask

Six questions, each with your recommendation attached:

1. Which skill or skills drive each Issue, and whether that differs per Issue
2. The default harness and model. If `~/.issue-runner` already exists, read it, confirm it, and
   skip this question. If it does not, ask once and write it: two lines, `harness=..` and
   `model=..`
3. Whether any Issue should run on a different harness or model than the default, and which
4. The subagent roster, and a model for each
5. Whether a reviewer exists, and what authority it has
6. What counts as a checkpoint on this job specifically

Recommend the orchestrator's own model for every subagent unless there is a reason to go smaller.
Delegating a skill to a cheaper model moves the substance of an Issue onto that model, which is
the thing the runner exists to avoid.

If a reviewer is wanted, recommend it check acceptance criteria only and never code quality, and
that a failure buy the orchestrator one fix attempt before the Issue becomes a checkpoint carrying
the disagreement in its brief. That bounds a weaker model's power to strand good work.

The merge resolver is config, not a seventh question. Recommend the default harness for it, say
that an explicit `none` opts out so every conflict comes straight to the human, and write whatever
is agreed as the `resolver` key.

## 3. Check the drivers

For each skill named in answer 1, read its frontmatter. A skill carrying
`disable-model-invocation: true` can only be reached from the prompt, which is the one slot that
counts as the human typing, so **at most one such skill per Issue and it must be first**. Two is a
clash: name both, say which is blocked, and ask again.

In your own library `implement`, `triage`, `to-tickets`, `wayfinder` and
`thermo-nuclear-code-quality-review` all carry it. `tdd`, `code-review`, `diagnosing-bugs`,
`research`, `prototype`, `fits-the-codebase` and `resolving-merge-conflicts` do not.

Later skills in a chain run as subagents told to invoke them. That path is designed but unproven,
so put the weight of an Issue on the first driver rather than the tail of a chain.

Then check reachability per harness. The first driver goes in the prompt, so it must resolve as a
command on whatever harness the Issue is assigned:

- `claude` reaches every linked skill. Nothing to check.
- `opencode` only sees the stubs in `~/.config/opencode/command/`. If the driver's stub is
  missing, run `~/.claude/commands/scripts/link-opencode-commands.sh` before generating.
- `cursor` only sees real copies in `~/.cursor/skills/`. If the driver's copy is missing, run
  `~/.claude/commands/scripts/link-skills.sh` before generating.

Every harness named in the config must also be on PATH, from the detection brief. The engine fails
fast on an unknown harness at run start; getting it right here means the first super-step does not
stop for it.

## 4. Generate

Write `console.json` into the pool directory. All six answers land here as data:

```json
{
  "defaults": { "harness": "opencode", "model": "kimi-for-coding-oauth/k3", "drivers": "implement" },
  "assign": {
    "04": { "harness": "claude", "model": "claude-opus-4-1", "drivers": "implement code-review" }
  },
  "roster": "- deepseek (DeepSeek V4 Flash via opencode go): general-purpose subagent...",
  "agents": "{\"deepseek\": {\"description\": \"general-purpose subagent\", \"model\": \"...\"}}",
  "resolver": "opencode",
  "reviewer": "a reviewer checks acceptance criteria only; a failure buys one fix attempt",
  "checkpoint": "a device, an external write, an undecided decision, or a material guess"
}
```

- `defaults` holds answer 2 and the common case of answer 1. `drivers` is a space-separated chain:
  the first name is the driver, the rest run as the chain behind it.
- `assign` holds one entry per Issue that differs from the defaults, from answers 1 and 3. Omit
  Issues that use the defaults.
- `roster` is the roster as plain words for the prompt, from answer 4. `agents` is the same roster
  as a JSON string for claude's `--agents` flag. Keep the two in step.
- `resolver` is the merge resolver harness, or `none`. The engine falls back to the
  `~/.issue-runner` default when the key is absent, but write it explicitly so the pool's config
  says what it does.
- `reviewer` and `checkpoint` record answers 5 and 6. The engine does not read them; the agents
  do, through `AGENT.md`. Write both places from the one answer.

Then copy [`AGENT.template.md`](AGENT.template.md) into the pool directory as `AGENT.md`. Fill in
only what is below the CONFIG marker. The engine above the marker is the same in every runner and
that sameness is the point: leave it exactly as it is.

Below the marker:

- context files: the files detection found beside `issues/`, one bullet each, saying what each is
  for
- commit prefix: the one detection found
- this job's constraints: the reviewer authority and the checkpoint definition as rules, plus any
  environment quirks detection surfaced
- which Issues are expected to stop: from the checkpoint definition, so a checkpoint on those
  reads as correct rather than as a failure

## 5. Launch

One action, in order:

1. Build the Console if it is not built: `~/repos/learning/ai-agent-graphs/ui/dist/` must exist.
   If it does not, run `bun install` and `bun run build` in `~/repos/learning/ai-agent-graphs/ui/`.
2. Pick a port: 8787, or the next free one if it is taken.
3. If the pool's `runs/server.pid` names a live process, a server is already bound to this pool:
   skip to opening the browser. One pool, one server.
4. Start the server detached so it outlives this session, from the engine repo:

   ```
   nohup bun run engine/server.ts --pool "<pool>" --port <port> \
     >> "<pool>/runs/server.log" 2>&1 &
   echo $! > "<pool>/runs/server.pid"
   ```

5. Probe `http://localhost:<port>/api/state` until it answers with a snapshot. Then open the
   browser with the platform's opener:

   ```
   if [ "$(uname)" = "Darwin" ]; then
     open "http://localhost:<port>"
   else
     xdg-open "http://localhost:<port>"
   fi
   ```

Report the URL, the log path and the pid path. To stop the server later, kill the pid in
`runs/server.pid`.

Then stop. The run from here is the human's: tickets spawn real harnesses, checkpoints arrive as
interrupts, and the first launch of a pool is theirs to watch.

## What the engine already handles

Leave these alone rather than rediscovering them:

- The spawn kernel is ported from `run.sh`: non-interactive invocation with stdin closed, the
  fullest auto-approve permission mode per harness, the prompt glued from driver skill, AGENT.md,
  chain and roster. opencode gets the driver through `--command`; cursor's launch line comes from
  Cursor's documentation and is unproven.
- Upstream outcomes are injected into each ticket's prompt at spawn time, so downstream agents
  build on what upstream agents did.
- A ticket that exits without setting its line-1 status is a crash and surfaces as an interrupt
  carrying the log path.
- A merge conflict spawns the resolver agent; its resolution comes to the human as an approval
  interrupt, and rejecting hands the conflicted state over with the attempt noted.
- Line-1 markers are dual-written alongside the sqlite checkpoint and are the truth on conflict,
  so the pool on disk is always inspectable and `run.sh` agrees with the Console.
- Per-ticket logs land in the pool's `runs/` directory, same as my-issue-runner writes them.
- There is no spend cap. An unattended run spends until the pool quiesces.

---

## Guide

For the human. Written in Simplified Technical English.

### What you get

Two files in your pool directory. `console.json` holds your interview answers as data: the default
harness and model, per-ticket overrides, the subagent roster, the merge resolver, the reviewer and
what counts as a checkpoint. `AGENT.md` tells each agent what the job is. The Console server reads
both when it starts.

To change the default harness or model for every pool, edit `~/.issue-runner`. To change them for
one pool, edit that pool's `console.json`. To change one ticket, edit its entry under `assign`.

### How to start

Point the skill at a pool: `/my-console-runner <path-to-pool>`. It checks the pool, asks six
questions, writes the two files, starts the server and opens your browser. Run it again on a
configured pool to relaunch without the questions.

### How it stops

The pool runs until something needs you. Then it waits. A ticket's checkpoint, a merge that needs
your approval, a crash, a deadlock and the final Review all appear as interrupts on the card that
raised them. Answer in the card or in its Detail. The pool resumes when you answer. A stop at a
checkpoint is correct behaviour. Expect a good share of a real pool to stop this way.

### What it does not do

The server makes commits on the current branch. It does not push, and it does not open a pull
request. You do those, after you have read the log.

There is no spend cap. An unattended run spends until the pool stops.

The pool on disk stays drivable by `run.sh`. The line-1 markers are the truth both executors read.
