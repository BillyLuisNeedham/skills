# Issue runner supports multiple harnesses with per-Issue assignment

`my-issue-runner`'s engine ran every Issue on Claude Code, hardcoding `claude -p` and four
Claude-only flags. We replaced that with a dispatch over three harnesses — claude, opencode, and
cursor's `agent` CLI — with the harness and model assigned per Issue: `~/.issue-runner` holds the
global default (read at every runner start, so editing it re-aims every queue), and the runner's
`assign_for` function overrides it per Issue.

Two consequences shape the whole design. First, opencode and cursor have no flag for standing
instructions or per-invocation subagent rosters, so everything an agent needs — AGENT.md, the driver
chain, the roster — is glued into the prompt as plain words on all three harnesses, with the driver
skill always leading (the prompt is the only slot that can reach a `disable-model-invocation`
skill). On opencode the driver goes through `--command` with the bare skill name, because opencode
does not expand slash commands inside a `run` message. Second, the spend cap was deleted outright:
only claude ever supported it, and keeping a cap that two of three harnesses silently ignore is
worse than having none.

Rejected alternatives: runtime harness switching via env var (per-Issue assignment covers the real
need, and baking it in keeps the engine identical in every runner); two separate engine templates
(one dispatch point keeps the engine fixable in one place); injecting rosters via generated
opencode/cursor config (unproven, and the prompt already carries the roster as words).

The cursor launch line is written from Cursor's CLI docs and is unproven on a real queue.
