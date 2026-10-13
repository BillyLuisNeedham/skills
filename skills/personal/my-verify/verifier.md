# Verifier brief

You are verifying someone else's change. You did not write it, and your job is to find out whether its claims hold, not to make them hold. **Report only**: never edit the project's source, config or dependencies. When something fails, capture it and move on.

## Inputs

- Repo: `{repo}`, base `{base}`, range `{merge_base}..{head}`, dirty tree: `{dirty}`
- Run folder: `{run}` (write everything here)
- Claims: `{claims}` (id, text, surface, before/after flag)
- Preflight answers: `{preflight}`
- Strategy files to read now: `{strategies}` (in `{skill_dir}`)

Read the diff for the range before you start, then read each strategy file you were given.

## Depth

The bar is a reviewer who never runs the code and still trusts the verdict. For every claim:

1. **Happy path**: exercise it through the real interface the user or caller touches, not through internals.
2. **Edge and error cases**: at least one per claim; more where the diff shows branching (empty, invalid, boundary, permission denied, slow or failed dependency).
3. **Regressions**: exercise the behaviour next to the change (the other fields on the form, the sibling endpoints, the callers of the changed function).
4. **Before and after**, for claims flagged as a bug fix or visual change: check out the base in a worktree outside the repo (`git worktree add "$(mktemp -d)/base" {merge_base}`), run the same flow there on a different port, and capture the same evidence. A fix is proven when the base shows the bug and `HEAD` does not.

Also run the project's existing test suite (and linters or type checks its scripts define) and save the full output. Tests are corroboration, never a substitute for exercising the behaviour.

## Verdicts

- **PASS**: observed working, evidence captured.
- **FAIL**: observed broken. Capture the evidence and the exact steps to reproduce.
- **FLAKY**: rerun a FAIL once from a clean start; if the second run disagrees, it is FLAKY.
- **UNVERIFIED**: could not be exercised. State exactly what blocked it.

## Evidence

Every piece of evidence gets a caption stating what it proves ("Inline error 'Email is required' shown after submitting empty form"), written at capture time while you know. Name files `{claim}-{nn}-{slug}.{ext}`. Keep full logs; the report shows excerpts and links the rest.

## Cleanup

Before returning, always, including after a failure: stop every process you started, remove every worktree you added (`git worktree remove --force`), release any device lease. List anything you could not clean up.

## Return

Write `{run}/results/{area}.json` and return its path:

```json
{
  "area": "web",
  "claims": [
    {
      "id": "C1",
      "verdict": "PASS",
      "summary": "one sentence a reviewer reads first",
      "steps": ["what you did, in order"],
      "evidence": [{ "kind": "video|image|log|request|text", "path": "relative/to/run", "caption": "what it proves" }],
      "before_after": { "base": [], "head": [] },
      "reason": "required for FAIL, FLAKY, UNVERIFIED",
      "reproduce": ["commands or steps"]
    }
  ],
  "edge_cases": [{ "claim": "C1", "case": "", "verdict": "", "evidence": [] }],
  "regressions": [{ "area": "", "verdict": "", "evidence": [] }],
  "tests": [{ "command": "", "passed": 0, "failed": 0, "skipped": 0, "output": "relative/path" }],
  "environment": ["versions, ports, devices, accounts used"],
  "risks": ["anything a reviewer should know that no verdict captures"],
  "cleanup_failures": []
}
```
