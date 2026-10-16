# pclaude

Ported from pstack by poteto (MIT). See skills/pclaude/LICENSE.

Not promoted. A generated bucket that Billy edits directly, with no patch files. Upstream changes come in by three-way merge through `/my-pclaude-update`, a skill in the personal bucket. See `FORK.md` at the repo root.

Switch it on with `/king` or `scripts/use-skills.sh +pclaude`. Every skill here is user-invoked. Start at `/pclaude-help` or `/pclaude-poteto-mode <task>`. The rules every skill follows are in [CONVENTIONS.md](./CONVENTIONS.md), model roles in [models.md](./models.md), and the guide in [docs/](./docs/README.md).

- **[pclaude-architect](./pclaude-architect/SKILL.md)**: Sketch types, signatures and module structure before code, then stay in the loop while implementation fills in.
- **[pclaude-arena](./pclaude-arena/SKILL.md)**: Spawn parallel candidates at one task, pick a base, and graft the strongest parts of the rest into it.
- **[pclaude-automate-me](./pclaude-automate-me/SKILL.md)**: Draft or revise a personal `-mode` skill from your working style and recent transcripts.
- **[pclaude-benchmark-checklist](./pclaude-benchmark-checklist/SKILL.md)**: Vet a perf measurement before you report or act on it.
- **[pclaude-blast-radius](./pclaude-blast-radius/SKILL.md)**: Find what a change could break beyond the diff, and prove the fact it is safe because of.
- **[pclaude-bro](./pclaude-bro/SKILL.md)**: Restate the last message in plain language, with no jargon.
- **[pclaude-correct](./pclaude-correct/SKILL.md)**: Find the mistakes agents keep repeating in a repo and make each one impossible.
- **[pclaude-create-verification-skill](./pclaude-create-verification-skill/SKILL.md)**: Generate a project-local verification skill that drives the app the way a user does.
- **[pclaude-figure-it-out](./pclaude-figure-it-out/SKILL.md)**: Design an auditable playbook when no narrower one fits.
- **[pclaude-help](./pclaude-help/SKILL.md)**: Setup help, and picking the skill, playbook or principle for a task.
- **[pclaude-how](./pclaude-how/SKILL.md)**: Explain how code works, and where a change should live.
- **[pclaude-interrogate](./pclaude-interrogate/SKILL.md)**: Several reviewers challenge a change from independent angles.
- **[pclaude-in-your-own-words](./pclaude-in-your-own-words/SKILL.md)**: Restate the user's goals and problem in your own words.
- **[pclaude-ketchup](./pclaude-ketchup/SKILL.md)**: Catch the user up on what changed since their last message.
- **[pclaude-maintain-verification-skill](./pclaude-maintain-verification-skill/SKILL.md)**: Keep a project's verification skill and feature map honest.
- **[pclaude-no-comments](./pclaude-no-comments/SKILL.md)**: Spawn Comment Sicko, fix accepted findings, and offer encodings for claimed constraints.
- **[pclaude-poteto-mode](./pclaude-poteto-mode/SKILL.md)**: poteto's working style, with 23 playbooks, deliberate subagents and verified work.
- **[pclaude-principles](./pclaude-principles/SKILL.md)**: The 24 principles as a trigger index, each text in a leaf file beside it.
- **[pclaude-recall](./pclaude-recall/SKILL.md)**: Rebuild recent working context from your own chat history and live state.
- **[pclaude-reflect](./pclaude-reflect/SKILL.md)**: Review the active transcript and route each learning to an edit on an existing skill.
- **[pclaude-sharpen](./pclaude-sharpen/SKILL.md)**: Sharpen a task before starting it.
- **[pclaude-show-me-your-work](./pclaude-show-me-your-work/SKILL.md)**: Keep a reviewable decision log for long-running or unattended work.
- **[pclaude-swarm](./pclaude-swarm/SKILL.md)**: Fan out parallel workers, drain them, and return one report.
- **[pclaude-tdd](./pclaude-tdd/SKILL.md)**: Test-first work, only when asked or when a cheap local test target is obvious.
- **[pclaude-teach](./pclaude-teach/SKILL.md)**: Explain a body of work plainly, using `pclaude-how` and `pclaude-why`.
- **[pclaude-technical-writing](./pclaude-technical-writing/SKILL.md)**: A layered standard for docs, RFCs, PR descriptions and commit messages.
- **[pclaude-typescript-best-practices](./pclaude-typescript-best-practices/SKILL.md)**: TypeScript best practices for any `.ts` or `.tsx` edit.
- **[pclaude-unslop](./pclaude-unslop/SKILL.md)**: Cut AI tells from any writing.
- **[pclaude-why](./pclaude-why/SKILL.md)**: Explain why code works the way it does, with cited evidence.

Agents, linked into `~/.claude/agents` while the set is active:

- **[pclaude-poteto-agent](./agents/pclaude-poteto-agent.md)**: The delegate subagent for code-writing and helper tasks in a `/pclaude-poteto-mode` run.
- **[pclaude-comment-sicko](./agents/pclaude-comment-sicko.md)**: A comment-hater that savors deletion and condemns workaround code.
