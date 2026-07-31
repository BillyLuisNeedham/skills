---
name: sitrep
description: Dispatch a subagent to build a visual sitrep of the work in flight and open it in the browser.
disable-model-invocation: true
argument-hint: "What the sitrep should focus on, or nothing for the whole picture"
---

A **sitrep** answers "where are we?" for the work in flight — the mission, the current situation, the next move — as a self-contained HTML page that opens in the user's browser.

Building one is expensive: reading files, checking the repo, drawing diagrams, writing HTML. A subagent does all of it, so the cost lands in its context rather than yours. Your job is the brief.

### 1. Write the brief

The subagent starts blind. The brief carries the one thing it cannot recover on its own: this conversation.

Write it as prose, covering:

- **The mission** — what we're solving, and why we're solving it
- **The position** — what's done, what's in flight, what's untouched
- **The decisions** — what we chose, and the reasoning that got us there
- **The open ground** — unresolved questions, blockers, things we deliberately parked
- **The pointers** — paths to the files, commands, tests, and errors that matter. Name them by path; the subagent reads them itself.

Write from memory of the conversation — no files to open, no commands to run. It's finished when someone who has read none of this conversation could reconstruct the situation from it alone. Length follows from that bar; there is no target.

If the user passed an argument, treat it as the sitrep's focus and weight the brief toward it.

### 2. Dispatch

One `Agent` call, `general-purpose` subagent, running in the background. Its prompt is the brief plus this instruction:

> Read `<absolute path to REPORT.md in this skill's directory>` first and follow it. Everything below is your brief.

The subagent writes the HTML and opens it in the browser itself — nothing comes back to you but a path.

### 3. Carry on

Tell the user the sitrep is being built, and resume the work you were doing. When the notification arrives, relay the file path in one line.
