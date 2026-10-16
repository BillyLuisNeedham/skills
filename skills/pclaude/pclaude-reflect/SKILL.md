---
name: pclaude-reflect
description: Spawn three parallel review subagents over the active transcript, surface learnings, and route each to a concrete edit on an existing skill. Use when the user says reflect.
disable-model-invocation: true
---

# Reflect

Mine the current conversation for durable learnings, then route them into skill edits.

Invoke when the user says "reflect" or "/pclaude-reflect". Skip when the conversation is trivial, off-topic, or already covered by an existing skill the parent followed correctly. One-offs are not learnings.

## 1. Locate the active transcript

Before fanning out, find this conversation's transcript with the transcript reader (Reading transcripts in [CONVENTIONS.md](../CONVENTIONS.md)). It stays inside the active project, so it never reads private chats from unrelated projects.

```bash
bun ~/.claude/skills/pclaude-poteto-mode/scripts/transcript/transcript.ts info current
```

`current` resolves `$CLAUDE_CODE_SESSION_ID`, and the `path:` line is the transcript to hand the reviewers. Check that its first prompt is this conversation's opening prompt. If the variable is unset or the prompt does not match, pass a tight digest of the session instead.

## 2. Spawn three reviewers in parallel

One message, three Agent calls from the main session (see Nesting in [CONVENTIONS.md](../CONVENTIONS.md)), `subagent_type: "general-purpose"`, `run_in_background: true`. Reviewers need MCP access to look up the tickets, chat threads, and observability traces the transcript references, and `Explore` has no MCPs. Tell each reviewer not to edit files.

Each reviewer and the synthesizer name a role in [models.md](../models.md). Pass the role's value as the Agent tool's `model`, and omit `model` when the value is `inherit`. Pick each subagent's reasoning level for the job, per the Subagents section of `~/.claude/skills/pclaude-poteto-mode/SKILL.md`.

| Lens | Role | Prompt template |
|---|---|---|
| Judgment | `reflect judgment, divergent, synthesizer` | `references/judgment-reviewer.md` |
| Tooling | `reflect tooling` | `references/tooling-reviewer.md` |
| Divergent | `reflect judgment, divergent, synthesizer` | `references/divergent-reviewer.md` |

Pass each template verbatim, substituting the transcript path or digest where marked. Reviewers return findings in the Agent result.

## 3. Synthesize

One Agent call, `subagent_type: "general-purpose"`, `model` from the `reflect judgment, divergent, synthesizer` role. It spot-verifies citations through MCP, which `Explore` lacks. Tell it not to edit files. Pass `references/synthesizer.md` verbatim, with each reviewer's full output inlined where marked. It returns an Accepted / Rejected / Backlog list.

## 4. Structural enforcement check

Move any Accepted item that a lint rule, script, metadata flag, or runtime check would enforce more reliably to Backlog. See the Encode Lessons in Structure principle (`~/.claude/skills/pclaude-principles/encode-lessons-in-structure.md`).

## 5. Apply

Present the synthesizer's full Accepted / Rejected / Backlog output and wait for explicit approval before applying any Accepted edit. The user picks the subset and may redirect routings. Skill changes affect every future agent in the org. Do not auto-apply.

File each Backlog item to your team's devex or backlog tracker without waiting. Only the Accepted list waits for approval.

Follow each approved row's Routing exactly:

- Trivial existing-skill edit (a one-line bullet, a tightened sentence, a stale fact corrected): the parent does it directly.
- Substantive existing-skill edit (a new section, a new pattern table, more than ~10 lines): load the `writing-for-agents` skill with the Skill tool and follow it while you draft, test and iterate.
- `tune description: <skill path>` (the skill exists but didn't trigger when it should have): rewrite the description per `writing-for-agents`.
- `new skill: <kebab-name>`: author it with `writing-for-agents`. Do not invent the shape ad hoc.

If your environment ships a SKILL.md validator, run it on every touched skill before declaring done.

## 6. Summarize for the user

Short list, no preamble:

- Edits applied: `<skill path>`. What changed, one line each.
- New skills created: `<skill path>`. One line each (rare).
- Backlog filed to the devex tracker: `<issue title>` (`<tags>`). One line each.
- Dropped: one line per rejected finding + reason from the synthesizer.

Ported from pstack by poteto (MIT). See skills/pclaude/LICENSE.
