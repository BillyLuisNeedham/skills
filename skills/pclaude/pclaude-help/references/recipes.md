# Prompts worth copying

Swap in the real paths, skills, and done checks. Informal wording works.

## Understand

- `/pclaude-poteto-mode read <thread>. restate the underlying issue in your own words, in plain english.`
- `/pclaude-in-your-own-words <long or messy ask>`
- `/pclaude-sharpen <your task>`
- `/pclaude-poteto-mode investigate why <symptom>. give me what we know, what data you used, and your best hypotheses. don't change any code yet.`
- `use /pclaude-how to understand <subsystem>. then use /pclaude-why to find out why it broke recently.`
- `/pclaude-recall my work on <topic> from last week, then read <issue>.`
- `/pclaude-teach me why you implemented it this way and not <other way>. what did you trade off?`
- `/pclaude-poteto-mode take over this branch. read the decision log, find what's done, and continue. don't redo finished work.`

## Build

- Bug: `/pclaude-poteto-mode <symptom>. repro first, then fix and verify.`
- Bug in an app: `/pclaude-poteto-mode repro this with /verify-<app>. if it repros on main, fix it and show me a video as proof.`
- Bug with a cheap test: `/pclaude-poteto-mode repro <bug> first. if there's a cheap test path, /pclaude-tdd it. then fix and rerun.`
- Feature: `/pclaude-poteto-mode add <behavior>. <current output> stays byte-identical. verify both.`
- Refactor: `/pclaude-poteto-mode move <code> into one module, zero behavior change. record the current output first and prove it's unchanged after.`
- Perf: `/pclaude-poteto-mode <operation> takes <time> on <fixture>. trace it, fix the measured cause, show me before and after.`

## Design and plan

- `/pclaude-poteto-mode prototype a few options for <feature>. take screenshots or videos for me to compare.`
- `/pclaude-poteto-mode we need <feature>. /pclaude-architect it first, and answer open questions with prototypes. let me review before proceeding.`
- `/pclaude-poteto-mode write a tutorial for how i would use <new package> first. then /pclaude-teach me why it beats the current one.`
- `ask /pclaude-arena for a second opinion on this thread and our approach.`
- `/pclaude-poteto-mode turn this design into a plan. small verifiable PRs, each with its own verification steps.`
- `/pclaude-poteto-mode plan the migration of <library> to <target>. small verifiable PRs. the result must match the original exactly, bugs included.`

## Review and ship

- `/pclaude-interrogate the whole branch, but skeptically. don't change anything yet. no nitpicks unless it's a real bug or regression.` Read the dismissals too.
- `/pclaude-swarm check every package under <dir> against its check script. one worker per package. one report.`
- `/pclaude-poteto-mode open the pr. small ordered commits, evidence in the description.`
- `/pclaude-poteto-mode babysit this pr. get it green.` For status only: `/pclaude-poteto-mode check on pr <number>. anything outstanding?`
- `/pclaude-poteto-mode land the stack.`

## Away and back

- `/pclaude-poteto-mode im going to bed. <goal> in a fresh worktree off <base>. done means <checks>. keep a decision log. don't ask me before committing. /loop until done. if you're truly stuck after a few hours, stop and write up why.`
- `/pclaude-show-me-your-work catch me up on what you did last night.` Read its Attention section first.
- `/pclaude-poteto-mode full autopilot on this queue. each item is independent.`
- `/pclaude-poteto-mode autopilot these changes but stack them, don't ship. i'll land the stack.`
- `/pclaude-reflect capture what we learned so the next run doesn't repeat it.` Approve only edits that change a future decision.
- `/pclaude-bro` restates the last reply in plain words.
