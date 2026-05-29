# Peer Review: `<branch>` → `<base>`

**Ticket**: `<ID or "none">`
**Reviewer**: AI peer review
**Date**: `<YYYY-MM-DD>`
**Commits**: `<n>` · **Files changed**: `<n>` · **+<added> / -<removed>`

## Verdict

One of: **Ready to merge** · **Needs changes** · **Blocked**

One-paragraph summary of the overall state of the branch.

## Summary

| Severity | Count |
|----------|-------|
| Blocker  | 0     |
| Major    | 0     |
| Minor    | 0     |
| Nit      | 0     |

## Acceptance Criteria

- [x] Criterion 1 — met in `path/to/file.kt:42`
- [ ] Criterion 2 — **not addressed**; see Findings #3
- [~] Criterion 3 — partially met; missing error case

_Omit this section entirely if no ticket/AC was provided._

## Findings

### 1. [Blocker] Short title

**File**: `path/to/file.kt:42-58`
**Category**: Bugs

Description of the problem and why it matters.

Suggested fix:

```kotlin
// brief illustrative snippet or pseudo-code
```

---

### 2. [Major] Short title

**File**: `path/to/other.kt:10`
**Category**: Codebase patterns

Description…

---

### 3. [Minor] Short title

**Files**:
- `path/to/a.kt:12`
- `path/to/b.kt:77`

**Category**: Code quality

Description…

---

## Highlights

Things done well worth calling out:

- `path/to/file.kt:88` — clean separation of X and Y
- Good test coverage on the new `FooPresenter`

## Test & Lint Run

**Tests**: `<command used>` — Pass / Fail / Skipped (`<n> passed, <n> failed`)
**Lint**: `<command used>` — Pass / Fail / Skipped (`<n> issues`)

Failures (if any):

- `path/to/test.kt::methodName` — `<one-line reason>`

## Test Coverage Notes

- New code covered: Y / N / Partial
- Missing cases: …
- Existing test suites affected: …

## Out of Scope / Follow-ups

Items noticed but not blocking this review:

- …
