# The pclaude guide

pclaude works best when you stop micromanaging the agent. You describe what you want and how you'll know it's done. `/pclaude-poteto-mode` picks the playbook, runs the other skills as the steps need them, and shows you the evidence. This guide teaches that habit with realistic prompts.

Here's what you'll learn:

1. [Set up pclaude](./01-setup.md). Turn on the pclaude skill set and check which models it uses.
2. [Route work through `/pclaude-poteto-mode`](./02-poteto-mode.md). Give it a goal and watch it pick a playbook.
3. [Understand the code](./03-understand.md). A read-only investigation, then `/pclaude-how`, `/pclaude-why`, `/pclaude-teach`, and `/pclaude-recall` before you edit anything.
4. [Design the change](./04-design.md). `/pclaude-architect`, `/pclaude-arena`, `/pclaude-swarm`, `/pclaude-interrogate`, prototypes, and plans before code locks in a shape.
5. [Build and clean the change](./05-build-and-clean.md). The build playbooks, `/pclaude-tdd`, `/pclaude-unslop`, and `/pclaude-no-comments`.
6. [Verify and ship](./06-verify-and-ship.md). Prove behavior on the real app, vet numbers with `/pclaude-benchmark-checklist`, then open a focused PR and drive it to merged.
7. [Run work while you sleep](./07-overnight.md). Trust before loops, an overnight contract, a decision log you can audit, and the playbooks that scale past one agent.
8. [Steer with principle names](./08-principles.md). The 24 names that redirect an agent mid-task.
9. [Make it yours](./09-make-it-yours.md). Your own mode skill, `/pclaude-correct` for repeated mistakes, and how to test a skill change.
10. [Recipes and pitfalls](./10-recipes-and-pitfalls.md). Prompts to copy and mistakes to skip.

Read the pages in order the first time. After that, each page stands alone.

When you're stuck, or can't tell which skill fits, type [`/pclaude-help`](../pclaude-help/SKILL.md) with your question:

```text
/pclaude-help which skill should i use to review this branch?
```

It answers, hands you a prompt to send, and links the skill or guide page the answer came from. It doesn't start the work, because a pclaude run spends real tokens, so you send the prompt when you're ready. It runs only when you type it.

## If you only remember one thing

Give the agent a goal and a way to check it, in your own words:

```text
/pclaude-poteto-mode the export writes duplicate rows when a retry lands mid-run. repro first, then fix and verify.
```

You don't need to name a playbook or list skills. "repro first" and a checkable outcome are all the routing signal `/pclaude-poteto-mode` needs. It matches the Bug fix playbook, copies the steps into a todo list, and calls the right skills as each step fires.

Next: [Set up pclaude](./01-setup.md).
