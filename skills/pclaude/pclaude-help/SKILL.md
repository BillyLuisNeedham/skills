---
name: pclaude-help
description: Guides users through pclaude setup, /pclaude-poteto-mode, and picking the skill, playbook, or principle for a task. Type /pclaude-help with a question.
disable-model-invocation: true
---

# Poteto help

Answer the user's question about pclaude, hand them a prompt they can send, and link the file the answer came from. For a help question, don't start the work. The user asked how, and a pclaude run spends real tokens, so let them send the prompt.

A message that asks for work, such as "use pclaude to fix this bug", is not a help question. Read `~/.claude/skills/pclaude-poteto-mode/SKILL.md`, do the work under it, and mention once that `/pclaude-poteto-mode <task>` starts it directly next time.

This file maps questions to the skills and guide pages that hold the answers. Those files own the details. Read the file you route to before you quote it, and trust it when it disagrees with this map. A skill linked here is at `~/.claude/skills/pclaude-<name>/SKILL.md`. The guide pages, `models.md` and `CONVENTIONS.md` sit in the bucket root, which is not linked into `~/.claude/skills/`. Find it with `realpath ~/.claude/skills/pclaude-help/..` and read them from there. Give the user that absolute path, since every installed skill is a symlink into their checkout of the skills repo.

## Find out what they need

Infer the need from the message and the conversation. A named situation, such as "which skill reviews a PR?", goes straight to its section. If the need is still unclear, ask which of these they want, as one numbered free-text question with your recommendation, then answer only the section they pick:

1. Get set up
2. Start a task with `/pclaude-poteto-mode`
3. Pick a skill for a situation
4. Fix a run that went wrong
5. Make pclaude my own

Check the state that changes the answer, and mention it only when it does:

- No `pclaude-poteto-agent.md` in `~/.claude/agents/` means the pclaude set is not active, so no pclaude skill or agent is linked. Point them at `/king`.
- No `verify-*` skill or other app harness in the project means agents have no scripted way to drive the app. Mention `/pclaude-create-verification-skill` when the question is about proving a change works.

## Get set up

1. Switch the pclaude set on with `/king add pclaude`, or `scripts/use-skills.sh +pclaude` from the skills repo. That links every pclaude skill into `~/.claude/skills/` and both agents into `~/.claude/agents/`. A running session picks the change up live. Run `/reload-skills` if a skill is still missing, and restart only if `~/.claude/agents/` did not exist when the session started.
2. Check the models. Every role reads its model from [`models.md`](../models.md). Edit a line there to change a role. There is no setup command.
3. Start a real task with `/pclaude-poteto-mode`, a goal, and a check that can pass or fail.

Every pclaude skill is user-invoked, so switching the set on changes nothing until the user types one. [Guide page 1](../docs/01-setup.md) has the details, and [`CONVENTIONS.md`](../CONVENTIONS.md) has the rules the skills follow. Offer to word their first prompt with them, per [`references/prompting.md`](references/prompting.md).

If cost is the worry, say where the tokens go and how to spend fewer. pclaude spends extra tokens on subagents and review panels. Set a role in `models.md` to `haiku` for cheaper runs, or to `inherit` to run it on the session's model. A shorter panel list runs fewer subagents, one for each entry. Save `/pclaude-poteto-mode` for work that needs rigor.

pclaude is built for Claude Code. Its workflow skills, including `/pclaude-poteto-mode`, `/pclaude-how`, `/pclaude-why`, and `/pclaude-teach`, spawn subagents with the Agent tool on the models `models.md` names. Other harnesses get the upstream copy instead, not pclaude.

## Start a task with `/pclaude-poteto-mode`

`/pclaude-poteto-mode` matches the task to a playbook, copies the playbook's steps into the todo list, and runs the other skills as the steps need them. A step it skips stays in the list as `skip: <reason>`. A good prompt states the goal and how to tell it's done. It doesn't list skills, because a hand-written sequence tends to drop or reorder steps the playbook would keep. Read [`references/prompting.md`](references/prompting.md) before you help word one. [Guide page 2](../docs/02-poteto-mode.md) has examples.

`/pclaude-poteto-mode <task>` loads the skill into the session for that task. Start each new task with it again, so the run matches a fresh playbook instead of treating the message as the next step. Mid-chat, "new task" does the same. `/pclaude-poteto-mode` already uses `pclaude-poteto-agent` for the subagents its playbook steps spawn. To get the same style from a subagent of your own, spawn it with `subagent_type: "pclaude-poteto-agent"`.

## Pick a skill

The default answer is `/pclaude-poteto-mode`, which runs most of the others when its steps need them. Name a skill directly when the user wants more or less of something than the playbook gives. Read the skill before you recommend it, and give one example prompt.

