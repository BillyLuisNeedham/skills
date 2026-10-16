# Make it yours

pclaude-poteto-mode is one person's style. The machinery underneath, playbooks, routing, model roles, works just as well wearing yours. This page covers generating a personal skill in your own style, capturing lessons from a session, fixing the repo so agents stop repeating mistakes, authoring a focused skill, and testing a skill change before you trust it.

Start smaller than you think. You don't need many skills on day one, or even this whole skill set. Prompt plainly, watch where agents fail, and add a skill or a check when the same failure shows up twice.

## Generate your own skill with `/pclaude-automate-me`

```text
/pclaude-automate-me
```

You don't describe your style, because [`/pclaude-automate-me`](../pclaude-automate-me/SKILL.md) reads it out of your history. It mines the active project's recent transcripts in `~/.claude/projects` for repeated preferences, in how you like replies, delegation, verification, code, prose, and process, then asks you numbered questions about which patterns are really you. It drafts a `<your-name>-mode` skill with the `writing-for-agents` skill, runs the draft through [`/pclaude-unslop`](../pclaude-unslop/SKILL.md), and opens a PR from a worktree so you review it like any other change.

The result is shaped like [`/pclaude-poteto-mode`](../pclaude-poteto-mode/SKILL.md). It is a user-invoked skill (`disable-model-invocation: true`), so it loads only when you type `/<your-name>-mode <task>`. It lands in the project's `.claude/skills/<your-name>-mode/` by default, or in `~/.claude/skills/<your-name>-mode/` if you want it everywhere.

Run it again whenever your habits drift:

```text
/pclaude-automate-me update my mode skill with everything since its last edit
```

An update mines only the history since the skill last changed. It keeps rules you haven't contradicted, revises the ones with new evidence, and adds sections only for genuinely new patterns.

## Capture a session's lessons with `/pclaude-reflect`

Right after a task that taught you something, run:

```text
/pclaude-reflect that took way too long. capture what we learned so the next run doesn't repeat it.
```

[`/pclaude-reflect`](../pclaude-reflect/SKILL.md) sends the transcript to three parallel reviewers, then a synthesizer sorts the proposals into `Accepted`, `Rejected`, and `Backlog` and waits for your approval before any skill changes. Approve a proposal only if it would change a future decision. One weird session is an anecdote, not a rule.

## Fix the environment with `/pclaude-correct`

When you correct agents for the same mistake again and again, the fix belongs in the repo, not in your next prompt. Rank the options by how well they hold:

1. Make the mistake impossible with architecture or a better data structure.
2. Block it with types, or with a lint or CI check whose error names the fix.
3. Catch it with a test.
4. Write it down as a doc or agent rule. Nothing fails when an agent skips a rule, so this comes last.

Human review isn't on the list. A reviewer who must catch the same mistake on every PR is the problem this fixes. [`/pclaude-correct`](../pclaude-correct/SKILL.md) does the work:

```text
/pclaude-correct agents keep calling the database client directly instead of going through the repository layer
```

It reads recent commits, reverts, review comments, and comments that explain workarounds, then groups the mistakes into classes. A class counts once it has happened twice. It fixes the most frequent classes one commit each, at the highest level that works, and proves each new check fails on a real past mistake. It also keeps a table in the agent instruction file (`CLAUDE.md` or `AGENTS.md`) that pairs each rule with what enforces it, so a rule that nothing enforces shows up as a repeat. The reply lists each class with its evidence, the level chosen, and why a higher level didn't work.

Run it with no argument and it finds the classes from history on its own. `/pclaude-reflect` and `/pclaude-correct` split the work. `/pclaude-reflect` improves skills from one session. `/pclaude-correct` changes the repo so a mistake class can't come back. Pair it with `/pclaude-architect` when the fix is a new boundary. [Run many projects in parallel](./07-overnight.md#run-many-projects-in-parallel) has a prompt that does both across a whole repo.

## Author a focused skill

When you already know the workflow you want to capture:

```text
/pclaude-poteto-mode write a skill for verifying database migrations in this repo
```

Writing a skill matches the [Authoring or modifying a skill playbook](../pclaude-poteto-mode/playbooks/authoring-a-skill.md), which loads the `writing-for-agents` skill, follows [`CONVENTIONS.md`](../CONVENTIONS.md) for a pclaude skill, validates the frontmatter and links, and ships the result through the [Opening a PR playbook](../pclaude-poteto-mode/playbooks/opening-a-pr.md). Agent-facing prose has a higher bar than human prose, because an unhelpful sentence becomes an instruction some future agent follows. Let the playbook hold that bar rather than writing a `SKILL.md` freehand.

One special case has its own generator. A skill that must drive your app and prove behavior is a verification skill, so use [`/pclaude-create-verification-skill`](../pclaude-create-verification-skill/SKILL.md) and [`/pclaude-maintain-verification-skill`](../pclaude-maintain-verification-skill/SKILL.md) instead. [Verify and ship](./06-verify-and-ship.md#create-a-project-verification-skill) covers both.

## Write docs to a standard with `/pclaude-technical-writing`

Skills aren't the only prose you ship. For docs, RFCs, readmes, PR descriptions, and commit messages:

```text
/pclaude-technical-writing review the readme changes
```

[`/pclaude-technical-writing`](../pclaude-technical-writing/SKILL.md) applies a layered standard with one goal, prose a tired engineer understands on the first read. It picks the document's mode first (tutorial, how-to, reference, or explanation), then works sentence by sentence: who does what, one thought per sentence, nothing readable two ways. Use it to review what you or an agent just wrote, or name it up front when you ask for a doc.

## Test a skill change blind

A skill edit affects every future session, so test it like the experiment it is. The same goes for adopting someone else's skill. Check that it makes the agent better on your work before you keep it.

```text
/pclaude-poteto-mode run the eval playbook on this skill change. same task for both variants, candidates stay blind.
```

When a skill keeps missing and you know what it should do, change and test it in one task:

```text
/pclaude-poteto-mode update the review skill so it flags missing migrations, and eval the change.
```

Asking for the eval up front keeps the edit honest. A fix written from one bad session tends to overfit that session, and over many edits the skill drifts. The eval catches the drift before it ships.

The [Eval playbook](../pclaude-poteto-mode/playbooks/eval.md) is built around one failure mode, the observer effect. An agent that knows it's being evaluated behaves differently. So candidate agents get an organic-looking task in sanitized directories, never the words "eval" or "candidate", and never each other's existence. One judge scores all outputs under neutral labels, and chain-following gets graded from which files each candidate actually read, not from what it claims.

Read every output yourself before accepting the verdict. If you disagree with the judge, suspect the rubric before you suspect your judgment.

**Pitfall:** don't edit a skill mid-task because it's misbehaving. Fix it in its own PR and keep the task moving. A skill edit that ships tangled into feature work is invisible to review and impossible to evaluate.

Next: [Recipes and pitfalls](./10-recipes-and-pitfalls.md).
