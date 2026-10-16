# Resolving and translating upstream text

Read this before resolving anything in step 3. Every line you write into `skills/pclaude/` follows the rules below, whether it came from a conflict, a clean merge or a new upstream file.

## Resolving one change

1. Read the **intent**: `diff -u <base>/<file> <theirs>/<file>`, with the tree paths the script printed. This is what upstream actually changed. The conflict hunk alone hides the context.
2. Take ours as the frame. Its translations and Billy's edits stay.
3. Write upstream's intent into ours, translated by the rules below. Port the idea, not the Cursor wording.
4. Remove the markers and re-read the whole passage. It should read as one voice, with nothing doubled.

Theirs is never taken wholesale. It brings back every Cursor-ism and drops Billy's edits.

When upstream rewrote a passage Billy had reworded, keep Billy's wording and port upstream's new substance into it only where the two agree. Where they pull apart, keep Billy's and put the upstream change on the judgment-call list.

When upstream adds something with no Claude Code substitute, cut it and put it on the judgment-call list. Leave nothing dangling: a cut feature takes its mentions and links with it.

## Translation rules

The live tables are in the bucket and win over this file when they differ: `skills/pclaude/models.md` for model roles and `skills/pclaude/CONVENTIONS.md` for the read-by-path convention, the nesting rule and the substitutes table. Point at them from skill text rather than restating them.

- **Names.** Everything is `pclaude-<name>`. The renderer already renamed `pstack`. A bold single-word skill name (`**how**`) means the skill `pclaude-how`.
- **Invocation.** Every pclaude skill is user-only: `disable-model-invocation: true`, `pclaude-principles` included. One skill reaches another by Reading `~/.claude/skills/pclaude-<name>/SKILL.md`, so "use the **how** skill" becomes an explicit Read of that path.
- **Principles.** `pclaude-principles/SKILL.md` is the trigger index. Each principle is a leaf file beside it (`pclaude-principles/<name>.md`), and links between principles point at sibling leaves. A new upstream principle becomes a new leaf plus an index entry.
- **Models.** No model slugs. Code and exploration use `sonnet`, judgment uses `opus`, mechanical helpers use `haiku`, and a "different model family" judge is a fresh-context `opus` agent, named through `models.md`.
- **Diversity.** arena, interrogate and architect stay as written. No "Claude-only" labels.
- **Nesting.** Subagents cannot spawn subagents. The main session is the lead that fans out, and delegates own their diff directly. This is stated once, in `CONVENTIONS.md`.
- **Mode.** poteto-mode is the user-invoked `/pclaude-poteto-mode <task>`. Drop `mode:`, `icon:`, `color:` and `reminder:` from SKILL.md frontmatter. Agents may keep `color:`.
- **Substitutes.**
  - `deslop` becomes `pclaude-unslop` for prose and `/simplify` for code.
  - `control-ui` becomes claude-in-chrome, and `control-cli` becomes `run` or tmux.
  - `AskQuestion` becomes plain numbered free-text questions, each with a recommendation.
  - `create-skill` becomes `writing-for-agents`.
  - The `Task` tool (and background tasks) becomes `Agent` with `run_in_background`.
  - `~/.cursor` transcripts become `~/.claude/projects`, and Cursor's origin becomes `gh`.
- **Cloud agents.** Autopilots, orchestrate, swarm and session-pickup use local background agents in isolated worktrees by default, with Claude Code remote agents as an opt-in flag.
- **Transcripts.** Skills that read sessions call the shared Bun transcript reader in the pclaude scripts package, never a Cursor path.
- **PR comments.** watch-pr and the babysit and shipping playbooks watch every comment regardless of author, and triage each one (fix, dismiss or ask). A human's comment is never auto-dismissed: it is fixed or raised to Billy.
- **Cut, not ported.** `make-bot-ui`, `setup-pstack`, orchestrate's dashboard and restart steps, poteto-help's `/add-plugin` and Custom Modes setup, and worktree-cleanup's iOS simulator and `xcrun` part.
- **Reply style.** poteto-mode's "Writing the reply" stays verbatim apart from Cursor references.

## A new upstream skill

It arrives as `skills/pclaude/pclaude-<name>/` with upstream frontmatter. Give it the pclaude shape:

- `disable-model-invocation: true`, and none of the dropped frontmatter keys.
- The footer line every pclaude SKILL.md ends with: `Ported from pstack by poteto (MIT). See skills/pclaude/LICENSE.`
- Its body translated by the rules above.
- An entry wherever the bucket lists its skills (`pclaude-help`, and `skills/pclaude/README.md` if there is one).

An upstream skill that cannot work in Claude Code at all is deleted instead, and goes on the judgment-call list.