| The user wants to | Skill |
|---|---|
| Do any non-trivial task with rigor | [`/pclaude-poteto-mode`](../pclaude-poteto-mode/SKILL.md) |
| Check that the agent understood their goal and the problem before it starts | [`/pclaude-in-your-own-words`](../pclaude-in-your-own-words/SKILL.md) |
| Aim a task higher before starting: more expert, more outcome-focused, not overspecified | [`/pclaude-sharpen`](../pclaude-sharpen/SKILL.md) |
| Know how code works now, or where new code should live | [`/pclaude-how`](../pclaude-how/SKILL.md) |
| Know why code is shaped this way, or where a number came from | [`/pclaude-why`](../pclaude-why/SKILL.md) |
| Understand a change or subsystem, explained plainly | [`/pclaude-teach`](../pclaude-teach/SKILL.md) |
| Catch up on their own recent work on a topic | [`/pclaude-recall`](../pclaude-recall/SKILL.md) |
| Catch up on what changed in this chat since their last message, in a few plain sentences and small visuals, with enough context to decide each action item | [`/pclaude-ketchup`](../pclaude-ketchup/SKILL.md) |
| Know what a small diff could break outside itself | [`/pclaude-blast-radius`](../pclaude-blast-radius/SKILL.md) |
| Settle types and module shape before code that crosses a function boundary | [`/pclaude-architect`](../pclaude-architect/SKILL.md) |
| Get several attempts at one brief, merged into the best one | [`/pclaude-arena`](../pclaude-arena/SKILL.md) |
| Run parallel checks over slices, or race workers, as background agents in their own worktrees | [`/pclaude-swarm`](../pclaude-swarm/SKILL.md) |
| Have different models review a diff and try to break it | [`/pclaude-interrogate`](../pclaude-interrogate/SKILL.md) |
| Fix a bug test-first when a cheap local test exists | [`/pclaude-tdd`](../pclaude-tdd/SKILL.md) |
| Apply TypeScript rules to `.ts` or `.tsx` work | [`/pclaude-typescript-best-practices`](../pclaude-typescript-best-practices/SKILL.md) |
| Strip comments before review, using a reviewer that didn't write them | [`/pclaude-no-comments`](../pclaude-no-comments/SKILL.md) |
| Clean AI tells out of prose | [`/pclaude-unslop`](../pclaude-unslop/SKILL.md) |
| Write docs, an RFC, a README, a PR description, or a commit message to a standard | [`/pclaude-technical-writing`](../pclaude-technical-writing/SKILL.md) |
| Hear the last reply again in plain words | [`/pclaude-bro`](../pclaude-bro/SKILL.md) |
| Give agents a scripted way to drive the app and prove behavior | [`/pclaude-create-verification-skill`](../pclaude-create-verification-skill/SKILL.md) |
| Bring a verification skill and its feature map back in line with the app | [`/pclaude-maintain-verification-skill`](../pclaude-maintain-verification-skill/SKILL.md) |
| Vet a performance number before reporting or acting on it | [`/pclaude-benchmark-checklist`](../pclaude-benchmark-checklist/SKILL.md) |
| Run a large or cross-cutting change, or one to review after stepping away | [`/pclaude-figure-it-out`](../pclaude-figure-it-out/SKILL.md) |
| Keep a decision log during a run, and review it afterward | [`/pclaude-show-me-your-work`](../pclaude-show-me-your-work/SKILL.md) |
| See the 24 principles and when each applies | [`/pclaude-principles`](../pclaude-principles/SKILL.md) |
| Pick a model for each role | Edit [`models.md`](../models.md) |
| Turn their own working habits into a personal mode skill | [`/pclaude-automate-me`](../pclaude-automate-me/SKILL.md) |
| Turn what a finished task taught into skill edits | [`/pclaude-reflect`](../pclaude-reflect/SKILL.md) |
| Stop agents from repeating the same mistakes in this repo | [`/pclaude-correct`](../pclaude-correct/SKILL.md) |
| Find their way around pclaude | `/pclaude-help` |

If a `pclaude-*` skill directory next to this one is missing from the table, read its frontmatter and route by its description.

Close calls:

- `/pclaude-how` explains what the code does. `/pclaude-why` explains the reasons. `/pclaude-teach` runs one or both and explains the result plainly.
- `/pclaude-arena` gives every worker the same brief and merges the best parts. `/pclaude-swarm` splits work into slices or a race and returns one report.
- `/pclaude-architect` implements right after it settles the design. Add "with checkpoint" to review the design before it writes code.
- `/pclaude-interrogate` reviews the diff. `/pclaude-blast-radius` looks for breakage outside the diff and proves the one fact that makes the change safe.
- `/pclaude-recall` rebuilds context across recent chats. `/pclaude-ketchup` covers only this chat since the user's last message. Resuming one specific chat or branch is the Session pickup playbook.
- `/pclaude-figure-it-out` designs one rigorous run. The Orchestrate playbook runs a program that spans days and many PRs. The Autonomous run playbook drives one task to a finish condition.

