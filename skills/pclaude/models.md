# pclaude models

Every pclaude skill names a role from this file instead of a model. When a skill says "the `swarm workers` model", look the role up here and pass its value as the Agent tool's `model`.

Billy edits this file directly. A changed line takes effect the next time a skill reads it.

## Values

- `sonnet` runs code and exploration.
- `opus` runs judgment, prose and the hardest changes.
- `haiku` runs mechanical helpers: moving files, summarising a log, polling a status.
- `inherit` runs the role on the parent session's model. Omit `model` from the Agent call.

A role whose value is a list is a panel. Spawn one agent per entry, so the list length sets the panel size. An `inherit` entry still counts toward the panel.

## Roles

| Role | Model |
| --- | --- |
| feature, refactoring | `sonnet` |
| bug-fix | `sonnet` |
| perf-issue | `sonnet` |
| hillclimb | `sonnet` |
| hardest tasks | `opus` |
| judgment and prose | `opus` |
| mechanical helpers | `haiku` |
| how explorer | `sonnet` |
| how explainer | `opus` |
| why investigators | `sonnet` |
| why synthesizer | `opus` |
| reflect tooling | `sonnet` |
| reflect judgment, divergent, synthesizer | `opus` |
| arena runners | `opus`, `sonnet` |
| arena cross-judge pool | `opus` |
| swarm workers | `sonnet` |
| architect runners | `opus`, `sonnet` |
| interrogate reviewers | `opus`, `sonnet` |

## Choosing between roles

Code delegates tier by difficulty. The hardest changes (cross-cutting design, subtle concurrency, delicate algorithms) use `hardest tasks`, whether the work needs judgment on vague intent or is a precise sequence to execute to the letter. Trivial mechanical edits use `mechanical helpers`. Everything else uses the line for its playbook.

## A judge from a different model family

Where a skill asks for a judge or reviewer from a different model family than the one that produced the work, spawn a fresh-context `opus` agent. Fresh context is the independence: give it the artifact and the criteria, never the producer's reasoning or transcript.

## Effort

Leave the Agent tool's `effort` unset. The session's own setting applies. Set it only where a skill or Billy explicitly asks for a level.
