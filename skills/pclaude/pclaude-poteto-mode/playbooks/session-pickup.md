### Session pickup

**You own the resume point. Read the prior trail, don't redo it.**

1. Locate the prior trail. The user gives a Claude Code session id, a transcript path, or a pushed branch. Read a session through the transcript reader (Reading transcripts in `CONVENTIONS.md`), written here as `transcript`. Without an id, `transcript list --since 7d` shows this project's recent chats, and a chat that ran in a worktree is found by `transcript last-chat <worktree-path>`. Never read another project's chats unless the user names one. Read the metadata overview and last messages first (`transcript info <id>`, then `transcript show <id> --tail 3`), then scan back for the decision points (`--grep`, `--turn N`). Parse a long transcript in a subagent and keep the reduced timeline in the main thread (the Guard the Context Window principle, `~/.claude/skills/pclaude-principles/guard-the-context-window.md`). Pick each subagent's reasoning level for the job, per the Subagents section.
2. Reconstruct operational state. The branch and worktree, what already landed (`git log`, `git diff` against the base), the open todos, the decisions made. The prior trail is authoritative input. Resist the bias to re-derive it.
3. Diff done vs pending. Compare what shipped against what was planned, name the resume point, do not re-run the prior repro or redo completed work. A "let me verify from scratch" pass means you're treating the trail as untrustworthy when it's authoritative.
4. Route the remaining work to the matching playbook and pick the verdict: continue the execution, ship a finished recommendation, ratify or override a prior conclusion, or postmortem a failed run. The pickup playbook ends here. The routed playbook owns the rest.
5. Verify the inherited claims against the original goal on the real artifact (the Prove It Works principle, `~/.claude/skills/pclaude-principles/prove-it-works.md`). A passing prior self-report is not the proof.

**Reply:** where the prior agent stopped, what you inherited vs redid (ideally nothing redone), the resume point, and the outcome.
