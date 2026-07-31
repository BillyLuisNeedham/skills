---
name: sitrep-figure-it-out
description: Build a sitrep from the session transcript on disk, so the working agent spends almost nothing.
disable-model-invocation: true
argument-hint: "What the sitrep should focus on, or nothing for the whole picture"
---

The record-based twin of `sitrep`. Same output — a self-contained HTML page showing where the work stands, opened in the user's browser — reached a different way.

`sitrep` runs on **testimony**: you write the brief from memory, which is accurate about intent but costs you the writing. This one runs on the **record**: a subagent reconstructs the situation from the session transcript on disk. Your part is two commands.

### 1. Locate the transcript

```bash
ls -t "$HOME/.claude/projects/$(pwd | sed 's/[/.]/-/g')"/*.jsonl | head -1
```

Sessions are stored as one JSONL file per session, named for the session UUID, appended live as the conversation runs — so the newest file at that path is this conversation. If several sessions are open on this repo, prefer the file whose basename matches the session UUID in your scratchpad path.

### 2. Dispatch

One `Agent` call, `general-purpose` subagent, running in the background. Its prompt:

> Read `<absolute path to RECONSTRUCT.md in this skill's directory>` first and follow it. The session transcript is at `<transcript path>`.

Add the user's argument as the sitrep's focus if they passed one. Everything else — mining the transcript, writing the brief, building the page, opening it — happens below you.

### 3. Carry on

Tell the user the sitrep is being built, and resume the work you were doing. When the notification arrives, relay the file path in one line.
