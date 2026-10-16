# Set up pclaude

In this page you turn on pclaude, check which models it uses, and run your first task. Setup is one command plus a file you can leave alone.

## Turn on the pclaude set

pclaude lives in this repo as the `pclaude` skill set. In Claude Code, run:

```text
/king add pclaude
```

`/king` runs `scripts/use-skills.sh +pclaude`. That links every pclaude skill into `~/.claude/skills` and both agents, `pclaude-poteto-agent` and `pclaude-comment-sicko`, into `~/.claude/agents`. Then it prints the active sets so you can confirm `pclaude` is on. Type `/king` alone any time to see them again.

A running session picks the change up live. If a skill is still missing from the `/` menu, run `/reload-skills`. Restart only if `~/.claude/agents` did not exist when the session started.

Every pclaude skill is user-invoked. You type it, and the model never loads one on its own. When one skill needs another, it reads the other skill's file by path.

## Check your models

There's nothing to run. Every pclaude skill names a role, such as `swarm workers` or `judgment and prose`, and [`models.md`](../models.md) maps each role to a model. The defaults put code and exploration on `sonnet`, judgment and prose on `opus`, and mechanical helpers on `haiku`.

To change a role, edit its line in that file. A changed line takes effect the next time a skill reads it, so there's no rule to regenerate and no new chat to start.

A role can also be `inherit`. pclaude then omits the subagent `model` field, so the subagent runs on your session's own model. For a panel role (`architect runners`, `arena runners`, `interrogate reviewers`) the value is a list, and one subagent runs per entry, so the list length sets the panel size. `swarm workers` sets the default model for every `/pclaude-swarm` worker unless a race names a model for each arm.

You don't pick a reasoning effort per role. pclaude leaves effort unset on every subagent, so your session's own setting applies.

## Create a verification skill

pclaude proves app behavior through a project-local verification skill. If your project has none, run [`/pclaude-create-verification-skill`](../pclaude-create-verification-skill/SKILL.md) in it:

```text
/pclaude-create-verification-skill
```

It writes `.claude/skills/verify-<app>/`, a skill that teaches agents to drive your app the way a user does. It proves the skill works once before handing it over. [`/pclaude-maintain-verification-skill`](../pclaude-maintain-verification-skill/SKILL.md) keeps it current as the app changes. [Verify and ship](./06-verify-and-ship.md#create-a-project-verification-skill) covers both in depth.

If you're new to pclaude, do this first. An agent that can check its own work keeps going until the check passes. An agent that can't hands every result back to you to check by hand. Of everything in this guide, the verification skill pays off the most.

## Keep the cost in check

pclaude spends extra tokens on subagents and review panels. That's the price of the rigor. To spend fewer:

- Edit [`models.md`](../models.md) to put cheaper models on the roles you care less about. A strong model in the main session with cheaper, faster models in the code roles is a good split.
- Set a role to `inherit` so it runs on the session's own model.
- Shorten a panel list. Each entry runs one subagent.
- Lower your session's effort. Every pclaude subagent follows it.
- Save `/pclaude-poteto-mode` for work that needs rigor. A small, obvious edit doesn't.

## Run your first task

Pick something real but small, and describe it the way you'd describe it to a colleague:

```text
/pclaude-poteto-mode add a --json flag to this command. text output stays byte-identical. verify both.
```

Watch the todo list. Its first items are the matched playbook's steps copied in, the Feature playbook for this prompt. If `/pclaude-poteto-mode` skips a step, the step stays in the list with `skip: <reason>`, so you can see what it chose not to do.

From here you can type normal follow-ups. `/pclaude-poteto-mode` is a skill, not a mode. It loads for the task you give it and stays in the conversation's context, but it fades as the chat moves on. When you start a new task, or the chat has drifted far from the first one, type `/pclaude-poteto-mode` again with the new goal.

Next: [Route work through `/pclaude-poteto-mode`](./02-poteto-mode.md).
