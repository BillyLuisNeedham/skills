# pclaude conventions

The rules every pclaude skill and agent follows in Claude Code. Each is stated here once. Skills point at this file instead of restating them.

## Reaching another skill

Every pclaude skill is user-invoked (`disable-model-invocation: true`). The Skill tool cannot load one, and no skill catalog lists them. So one pclaude skill reaches another by Reading its file by path.

- A skill is at `~/.claude/skills/pclaude-<name>/SKILL.md`. "Read `~/.claude/skills/pclaude-how/SKILL.md` and follow it" is the form. Read the whole file before acting on it.
- A path inside that skill (`references/…`, `playbooks/…`, `scripts/…`) resolves from that skill's own directory.
- A principle is a leaf file at `~/.claude/skills/pclaude-principles/<name>.md`. The trigger index is `~/.claude/skills/pclaude-principles/SKILL.md`.
- This file and `models.md` sit in the bucket root, one level above every skill, and are not linked into `~/.claude/skills/` themselves. Each skill directory there is a symlink into the repo, so a lexical `../` from it misses them. Find them with `realpath ~/.claude/skills/pclaude-poteto-mode/../models.md` (and `../CONVENTIONS.md`), which follows the symlink first, then Read the path it prints. A skill's own link to `../models.md` means that file.
- A skill from outside pclaude that is model-invoked (`writing-for-agents`, `run`, `claude-in-chrome`, `simplify`) is reached with the Skill tool, by name.
- A pclaude agent is a subagent type. Spawn it with the Agent tool as `subagent_type: "pclaude-poteto-agent"` or `subagent_type: "pclaude-comment-sicko"`. Its definition is linked into `~/.claude/agents/` while the pclaude set is active.

## Models

Never write a model slug. Name a role from `models.md` and pass its value as the Agent tool's `model`.

## Spawning subagents

Every spawn is an Agent tool call.

- **Read-only work** (exploring, explaining, reviewing) uses `subagent_type: "Explore"` when the agent needs only to search and read, and `subagent_type: "general-purpose"` with a "do not edit files" instruction when it also needs to run commands.
- **Code-writing delegates** inside a poteto-mode playbook use `subagent_type: "pclaude-poteto-agent"`. A routed skill that names its own type keeps it.
- **Background.** Pass `run_in_background: true` unless the next step cannot start without the result. You are notified when the agent finishes, so never poll it.
- **Isolation.** A delegate that writes code beside other writers gets `isolation: "worktree"`. That is the default for every cloud agent upstream used (autopilots, orchestrate, swarm, session pickup). Claude Code remote agents (`isolation: "remote"`) are opt-in. Use one only when the user asks for remote.
- **Prompts** carry file pointers, not inlined context. Put the absolute path of every skill file the delegate must follow in its prompt.

## Nesting

Claude Code subagents cannot spawn subagents. So the main session is always the lead that fans out. arena, swarm, interrogate, how and why spawn their agents from the main session, never from inside a delegate.

- A delegate owns its diff directly. It writes, tests and commits its own change instead of handing it to a further agent.
- A delegate that hits a step that says to fan out does that work itself, in sequence, or reports back so the lead can fan out.
- A skill that runs inside a delegate (a delegate reading `pclaude-how`, say) follows its steps inline, without spawning.

## Asking the human

Ask in plain text. Number the questions, ask them all at once, and give your recommendation with each one, so Billy can answer them in one voice-typed reply. Do not use the AskUserQuestion tool.

## Substitutes for Cursor features

Upstream pstack was written for Cursor. Where it named a Cursor feature, pclaude uses the substitute below. A feature with no substitute is cut, along with every mention of it.

| Upstream | pclaude |
| --- | --- |
| `deslop` (cursor-team-kit) | `pclaude-unslop` for prose, `/simplify` for code |
| `control-ui` | the `claude-in-chrome` skill |
| `control-cli` | the `run` skill, or tmux |
| `AskQuestion` | numbered free-text questions, each with a recommendation (above) |
| `create-skill` | the `writing-for-agents` skill |
| `Task` tool, background tasks | the Agent tool with `run_in_background: true` |
| `subagent_type: generalPurpose` with `readonly: true` | `subagent_type: "Explore"` |
| `subagent_type: generalPurpose`, agent mode | `subagent_type: "general-purpose"` |
| `environment: "cloud"` | `isolation: "worktree"`, or `isolation: "remote"` when asked |
| model slugs, `pstack-models.mdc`, `/setup-pstack` | a role in `models.md` |
| `~/.cursor` transcripts | `~/.claude/projects`, read through the pclaude scripts package |
| Origin | `gh` |
| Custom Modes, `mode: true` | the user-invoked `/pclaude-poteto-mode <task>` |
| principle skills (`principle-<name>`) | leaf files in `pclaude-principles/` |

## Footer

Every pclaude `SKILL.md` ends with this line.

`Ported from pstack by poteto (MIT). See skills/pclaude/LICENSE.`
