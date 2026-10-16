---
name: pclaude-automate-me
description: "Use for \"automate me\", \"create/update/refresh my -mode skill\", \"turn/capture my preferences or working style into a skill\", or wanting agents to follow how the user works. Drafts or revises a personal -mode skill via writing-for-agents + pclaude-unslop, optionally pulling fresh evidence from recent transcripts."
disable-model-invocation: true
---

# Automate me

A guided flow for turning the user's working conventions into a skill agents will follow. The output is one `-mode` skill tailored to them (e.g. `jay-mode`, `priya-mode`).

This skill orchestrates three others: an inline mining pass (see step 1), the `writing-for-agents` skill (authoring, loaded with the Skill tool), and `pclaude-unslop` (prose discipline, `~/.claude/skills/pclaude-unslop/SKILL.md`). It sequences them. It doesn't replace them.

## Flow

### 0. Check for an existing skill

Look for `.claude/skills/*-mode/SKILL.md` in the project and `~/.claude/skills/*-mode/SKILL.md` matching the user's handle. Follow symlinks. A linked skill's source can live in a repo folder of its own, and that source is the file to edit. If one exists, confirm intent with a numbered question and your recommendation (Asking the human in [CONVENTIONS.md](../CONVENTIONS.md)), unless they already said "update my skill" or similar:

- Update the existing skill (default for repeat runs)
- Start fresh (rare, ask why before doing it)

Update mode changes the rest of the flow:
- Step 1 mines only history since the skill was last edited (`git log -1 --format=%cI <path>`).
- Step 2 asks what's changed or missing, not what to capture from zero.
- Step 4 edits the existing file in place. Preserve sections the user hasn't contradicted. Revise ones with new evidence. Add new sections only for genuinely new rules.

### 1. Mine their history

Read history through the transcript reader (Reading transcripts in [CONVENTIONS.md](../CONVENTIONS.md)), written here as `transcript`. `transcript list --since 28d --limit 200` lists the active project's chats. Use only that project. Never point `--project` elsewhere or glob across `~/.claude/projects/*/` unless the user asks, since that reads private chats from unrelated projects.

Survey recent agent conversations within that scope for recurring patterns. Run multiple parallel Agent calls on the `how explorer` line of [models.md](../models.md) across slices of history (e.g. last 2-4 weeks, split into 3 slices so each has enough material). Pick each subagent's reasoning level for the job, per the Subagents section of `~/.claude/skills/pclaude-poteto-mode/SKILL.md`. Each slice mining subagent gets its slice of session ids and reads each one with `transcript show <id>`, looks for the signals below, and returns a short structured list of patterns it saw with evidence pointers. Default signals worth hunting:

- Response preferences (length, tone, format, "dumb it down" corrections)
- Delegation habits (subagents, models, specialized workflows, parallelism)
- Verification posture (what "done" means, unit tests vs live repro, reviewers)
- Code and prose discipline (style, principles cited, lint/format tools)
- Process conventions (worktrees, commits, PRs, review/merge tooling)
- Meta preferences (fixing skills mid-task, proposing new ones)

Cross-check across slices before elevating a signal. Patterns seen in 2+ slices are high-confidence. Lone signals are weak and usually get dropped.

### 2. Ask the user directly

Mining misses intent that hasn't come up yet. Ask in plain text per Asking the human in [CONVENTIONS.md](../CONVENTIONS.md). Number the questions, ask them all at once, and give each one your recommendation drawn from what the mining found, so the user can answer in one reply.

Shape: one broad round first ("Which areas matter most?", with the mined candidates named so the user can confirm or strike them), then one follow-up round on the areas they picked. Close with one open question that catches anything the rounds missed.

Don't dump 20 questions.

### 3. Cluster findings

Group the combined signals into sections. Common ones (use only what applies):

- **Response style**: length, tone, format.
- **Autonomy**: how much to do without asking, MCP tool use.
- **Understand first**: which skills to reach for when scoping or investigating a change.
- **Subagents**: default, parallelism, model-to-task, specialized workflows.
- **Prose / code discipline**: principles, lint tools, style guides.
- **Review and verify**: repro posture, verification skills, live-testing tools.
- **Process**: git worktrees, commits, PRs, review/merge tooling.
- **Skills**: skill-authoring habits, fix-the-skill-first, proposing new skills.

`~/.claude/skills/pclaude-poteto-mode/SKILL.md` shows the shape. Read it for granularity. Don't copy its content. The user's rules are not the same as pclaude-poteto-mode's.

### 4. Draft the skill

Load the `writing-for-agents` skill with the Skill tool and follow it to author the skill. Placement:

- Path: preserve an existing mode skill's location. For a new mode, default to `.claude/skills/<handle>-mode/SKILL.md` in the project, or `~/.claude/skills/<handle>-mode/SKILL.md` if the user prefers a personal skill. Where the repo keeps its skills in folders of its own and links them into `~/.claude/skills/`, put it beside the user's other personal skills and link it the way they are linked.
- Handle: the user's first name or chosen identifier.
- Frontmatter `description`: trigger on their name + `/<handle>-mode` + "work in their style", not on generic keywords like "write code" or "review PR".
- Frontmatter formatting: follow `writing-for-agents`' YAML rules. Keep `description` as one YAML scalar. Quote it or use `description: >-` with indented continuation lines when punctuation or wrapping requires it.
- Frontmatter `disable-model-invocation: true` by default. Opt out only if the user explicitly wants their mode to apply on every turn.

### 5. Iterate on prose

Apply `pclaude-unslop` and `writing-for-agents`' writing guidelines to every line.

Show the draft to the user and take feedback. Expect multiple iterations. Cut ruthlessly. A mode skill is not a manual.

### 6. Land it

Work in a worktree off main. Commit and open a PR. Don't push to main directly.

## Guardrails

- **Don't overfit to one conversation.** A preference stated once and contradicted another time is noise. Require multiple instances before codifying it.
- **Don't be clever.** Restating other skills' contents, inventing metaphors, or writing "poetic" prose for an agent reader is cost without benefit. Keep it operational.
- **Reference, don't inline.** Other skills the user relies on should appear as path references, not pasted excerpts. Same for any principle docs they maintain elsewhere.
- **Keep sections minimal.** Only add a section if the user has a specific, non-default rule there. "Communicate clearly" is not a section. "Short paragraphs. Tables when comparing options. Bullets only when items are genuinely parallel." is.
- **Name conventions generic.** Use "the user" or "the human" in imperatives, not the author's first name.
- **Don't force symmetry.** If a user has no process rules worth writing down, skip the Process section entirely.

## Evaluation

A `-mode` skill is subjective output. A test/iterate benchmark loop isn't useful here. Vibe-check with the user: does it read like them? Did it miss anything? Then ship.

Run a description-optimization loop only if the skill's trigger accuracy turns out to be a problem in practice.

## When not to use

- User wants a task-specific skill (not working conventions): `writing-for-agents` alone, no mining required.
- User wants to capture one narrow workflow (e.g. "how I write commit messages"). That's a regular skill, not a mode skill.

Ported from pstack by poteto (MIT). See skills/pclaude/LICENSE.
