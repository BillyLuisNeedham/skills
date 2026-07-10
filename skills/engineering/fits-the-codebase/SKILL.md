---
name: fits-the-codebase
description: Check whether a change reads as native to *this* codebase — written with the grain of the surrounding code, not merely working. Infers the team's undocumented conventions from neighbouring code, flags each 'tell' that gives the change away as an outsider's (or an LLM's), and recommends how to realign it. Use when the user wants to check that code fits the codebase, reads like the team wrote it, matches the house idioms/conventions, or worries it "just works" or feels foreign/AI-written. Works on uncommitted changes, a commit, a range, or a branch. Distinct from /code-review, which checks documented standards and spec.
---

Judge whether a change reads as **native** to this codebase — written *with the grain* of the code around it — or merely works while giving itself away as a transplant.

Every finding is a **tell**: a place the change reveals an outsider's hand. The discipline that makes this skill worth running is one rule — **no tell without a cited local precedent.** Each tell must point at neighbouring code (`file:line`) that does the same thing differently. That forces every judgement to come from *this repo's* grain, not your own generic taste. If you can't cite a neighbour that does it another way, it isn't a tell — drop it.

## Not /code-review

Kept separate on purpose; run both for a full review:

- **`/code-review`** judges the diff against **documented** standards and the originating spec — *is it built right, is it the right thing?*
- **This skill** judges it against the **undocumented** fingerprint no `CONTRIBUTING.md` records — *does it read like the team wrote it?* Code can pass every standard and still stick out as foreign.

## Process

### 1. Pin the target

Whatever the user pointed at is the target. Resolve it to one diff command:

- **Uncommitted work** — `git diff HEAD` (add `--staged` if they mean staged). Default to this if they didn't say and the tree is dirty.
- **A commit** — `git show <sha>`.
- **A range or branch** — `git diff <base>...HEAD` (three-dot, against the merge-base), plus `git log <base>..HEAD --oneline` for the commit list.

Confirm the ref resolves and the diff is non-empty before going further — a bad ref or empty diff fails here, not later.

### 2. Build the grain

Before judging a single line, derive the local conventions from the code around the change. This is the legwork the whole skill rests on — skip it and you review against your own habits, which is the one failure this skill exists to prevent.

For **each changed file**, find its **nearest neighbours** — the sibling files of the same kind (same package/feature, same layer, same role: a presenter next to presenters, a test next to tests) — and read enough of them to state, in your own notes, how this codebase handles each **fit dimension** below. Complete when every changed file has neighbours identified and their conventions noted; a file with no neighbours (a genuinely new kind of thing) is itself a finding — say so.

### 3. Hunt tells

Walk the diff against the grain you built. For each fit dimension, flag every place the change departs from what the neighbours do. Skip anything a formatter or linter already enforces (import order, spacing, quote style) — that's tooling's job, not a fit judgement.

**Fit dimensions** — for each, *what it is* → *the tell* → *the fix*:

- **Naming** — the identifiers this team reaches for. → A name that's correct but generic where neighbours use a specific house term (`data`/`response` where the team says `payload`; `getUser` where the team says `fetchUser`). → Rename to the local vocabulary.
- **Reinvention** — reusing what already exists. → Hand-rolling a helper, extension, mapper, or util the codebase already ships. The single loudest "just works" tell. → Call the existing one; cite it.
- **Library & API choice** — the team's default tool for this job. → Reaching for a different library or language construct than neighbours use for the same task (coroutines where the team uses RxJava3; a raw loop where they use a known extension). → Switch to the house choice.
- **Error handling** — how failure travels here. → A different failure pattern than neighbours (throwing where they return a Result, swallowing where they surface via `onError`). → Match the local pattern.
- **Structure & placement** — where this kind of code lives, and the layers it goes through. → Code placed where the team doesn't put it, or skipping the local layering every sibling feature follows (no contract, bypassing the repository). → Move it and route it the way siblings do.
- **Abstraction level** — how much indirection the team tolerates here. → More or less than neighbours: an interface/factory/generic where siblings are plain and direct, or one fat function where siblings decompose. → Match the surrounding altitude.
- **Test shape** — how tests read here. → Different naming, structure (given/when/then), mocking approach, or fixture style than the sibling tests. → Mirror the neighbouring tests.
- **Comments & ceremony** — the density of comments and defensive code the team writes. → Explanatory comments, doc blocks, or null/guard checks out of step with neighbours who write none (or vice versa). A classic AI tell. → Bring it to the local level.

### 4. Report

List the tells, most jarring first. Each carries four parts:

1. **Dimension** and a one-line statement of the tell.
2. **The change** — quote the hunk (`file:line`).
3. **The grain** — cite the neighbour that does it the local way (`file:line`), quoted.
4. **The fix** — the concrete realignment.

End with a verdict in the skill's own terms: does the change read as native, or how many tells pull it against the grain — and the worst one. Every tell is a judgement call, never a hard violation; the author owns the call. A change with zero citeable tells reads as native — say so plainly rather than manufacturing findings.
