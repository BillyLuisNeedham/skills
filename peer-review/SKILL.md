---
name: peer-review
description: Conduct a peer code review of the current branch against a base branch, checking acceptance criteria, code quality, patterns, best practices, test coverage, and bugs. Runs the project's test and lint suites and produces a markdown report with file paths and line numbers. Use when user asks for a peer review, PR review, code review, or wants to review a branch before merging.
---

# Peer Review

Review the current branch against a base branch and produce a structured markdown report.

## Process

### 1. Gather context

Run in parallel:

- `git rev-parse --abbrev-ref HEAD` — current branch
- `git status` — uncommitted changes (warn if dirty)
- `git log --oneline <base>..HEAD` — commits in this branch
- `git diff --stat <base>...HEAD` — files touched

**Base branch**: default to `origin/main`. If missing, try `origin/develop`, then `main`, then `develop`. If still unresolved, ask the user.

**Ticket details**: extract ticket ID from branch name (e.g. `feature/BB-458a` → `BB-458`, `JIRA-123-foo` → `JIRA-123`). Then:
- Ask the user: "Found ticket `<ID>` in the branch name. Paste the acceptance criteria (or say 'skip')."
- If no ID found, ask: "Is there a ticket for this work? Paste the acceptance criteria or say 'skip'."

### 2. Read the diff

Get the full cumulative diff: `git diff <base>...HEAD` (three dots — merge-base to HEAD).

For each non-trivial file, use `Read` to see surrounding context. Reviewing a hunk without the rest of the file misses structural issues.

### 3. Run tests and lint

Detect the toolchain by looking for lockfiles / build files, then run the suite. Capture output to feed into findings.

| Signal | Test command | Lint/format command |
|--------|--------------|---------------------|
| `build.gradle`(.kts) | `./gradlew test` | `./gradlew lint` |
| `package.json` | `npm test` (or detect yarn/pnpm) | `npm run lint` if script exists |
| `pyproject.toml` / `requirements.txt` | `pytest` | `ruff check .` / `flake8` if configured |
| `Cargo.toml` | `cargo test` | `cargo clippy` |
| `go.mod` | `go test ./...` | `go vet ./...` |

Rules:
- Only run if a runner is detected. Don't guess.
- If tests take > 5 min historically, ask before running.
- Capture failures with file + line, attach to findings.
- If the suite doesn't compile, that's a **Blocker** — stop and report.

### 4. Review against each dimension

Work through these in order. For every finding, record `file:line` and a short rationale.

**Acceptance criteria** (skip if none provided)
- Map each criterion to code that fulfils it
- Flag missing or partially-met criteria

**Code quality**
- Readability, naming, function length, nesting depth
- Dead code, commented-out code, TODOs left behind
- Error handling (swallowed exceptions, missing null checks)
- Magic numbers / strings that should be constants

**Codebase patterns**
- Does new code follow existing conventions? Infer patterns from sibling files — read 2-3 similar features before flagging "doesn't match pattern".
- Look at imports, folder layout, naming, layering, DI style, state management, test style used elsewhere.

**Best practices**
- Language idioms for the stack in use
- Concurrency / threading correctness
- Resource lifecycle (subscriptions, streams, file handles, connections)
- Accessibility and i18n for UI changes

**Test coverage**
- New logic has tests? Branches covered?
- Tests assert behaviour, not implementation
- Missing edge cases (null, empty, error paths)
- Cross-reference with the test run output from step 3

**Bugs**
- Off-by-one, null dereferences, race conditions
- Incorrect logic, inverted conditions
- Regressions in untouched callers

**Other**
- Security (input validation, secrets, PII logging)
- Performance (N+1, unbounded loops, main-thread work)
- Dependencies added — necessary? licenced?

### 5. Assign severity

Each finding gets one of:
- **Blocker** — must fix before merge (bug, missing AC, failing tests, security)
- **Major** — should fix (pattern violation, missing tests on core logic)
- **Minor** — nice to fix (naming, style, small refactor)
- **Nit** — optional (preference, micro-optimisation)

### 6. Write the report

Write to `./peer-review-<branch-sanitised>.md` (e.g. `./peer-review-feature-BB-458a.md`).

Use the template in [REPORT_TEMPLATE.md](REPORT_TEMPLATE.md).

### 7. Summarise

Print to the user:
- Report path
- Count per severity
- Test/lint result summary
- One-line overall verdict (ready to merge / needs changes / blocked)

## Rules

- **Cite every finding** with `file:line` — no vague "somewhere in X".
- **Quote sparingly** — short snippets only.
- **Be specific** — "rename `x` to `userCount`" beats "improve naming".
- **Don't repeat yourself** — if the same issue appears 10 times, note it once with a list of locations.
- **Positive notes welcome** — call out genuinely good changes in a "Highlights" section.
- **No speculation** — if you'd need to run code to confirm a bug, say so rather than guessing.
