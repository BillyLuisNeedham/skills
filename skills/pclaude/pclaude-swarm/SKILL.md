---
name: pclaude-swarm
description: "Fan out N parallel workers, drain them, and return one report. Use for /pclaude-swarm, 'swarm this', or parallel coverage, races, gauntlets, and exploration."
disable-model-invocation: true
---

# Swarm

## Start

Open a todolist with one entry per phase before launching anything.

1. Frame
2. Fan out
3. Aggregate
4. Report

## Phase A: Frame

1. State the done predicate and the artifact or report the swarm must return.
2. Choose the shape. Partition into slices, race N workers on identical briefs, or mix both. For a race or mixed shape, declare `first pass`, `rank all`, or `best-of` before spawning.
4. Pick the worker model from the `swarm workers` role in [models.md](../models.md) and pass its value as the Agent tool's `model`. For `inherit`, omit `model` so the workers run on the parent model. For a model race, name each arm's model up front.
5. Give each worker its own writable output when it writes. When workers verify or measure commits, each brief names the exact SHAs. A measurement brief also names the method (sample count, what one sample is, order). The worker records both in its result.

## Phase B: Fan out

Run the swarm from the main session, since Claude Code subagents cannot spawn subagents (see Nesting in [CONVENTIONS.md](../CONVENTIONS.md)). Spawn all N workers in one message as Agent calls with `subagent_type: "general-purpose"`, `isolation: "worktree"`, `run_in_background: true`, and the step 4 model, left unset for `inherit`. Each worker is a local background agent in its own git worktree. You are notified as each one finishes, so never poll. Use `isolation: "remote"` instead only when the user asks for remote workers (`/pclaude-swarm remote …`, "run it remote"). A remote worker has no access to this machine, so it sees only what is pushed.

A worktree starts from the current `HEAD`. When a worker must start from another branch or commit, its brief names it and tells the worker to check it out first. A remote worker can only start from a pushed branch, so push it first or keep that worker local.

Every brief stands alone. Include the goal, scope, exact slice or race arm, how to verify, and what to report. Reports use `PASS`, `ISSUES`, or `BLOCKED` with evidence. A worker that can prove a defect reports `ISSUES` and lists every issue it can prove, not only the first.

If a worker drops out, proceed with N-1 and note it.

## Phase C: Aggregate

Read the terminal results. Drop a result that does not record the SHAs and method its brief names, and respawn that worker once. After a second miss, record a gap. A gap does not count as a pass. For coverage, every required slice needs a result. For a race, apply the selection rule declared up front. Use first pass, rank all, or best-of. Do not paste raw worker dumps.

## Phase D: Report

Return one consolidated in-chat report with the table, issue one-liners, gaps or dropouts, and the race rule when used.

Ported from pstack by poteto (MIT). See skills/pclaude/LICENSE.
