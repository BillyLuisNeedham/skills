---
name: my-verify
description: Verify finished work end to end and produce an evidence report (HTML with video, captioned screenshots and logs) that gives a human reviewer confidence. Use when the user asks to verify work, prove it works, or check a branch before a PR, or when an implementation workflow finishes and needs evidence.
---

Verification turns "it should work" into **evidence** a reviewer can check without rerunning anything. The unit of work is the **claim**: one thing the change is supposed to make true. Every claim ends with a **verdict** and the evidence behind it. A claim the run cannot reach is UNVERIFIED with the reason, never quietly dropped and never faked.

This skill reports. It never fixes. A failure gets reproduction steps and stays a failure; mixing fixing into verifying spoils the evidence.

## 1. Find the range

The work is every commit on the branch since it left its base, plus the working tree.

Resolve the base in this order, stopping at the first hit:

1. An open PR's base: `gh pr view --json baseRefName`.
2. The branch's configured upstream parent.
3. The closest candidate (`main`, `develop`, `release/*`, other local branches) by merge-base distance from `HEAD`.
4. Ask the user.

Record the base, the merge-base SHA, `HEAD`'s short SHA, and whether the tree is dirty. A dirty tree is included and flagged, since the evidence may not match what gets committed.

Create the run folder `.verify/<branch>-<shortsha>-<YYYYMMDD-HHMM>/` at the repo root (slashes in the branch name become `-`). Never commit it and never add it to `.gitignore`: the user decides what lands in git.

## 2. Gather the claims

Read the source of intent, in order of authority: the ticket (fetch it from Jira when a key appears in the branch name, commits or PR), a spec or plan doc the commits reference, the PR body, the commit messages. Then read the diff.

Write the claims as a numbered list (`C1`, `C2`, ...), each one observable: "Submitting the form with an empty email shows an inline error", never "validation improved". Split compound claims. Add claims the diff implies but the intent never stated (a changed API response shape, a new migration). When no intent source exists, derive every claim from the diff and say so in the report.

Tag each claim with its **surface** (web, android, api, cli, library, infra) and whether it is a **bug fix or visual change**, which earns a before and after run.

## 3. Preflight

Work out everything the run needs: credentials, test accounts, env files, running services, VPN, seed data, devices. Ask the user for all missing pieces **in one message**. Whatever stays blocked after that marks its claims UNVERIFIED with the reason, and the run carries on with the rest.

## 4. Dispatch verifiers

Verification runs in **fresh-context subagents**, so the verifier never inherits the implementer's reasoning and marks its own homework. Size the dispatch to the scope: one verifier for a single surface, one per independent surface otherwise, run in parallel.

Give each verifier the brief in [`verifier.md`](verifier.md) verbatim, filled with: the repo path, base and range, the run folder, its claims with their tags, the preflight answers, and which strategy files apply. Each verifier writes its evidence under the run folder and returns a results file.

## 5. Assemble the report

Read every verifier's results file. Compute the overall verdict:

- **VERIFIED**: every claim PASS.
- **VERIFIED WITH GAPS**: no FAIL, at least one FLAKY or UNVERIFIED.
- **FAILED**: any claim FAIL.

Build `report.html` in the run folder from [`report-template.html`](report-template.html). The section order is fixed so a reviewer always knows where to look; drop a section only when it has nothing to say, and adapt styling to the content. Every asset path is relative to the run folder. Every screenshot and clip carries a caption stating what it proves; uncaptioned media is not evidence.

The report is done when every claim from step 2 appears in the claims table with a verdict, every UNVERIFIED and FLAKY names its reason in **Not verified and risks**, and every failure carries reproduction steps.

## 6. Hand over

Open `report.html` in the browser. In the terminal print the overall verdict, the claims table as text, any cleanup a verifier could not finish, and the run folder path. Close with a one-line offer to publish the report as an Artifact.