Not in pclaude, but used by it:

- `/simplify` cleans code, `run` drives a CLI or app, `claude-in-chrome` drives a browser, and `writing-for-agents` shapes a skill. pclaude skills load them with the Skill tool when a step needs one.
- `/loop` is a Claude Code built-in. The overnight and autonomous playbooks use it.
- pclaude has no `/orchestrate` skill. Orchestrate is a `/pclaude-poteto-mode` playbook. If the slash menu shows `/orchestrate`, another skill set provides it.

## Playbooks and principles

Playbooks are step lists inside `/pclaude-poteto-mode`, not skills, so they have no slash command. Inside `/pclaude-poteto-mode`, describing the task picks one, and these phrases name one directly:

- "babysit this pr" or "check on pr 123" runs Babysit. It drives the PR to merge-ready and stops there. It doesn't merge unless the user asks to merge, land, or ship.
- "land the stack" runs Shipping.
- "take over this branch" runs Session pickup.
- "pause safely" runs Pause safely.
- "full autopilot on this queue" runs Autopilot-full. "stack them, don't ship" runs Autopilot-stack.
- "run the eval playbook" runs Eval.

Without `/pclaude-poteto-mode`, those phrases start nothing from pclaude, since every pclaude skill is user-invoked. Another active skill set may pick them up instead. The Playbooks section of [`pclaude-poteto-mode`](../pclaude-poteto-mode/SKILL.md) lists every playbook and when it applies. [Guide page 6](../docs/06-verify-and-ship.md) covers opening, babysitting, and landing a PR.

pclaude has no planning skill. Claude Code's plan mode works alongside it. For work that spans phases or stacked PRs, asking `/pclaude-poteto-mode` for a plan runs the [Multi-phase plan playbook](../pclaude-poteto-mode/playbooks/multi-phase-plan.md), which writes the plan and doesn't implement it. For a design question, the Prototype playbook or `/pclaude-architect` settles it in code first.

Principles are one-rule files that `/pclaude-poteto-mode` reads and cites in its replies. They live in `pclaude-principles/`, one leaf file per principle beside a trigger index. The user rarely reads one. They steer with the names instead, as in "apply prove it works. show me the real output." `/pclaude-principles` loads the index on demand. [Guide page 8](../docs/08-principles.md) lists them.

## Fix a run that went wrong

| Symptom | Fix |
|---|---|
| The mode stopped applying after a few turns | Start each task with `/pclaude-poteto-mode <task>`. After a long chat compacts, start it again. |
| A question got treated as the next step of the last task | Say "new task", or say the turn doesn't need the mode. |
| A new model choice had no effect | Skills read `models.md` when they spawn. A change applies from the next spawn, not to agents already running. |
| Runs cost more than expected | See the cost paragraph under Get set up. |
| A skill didn't load on its own | Every pclaude skill is user-invoked. They load when the user types them or when `/pclaude-poteto-mode` reads them, and it doesn't run every skill. |
| A pclaude skill or agent is missing from `/` | The pclaude set is off. Switch it on with `/king`, then `/reload-skills`. |
| Parallel agents overwrote each other | Give each agent its own worktree (`isolation: "worktree"`). Claude Code remote agents are the opt-in alternative. |
| An overnight run moved but finished nothing | `/loop` needs a check that can pass or fail, not a duration. See [guide page 7](../docs/07-overnight.md). |
| The reply claims success from a green build | Ask for the real command, flow, stored value, or profile. That's the prove-it-works principle. |

For a run that drifts, [`references/prompting.md`](references/prompting.md) has one-line steers. [Guide page 10](../docs/10-recipes-and-pitfalls.md) has more pitfalls and the recipes worth copying.

## Make pclaude my own

- [`/pclaude-automate-me`](../pclaude-automate-me/SKILL.md) drafts a personal mode skill from the user's own history, to use alongside `/pclaude-poteto-mode`.
- [`/pclaude-reflect`](../pclaude-reflect/SKILL.md) after a session turns its lessons into skill edits the user approves.
- `/pclaude-poteto-mode write a skill for <workflow>` runs the authoring playbook. The eval playbook tests a skill change blind.
- Edit `skills/pclaude/` directly. Upstream changes arrive by three-way merge through `/my-pclaude-update`, so local edits survive.
- Fix a misbehaving skill in its own PR, not inside the feature work where it went wrong.

[Guide page 9](../docs/09-make-it-yours.md) covers each of these.

## Reply

Lead with the answer. Give at most one example prompt in a code block, adapted from [`references/recipes.md`](references/recipes.md) when one fits, then the path to that file. Keep it short unless the user asked for the whole map.

Ported from pstack by poteto (MIT). See skills/pclaude/LICENSE.
