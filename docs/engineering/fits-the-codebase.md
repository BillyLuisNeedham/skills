Quickstart:

```bash
npx skills add mattpocock/skills --skill=fits-the-codebase
```

```bash
npx skills update fits-the-codebase
```

[Source](https://github.com/mattpocock/skills/tree/main/skills/engineering/fits-the-codebase)

## What it does

`fits-the-codebase` judges whether a change reads as **native** to this codebase — written *with the grain* of the code around it — or merely works while giving itself away as a transplant. It infers the team's undocumented conventions from the neighbouring code and flags each place the change breaks from them, with a fix for each. It never reports a finding it can't anchor to a cited local precedent — if no neighbour does the same thing differently, there is no house convention to break, so it stays silent rather than fall back on generic taste. That one rule is what separates this from a linter or a second opinion: every judgement comes from *this repo*.

## When to reach for it

Type `/fits-the-codebase`, or the agent reaches for it automatically when you ask whether a change fits the codebase, reads like the team wrote it, matches the house idioms — or worries it "just works" or feels foreign or AI-written.

Reach for this when the code is *correct* but you're not sure it *belongs*. For whether it's built right against documented standards and does what the spec asked, use [code-review](https://aihero.dev/skills-code-review) instead — the two are deliberately separate axes, and a change can sail through one while failing the other. Run both for a full review.

## The grain, and the tell

The two words the skill thinks with. The **grain** is the codebase's undocumented fingerprint — the names this team reaches for, which existing helper they reuse, how failure travels, how much abstraction they tolerate, how their tests read. None of it lives in a `CONTRIBUTING.md`; it lives only in the surrounding code. So before judging a single line, the skill reads the **nearest neighbours** of each changed file — the siblings of the same kind — and derives the grain from them.

A **tell** is any place the change cuts across that grain: a generic name where the team has a house term, a hand-rolled helper the codebase already ships, coroutines where the team uses RxJava3, a guard clause the neighbours never write. Each tell is reported with the offending hunk, the neighbour that does it the local way (quoted, with `file:line`), and the realignment. Every tell is a judgement call the author owns — never a hard violation — and formatter/linter concerns are skipped, because tooling already owns those.

## It's working if

- It pins and confirms the target diff first — uncommitted work, a commit, a range, or a branch — failing fast on a bad ref or empty diff.
- Before any finding, it has read the sibling files and can state the local convention it's judging against.
- Every tell cites a neighbour (`file:line`) doing it the house way; a change with no citeable tells is reported as native, not padded with invented findings.

## Where it fits

A reach-for-it-anytime standalone at the review end of the build loop, sibling to [code-review](https://aihero.dev/skills-code-review): where that skill asks *is it built right and is it the right thing?*, this one asks *does it read like we wrote it?* — the check that matters most for code that a contractor, a new hire, or an agent wrote and that needs to disappear into the codebase. For the whole map, see [ask-matt](https://aihero.dev/skills-ask-matt).
