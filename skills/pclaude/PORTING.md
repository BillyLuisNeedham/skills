# pclaude porting work list

Every hit `scripts/pclaude-check.sh` reported on the first port (upstream `cdb3c41`), grouped by the ticket that owns the file and then by file. 256 hits in all. Line numbers are from the first port and drift as files change, so find a hit by its file and text.

Tick a hit when it is fixed or allowlisted (with a comment in `scripts/pclaude-check.allow`). A ticket is done with this list when every hit under its heading is ticked and `scripts/pclaude-check.sh` shows none left in its files.

The check only finds leftovers. Spec section 5 also asks for things it cannot see: explicit Reads of `~/.claude/skills/pclaude-<name>/SKILL.md` instead of "use the **x** skill", `disable-model-invocation: true` and the MIT footer on every SKILL.md, and models from `models.md`. Each ticket owns those for its files too.

Ownership follows each ticket's file list. Where no ticket names a file, the choice is noted below the table.

| Ticket | Owns | Files with hits | Hits |
| --- | --- | --- | --- |
| 06 | Foundations: models, principles, conventions, agents | 1 | 4 |
| 07 | Core building blocks: how, why, architect, arena, swarm, interrogate | 6 | 41 |
| 08 | poteto-mode core and the main code playbooks | 6 | 31 |
| 10 | Helper skills and pclaude-help | 3 | 51 |
| 11 | Shared transcript reader and the skills that read transcripts | 10 | 38 |
| 12 | Remaining simple playbooks and multi-phase-plan | 6 | 16 |
| 13 | babysit, shipping and watch-pr over every PR comment | 6 | 12 |
| 14 | Autopilots and orchestrate | 2 | 14 |
| 15 | Rewrite docs/guide for Claude Code | 7 | 49 |

- `pclaude-sharpen` and `pclaude-in-your-own-words` are named by no ticket. Neither has a hit. Ticket 10 owns their section 5 translation.
- `pclaude-poteto-mode/scripts/package.json` and `bun.lock` (the `@cursor-skill/` package name) go to ticket 13, the first ticket to touch the shared scripts package. Ticket 14 must not rename it again.
- `pclaude-show-me-your-work`'s one hit is its transcript path, so it goes to ticket 11.
- The `pclaude-models` hits (`unknown-skill`) come from upstream's `pstack-models.mdc` rule. They are fixed by pointing at `skills/pclaude/models.md`, which ticket 06 writes, but each one is owned by the ticket that owns its file.

## Ticket 06

Foundations: models, principles, conventions, agents.

### agents/pclaude-poteto-agent.md

- [x] L9 [cursor:.cursor] `.cursor` in `` …ore any other work, search `~/.cursor/plugins/` for a file whose pa… ``
- [x] L9 [cursor:.cursor] `.cursor` in `` …ore any other work, search `~/.cursor/plugins/` for a file whose pa… ``
- [x] L9 [cursor:Task-tool] `every Task` in `…playbook, the todo list, and every Task spawn. You are one of its del…`
- [x] L9 [cursor:cursor-name] `cursor-plugin` in `` …matches, use the copy whose `.cursor-plugin/plugin.json` has the highest… ``

## Ticket 07

Core building blocks: how, why, architect, arena, swarm, interrogate.

### pclaude-architect/SKILL.md

- [x] L31 [cursor:grok] `grok` in `` …`claude-opus-5-5-xhigh` and `grok-4.7-xhigh-fast`. Alias and re… ``
- [x] L31 [cursor:.mdc] `.mdc` in `` …s` line in the `pclaude-models.mdc` rule, in place of the `arena… ``
- [x] L31 [unknown-skill] `pclaude-models` in `` …chitect runners` line in the `pclaude-models.mdc` rule, in place of the `a… ``

### pclaude-arena/SKILL.md

- [x] L17 [cursor:grok] `grok` in `` …`claude-opus-5-5-xhigh` and `grok-4.7-xhigh-fast`. An `auto` or… ``
- [x] L17 [cursor:grok] `grok` in `` …`claude-opus-5-5-xhigh` and `grok-4.7-xhigh-fast`. An `auto` or… ``
- [x] L17 [cursor:grok] `grok` in `` …`claude-opus-5-5-xhigh` and `grok-4.7-xhigh-fast`. An `auto` or… ``
- [x] L17 [cursor:grok] `grok` in `` …`claude-opus-5-5-xhigh` and `grok-4.7-xhigh-fast`. An `auto` or… ``
- [x] L17 [cursor:.cursor] `.cursor` in `` …he `arena runners` line in `~/.cursor/rules/pclaude-models.mdc`. If… ``
- [x] L17 [cursor:.mdc] `.mdc` in `` …~/.cursor/rules/pclaude-models.mdc`. If the rule or that line is… ``
- [x] L17 [cursor:Task-tool] `the Task` in `` …l, so omit `model` for it. If the Task tool rejects a configured ent… ``
- [x] L17 [cursor:cursor-name] `cursor-grok` in `` …claude-*`, and `grok-*` with `cursor-grok-*` and `composer-*`. A refuse… ``
- [x] L17 [unknown-skill] `pclaude-models` in `` …ers` line in `~/.cursor/rules/pclaude-models.mdc`. If the rule or that lin… ``
- [x] L28 [cursor:grok] `grok` in `` …`claude-opus-5-5-xhigh` and `grok-4.7-xhigh-fast`. Prefer a dif… ``
- [x] L28 [cursor:.cursor] `.cursor` in `` …cross-judge pool` line in `~/.cursor/rules/pclaude-models.mdc`. If… ``
- [x] L28 [cursor:.mdc] `.mdc` in `` …~/.cursor/rules/pclaude-models.mdc`. If the rule or that line is… ``
- [x] L28 [unknown-skill] `pclaude-models` in `` …ool` line in `~/.cursor/rules/pclaude-models.mdc`. If the rule or that lin… ``

### pclaude-how/SKILL.md

- [x] L11 [cursor:grok] `grok` in `` …de-models.mdc` rule (default `grok-4.7-xhigh-fast`), and every e… ``
- [x] L11 [cursor:.mdc] `.mdc` in `` …r` line in the `pclaude-models.mdc` rule (default `grok-4.7-xhig… ``
- [x] L11 [cursor:Task-tool] `Task subagent` in `` Every spawn is a Task subagent with `subagent_type: generalP… ``
- [x] L11 [cursor:Task-tool] `the Task` in `` …auto` or `inherit-parent`. If the Task tool rejects a slug, use the… ``
- [x] L11 [unknown-skill] `pclaude-models` in `` …e `how explorer` line in the `pclaude-models.mdc` rule (default `grok-4.7-… ``

### pclaude-interrogate/SKILL.md

- [x] L27 [cursor:.cursor] `.cursor` in `` …rrogate reviewers` line in `~/.cursor/rules/pclaude-models.mdc`, la… ``
- [x] L27 [cursor:.mdc] `.mdc` in `` …~/.cursor/rules/pclaude-models.mdc`, labeled Reviewer A, B, and… ``
- [x] L27 [cursor:Task-tool] `the Task` in `` …wers in a single message with the Task tool, one per entry on the `i… ``
- [x] L27 [unknown-skill] `pclaude-models` in `` …ers` line in `~/.cursor/rules/pclaude-models.mdc`, labeled Reviewer A, B,… ``
- [x] L32 [cursor:grok] `grok` in `` | Reviewer B | `grok-4.7-xhigh-fast` | ``
- [x] L36 [cursor:grok] `grok` in `` …o by prefix: `claude-*`, and `grok-*` with `cursor-grok-*` and `… ``
- [x] L36 [cursor:grok] `grok` in `` …o by prefix: `claude-*`, and `grok-*` with `cursor-grok-*` and `… ``
- [x] L36 [cursor:Task-tool] `the Task` in `If the Task tool rejects a configured ent…`
- [x] L36 [cursor:cursor-name] `cursor-grok` in `` …claude-*`, and `grok-*` with `cursor-grok-*` and `composer-*`. A refuse… ``

### pclaude-swarm/SKILL.md

- [x] L22 [cursor:grok] `grok` in `` …or that line is missing, use `grok-4.7-xhigh-fast`. For `auto` o… ``
- [x] L22 [cursor:.cursor] `.cursor` in `` …he `swarm workers` line in `~/.cursor/rules/pclaude-models.mdc`. If… ``
- [x] L22 [cursor:.mdc] `.mdc` in `` …~/.cursor/rules/pclaude-models.mdc`. If the rule or that line is… ``
- [x] L22 [cursor:Task-tool] `the Task` in `…s run on the parent model. If the Task tool rejects a slug, use the…`
- [x] L22 [unknown-skill] `pclaude-models` in `` …ers` line in `~/.cursor/rules/pclaude-models.mdc`. If the rule or that lin… ``

### pclaude-why/SKILL.md

- [x] L11 [cursor:.mdc] `.mdc` in `` …le line in the `pclaude-models.mdc` rule and a default. Set `mod… ``
- [x] L11 [cursor:Task-tool] `the Task` in `` …auto` or `inherit-parent`. If the Task tool rejects a slug, use the… ``
- [x] L11 [unknown-skill] `pclaude-models` in `` …low names a role line in the `pclaude-models.mdc` rule and a default. Set… ``
- [x] L35 [cursor:Cursor] `Cursor` in `…t the available MCPs from the Cursor environment. Use the availabl…`
- [x] L35 [cursor:Cursor] `Cursor` in `…t the available MCPs from the Cursor environment. Use the availabl…`
- [x] L49 [cursor:grok] `grok` in `` …investigators` line, default `grok-4.7-xhigh-fast`. ``

## Ticket 08

poteto-mode core and the main code playbooks.

### pclaude-no-comments/SKILL.md

- [x] L19 [cursor:Task-tool] `` `Task` `` in `` 1. Spawn `Task` with `subagent_type: "pclaude… ``

### pclaude-poteto-mode/SKILL.md

- [x] L5 [cursor:icon-frontmatter] `icon: crown`
- [x] L20 [cursor:AskQuestion] `AskQuestion` in `` - About to `AskQuestion` on a "which approach", "how… ``
- [x] L26 [cursor:Cursor] `Cursor` in `…s the **create-skill** skill (Cursor's built-in for authoring SKIL…`
- [x] L28 [cursor:deslop] `deslop` in `` - Before commit → the `deslop` skill from the `cursor-team-… ``
- [x] L28 [cursor:deslop] `deslop` in `` - Before commit → the `deslop` skill from the `cursor-team-… ``
- [x] L28 [cursor:cursor-team-kit] `cursor-team-kit` in `` …the `deslop` skill from the `cursor-team-kit` plugin (`/deslop`). ``
- [x] L30 [cursor:control-ui] `control-ui` in `` …rol-cli` (CLIs and TUIs) and `control-ui` (browser / Electron / web UI… ``
- [x] L30 [cursor:control-cli] `control-cli` in `` …`cursor-team-kit` publishes `control-cli` (CLIs and TUIs) and `control… ``
- [x] L30 [cursor:cursor-team-kit] `cursor-team-kit` in `` …the matching control skill. `cursor-team-kit` publishes `control-cli` (CLI… ``
- [x] L32 [cursor:Cursor] `Cursor` in `` …(`playbooks/babysit.md`), not Cursor's built-in babysit skill, who… ``
- [x] L95 [cursor:grok] `grok` in `` …ia `/setup-pstack`. Defaults `grok-4.7-xhigh-fast` for code, `cl… ``
- [x] L95 [cursor:Task-tool] `` `Task` `` in `` **Defaults for every `Task` call.** `run_in_background: t… ``
- [x] L95 [cursor:Task-tool] `omit Task` in `` …ole on the parent chat model (omit Task `model`). Each code playbook'… ``
- [x] L95 [pstack] `pstack` in `` …ole (configurable via `/setup-pstack`. Defaults `grok-4.7-xhigh-fa… ``
- [x] L95 [pstack] `pstack` in `` …ole (configurable via `/setup-pstack`. Defaults `grok-4.7-xhigh-fa… ``
- [x] L95 [unported-skill] `setup-pstack` in `` …per role (configurable via `/setup-pstack`. Defaults `grok-4.7-xhigh-fa… ``
- [x] L95 [unported-skill] `setup-pstack` in `` …per role (configurable via `/setup-pstack`. Defaults `grok-4.7-xhigh-fa… ``
- [x] L97 [cursor:grok] `grok` in `` …rm workers` model and speed (`grok-4.7-xhigh-fast` by default).… ``
- [x] L97 [cursor:Task-tool] `the Task` in `…stays on the parent model. If the Task tool rejects the adjusted slu…`
- [x] L97 [pstack] `pstack` in `` …ed the job needs. The `/setup-pstack` budget sets each role's star… ``
- [x] L97 [unported-skill] `setup-pstack` in `` …nd speed the job needs. The `/setup-pstack` budget sets each role's star… ``
- [x] L146 [cursor:Cursor] `Cursor` in `…licit pause, going offline, a Cursor restart, or imminent context…`

### pclaude-poteto-mode/playbooks/bug-fix.md

- [x] L8 [cursor:Cursor] `Cursor` in `` …a long or stubborn hunt with Cursor's `/loop` command. Confirm th… ``
- [x] L9 [cursor:grok] `grok` in `` …gured bug-fix model (default `grok-4.7-xhigh-fast`) with a speci… ``

### pclaude-poteto-mode/playbooks/feature.md

- [x] L12 [cursor:grok] `grok` in `` …gured feature model (default `grok-4.7-xhigh-fast`) with a speci… ``

### pclaude-poteto-mode/playbooks/opening-a-pr.md

- [x] L5 [cursor:Task-tool] `` `Task` `` in `` …ubagents inherit it. Multiple `Task` calls on the same branch each… ``
- [x] L9 [cursor:deslop] `deslop` in `` **PRs.** Run `/deslop` from `cursor-team-kit` over… ``
- [x] L9 [cursor:cursor-team-kit] `cursor-team-kit` in `` **PRs.** Run `/deslop` from `cursor-team-kit` over the diff before commit… ``
- [x] L34 [cursor:deslop] `deslop` in `` …runs `pclaude-interrogate`, `/deslop`, and `/pclaude-no-comments`,… ``

### pclaude-poteto-mode/playbooks/refactoring.md

- [x] L11 [cursor:grok] `grok` in `` …d refactoring model (default `grok-4.7-xhigh-fast`) with a speci… ``

## Ticket 10

Helper skills and pclaude-help.

### pclaude-create-verification-skill/SKILL.md

- [x] L9 [cursor:.cursor] `.cursor` in `` …at as a project-local skill (`.cursor/skills/verify-<app>/`) tailor… ``
- [x] L25 [cursor:.cursor] `.cursor` in `` Write `.cursor/skills/verify-<app>/SKILL.md`… ``
- [x] L36 [cursor:.cursor] `.cursor` in `` Create `.cursor/skills/verify-<app>/features/… ``

### pclaude-help/SKILL.md

- [x] L13 [cursor:cursor.com] `github.com/cursor/` in `` …file's public copy: `https://github.com/cursor/plugins/blob/main/pstack/` fol… ``
- [x] L13 [pstack] `pstack` in `` ….com/cursor/plugins/blob/main/pstack/` followed by its path. ``
- [x] L27 [cursor:.cursor] `.cursor` in `` - No `~/.cursor/rules/pclaude-models.mdc` mea… ``
- [x] L27 [cursor:.mdc] `.mdc` in `` …~/.cursor/rules/pclaude-models.mdc` means `/setup-pstack` hasn't… ``
- [x] L27 [pstack] `pstack` in `` …ude-models.mdc` means `/setup-pstack` hasn't run for this user, so… ``
- [x] L27 [unported-skill] `setup-pstack` in `` …s/pclaude-models.mdc` means `/setup-pstack` hasn't run for this user, so… ``
- [x] L27 [unknown-skill] `pclaude-models` in `` - No `~/.cursor/rules/pclaude-models.mdc` means `/setup-pstack` ha… ``
- [x] L32 [pstack] `pstack` in `` - Now: give them `/setup-pstack` to type, and answer their qu… ``
- [x] L32 [unported-skill] `setup-pstack` in `` - Now: give them `/setup-pstack` to type, and answer their qu… ``
- [x] L33 [pstack] `pstack` in `` …model until they run `/setup-pstack`. ``
- [x] L33 [unported-skill] `setup-pstack` in `` …efault model until they run `/setup-pstack`. ``
- [x] L38 [pstack] `pstack` in `` 2. Run [`/setup-pstack`](../setup-pstack/SKILL.md).… ``
- [x] L38 [pstack] `pstack` in `` 2. Run [`/setup-pstack`](../setup-pstack/SKILL.md).… ``
- [x] L38 [unported-skill] `setup-pstack` in `` 2. Run [`/setup-pstack`](../setup-pstack/SKILL.md).… ``
- [x] L38 [unported-skill] `setup-pstack` in `` 2. Run [`/setup-pstack`](../setup-pstack/SKILL.md).… ``
- [x] L38 [dangling-link] `../setup-pstack/SKILL.md` in `` 2. Run [`/setup-pstack`](../setup-pstack/SKILL.md). It asks for a reasoning bud… ``
- [x] L41 [pstack] `pstack` in `` …invokes a skill. Only `/setup-pstack` loads from the user's words.… ``
- [x] L41 [unported-skill] `setup-pstack` in `` …user invokes a skill. Only `/setup-pstack` loads from the user's words.… ``
- [x] L41 [dangling-link] `../../README.md` in `…he user's words. The [README](../../README.md) and [guide page 1](../docs/0…`
- [x] L43 [pstack] `pstack` in `` …review panels. Rerun `/setup-pstack` and pick a smaller budget or… ``
- [x] L43 [unported-skill] `setup-pstack` in `` …ts and review panels. Rerun `/setup-pstack` and pick a smaller budget or… ``
- [x] L45 [cursor:Cursor] `Cursor` in `pclaude is built for Cursor. Its skills use the Agent Ski…`
- [x] L45 [cursor:Cursor] `Cursor` in `pclaude is built for Cursor. Its skills use the Agent Ski…`
- [x] L45 [cursor:Cursor] `Cursor` in `pclaude is built for Cursor. Its skills use the Agent Ski…`
- [x] L55 [cursor:Cursor] `Cursor` in `- Cursor's docs list Custom Modes in t…`
- [x] L57 [cursor:Cursor] `Cursor` in `Link [Cursor's skills docs](https://cursor…`
- [x] L57 [cursor:cursor.com] `cursor.com` in `…Cursor's skills docs](https://cursor.com/docs/skills) when this comes…`
- [x] L89 [pstack] `pstack` in `` …a reasoning budget | [`/setup-pstack`](../setup-pstack/SKILL.md) | ``
- [x] L89 [pstack] `pstack` in `` …a reasoning budget | [`/setup-pstack`](../setup-pstack/SKILL.md) | ``
- [x] L89 [unported-skill] `setup-pstack` in `` …e and a reasoning budget | [`/setup-pstack`](../setup-pstack/SKILL.md) | ``
- [x] L89 [unported-skill] `setup-pstack` in `` …e and a reasoning budget | [`/setup-pstack`](../setup-pstack/SKILL.md) | ``
- [x] L89 [dangling-link] `../setup-pstack/SKILL.md` in `` …ng budget | [`/setup-pstack`](../setup-pstack/SKILL.md) | ``
- [x] L93 [cursor:grok] `Grok` in `` …d a page whose buttons wake a Grok Bot over a webhook | [`/make-… ``
- [x] L93 [unported-skill] `make-bot-ui` in `` …Grok Bot over a webhook | [`/make-bot-ui`](../make-bot-ui/SKILL.md) | ``
- [x] L93 [unported-skill] `make-bot-ui` in `` …Grok Bot over a webhook | [`/make-bot-ui`](../make-bot-ui/SKILL.md) | ``
- [x] L93 [dangling-link] `../make-bot-ui/SKILL.md` in `` …a webhook | [`/make-bot-ui`](../make-bot-ui/SKILL.md) | ``
- [x] L109 [cursor:deslop] `deslop` in `` - `/deslop`, `control-cli`, and `control… ``
- [x] L109 [cursor:control-ui] `control-ui` in `` …/deslop`, `control-cli`, and `control-ui` ship in the `cursor-team-kit… ``
- [x] L109 [cursor:control-cli] `control-cli` in `` - `/deslop`, `control-cli`, and `control-ui` ship in th… ``
- [x] L109 [cursor:cursor-team-kit] `cursor-team-kit` in `` …and `control-ui` ship in the `cursor-team-kit` plugin. ``
- [x] L110 [cursor:Cursor] `Cursor` in `` …loop` and `/create-skill` are Cursor built-ins. ``
- [x] L124 [cursor:Cursor] `Cursor` in `…s "babysit this pr" can start Cursor's own skill for the same job…`
- [x] L126 [cursor:Cursor] `Cursor` in `…claude has no planning skill. Cursor's Plan Mode works alongside i…`
- [x] L136 [pstack] `pstack` in `` …ffect | The rule from `/setup-pstack` applies to new chats. Start… ``
- [x] L136 [unported-skill] `setup-pstack` in `` …d no effect | The rule from `/setup-pstack` applies to new chats. Start… ``
- [x] L138 [pstack] `pstack` in `` …oad on its own | Only `/setup-pstack` loads from the user's words.… ``
- [x] L138 [unported-skill] `setup-pstack` in `` …dn't load on its own | Only `/setup-pstack` loads from the user's words.… ``

### pclaude-maintain-verification-skill/SKILL.md

- [x] L25 [cursor:.cursor] `.cursor` in `` …s and a feature map (usually `.cursor/skills/verify-*/`). Several c… ``

## Ticket 11

Shared transcript reader and the skills that read transcripts.

### pclaude-automate-me/SKILL.md

- [x] L11 [cursor:Cursor] `Cursor` in `` …ine mining pass (see step 1), Cursor's built-in `create-skill` (au… ``
- [x] L17 [cursor:AskQuestion] `AskQuestion` in `` …exists, confirm intent with `AskQuestion` (unless they already said "u… ``
- [x] L17 [cursor:.cursor] `.cursor` in `` Look recursively for `.cursor/skills/**/*-mode/SKILL.md` an… ``
- [x] L17 [cursor:.cursor] `.cursor` in `` Look recursively for `.cursor/skills/**/*-mode/SKILL.md` an… ``
- [x] L17 [cursor:.cursor] `.cursor` in `` Look recursively for `.cursor/skills/**/*-mode/SKILL.md` an… ``
- [x] L29 [cursor:.cursor] `.cursor` in `` …at path. Don't glob across `~/.cursor/projects/*/`. That crosses wo… ``
- [x] L44 [cursor:AskQuestion] `AskQuestion` in `` …hasn't come up yet. Use the `AskQuestion` tool (structured multi-choic… ``
- [x] L67 [cursor:Cursor] `Cursor` in `` Use Cursor's built-in `create-skill` ski… ``
- [x] L69 [cursor:.cursor] `.cursor` in `` …ategory. For a new mode, use `.cursor/skills/<handle>/<handle>-mode… ``
- [x] L69 [cursor:.cursor] `.cursor` in `` …ategory. For a new mode, use `.cursor/skills/<handle>/<handle>-mode… ``
- [x] L69 [cursor:.cursor] `.cursor` in `` …ategory. For a new mode, use `.cursor/skills/<handle>/<handle>-mode… ``

### pclaude-poteto-mode/playbooks/eval.md

- [x] L22 [cursor:.cursor] `.cursor` in `` …path). Do not glob across `~/.cursor/projects/*/`. That crosses wo… ``

### pclaude-poteto-mode/playbooks/session-pickup.md

- [x] L5 [cursor:.cursor] `.cursor` in `` …e path. Do not glob across `~/.cursor/projects/*/`, that crosses wo… ``

### pclaude-poteto-mode/scripts/worktree-audit.sh

- [x] L64 [cursor:.cursor] `.cursor` in `# Transcripts dir: ~/.cursor/projects/<slugified-repo-path…`
- [x] L66 [cursor:.cursor] `.cursor` in `transcripts="$HOME/.cursor/projects/$slug/agent-transcri…`

### pclaude-recall/SKILL.md

- [x] L15 [cursor:.cursor] `.cursor` in `` Transcripts live at `~/.cursor/projects/<slug>/agent-transcr… ``

### pclaude-reflect/SKILL.md

- [x] L15 [cursor:.cursor] `.cursor` in `` …names. Do not glob across `~/.cursor/projects/*/`. That crosses wo… ``
- [x] L25 [cursor:Task-tool] `` `Task` `` in `` One message, three `Task` calls, `subagent_type: genera… ``
- [x] L27 [cursor:.mdc] `.mdc` in `` …le line in the `pclaude-models.mdc` rule and a default. Set `mod… ``
- [x] L27 [cursor:Task-tool] `the Task` in `` …auto` or `inherit-parent`. If the Task tool rejects a slug, use the… ``
- [x] L27 [unknown-skill] `pclaude-models` in `` …izer name a role line in the `pclaude-models.mdc` rule and a default. Set… ``
- [x] L32 [cursor:grok] `grok` in `` …ooling | `reflect tooling` | `grok-4.7-xhigh-fast` | `references… ``
- [x] L35 [cursor:Task-tool] `` `Task` `` in `` …iewers return findings in the `Task` response body. ``
- [x] L39 [cursor:Task-tool] `` `Task` `` in `` One `Task` call, `subagent_type: general… ``
- [x] L54 [cursor:Cursor] `Cursor` in `` …more than ~10 lines): hand to Cursor's built-in `create-skill` ski… ``

### pclaude-reflect/references/divergent-reviewer.md

- [x] L21 [cursor:.cursor] `.cursor` in `` …ad` of its `SKILL.md` (under `.cursor/skills/`, `~/.cursor/skills/`… ``
- [x] L21 [cursor:.cursor] `.cursor` in `` …ad` of its `SKILL.md` (under `.cursor/skills/`, `~/.cursor/skills/`… ``
- [x] L21 [cursor:.cursor] `.cursor` in `` …ad` of its `SKILL.md` (under `.cursor/skills/`, `~/.cursor/skills/`… ``
- [x] L21 [cursor:Task-tool] `` `Task` `` in `` …, or `~/.cursor/plugins/`), a `Task` prompt naming its path, or a… ``

### pclaude-reflect/references/judgment-reviewer.md

- [x] L20 [cursor:.cursor] `.cursor` in `` …ad` of its `SKILL.md` (under `.cursor/skills/`, `~/.cursor/skills/`… ``
- [x] L20 [cursor:.cursor] `.cursor` in `` …ad` of its `SKILL.md` (under `.cursor/skills/`, `~/.cursor/skills/`… ``
- [x] L20 [cursor:.cursor] `.cursor` in `` …ad` of its `SKILL.md` (under `.cursor/skills/`, `~/.cursor/skills/`… ``
- [x] L20 [cursor:Task-tool] `` `Task` `` in `` …, or `~/.cursor/plugins/`), a `Task` prompt naming its path, or a… ``

### pclaude-reflect/references/tooling-reviewer.md

- [x] L31 [cursor:.cursor] `.cursor` in `` …ad` of its `SKILL.md` (under `.cursor/skills/`, `~/.cursor/skills/`… ``
- [x] L31 [cursor:.cursor] `.cursor` in `` …ad` of its `SKILL.md` (under `.cursor/skills/`, `~/.cursor/skills/`… ``
- [x] L31 [cursor:.cursor] `.cursor` in `` …ad` of its `SKILL.md` (under `.cursor/skills/`, `~/.cursor/skills/`… ``
- [x] L31 [cursor:Task-tool] `` `Task` `` in `` …, or `~/.cursor/plugins/`), a `Task` prompt naming its path, or a… ``

### pclaude-show-me-your-work/SKILL.md

- [x] L57 [cursor:.cursor] `.cursor` in `` …e path). Don't glob across `~/.cursor/projects/*/`. That reads unre… ``

## Ticket 12

Remaining simple playbooks and multi-phase-plan.

### pclaude-poteto-mode/playbooks/authoring-a-skill.md

- [x] L5 [cursor:Cursor] `Cursor` in `…e the **create-skill** skill (Cursor's built-in for authoring SKIL…`

### pclaude-poteto-mode/playbooks/autonomous-run.md

- [x] L6 [cursor:Cursor] `Cursor` in `` …Pick the wake mechanism using Cursor's `/loop` command (a built-in… ``
- [x] L9 [cursor:AskQuestion] `AskQuestion` in `` …le work for the human or use `AskQuestion`. Surface only irreversible a… ``

### pclaude-poteto-mode/playbooks/hillclimb.md

- [x] L12 [cursor:grok] `grok` in `` …red hillclimb model (default `grok-4.7-xhigh-fast`) with a tight… ``

### pclaude-poteto-mode/playbooks/multi-phase-plan.md

- [x] L13 [cursor:grok] `grok` in `` …warm workers` model (default `grok-4.7-xhigh-fast`). Each lane i… ``
- [x] L15 [cursor:control-ui] `control-ui` in `` …r, Electron, and web UIs use `control-ui` from `cursor-team-kit`. CLIs… ``
- [x] L15 [cursor:control-cli] `control-cli` in `` …team-kit`. CLIs and TUIs use `control-cli` from `cursor-team-kit`. Nati… ``
- [x] L15 [cursor:cursor-team-kit] `cursor-team-kit` in `` …eb UIs use `control-ui` from `cursor-team-kit`. CLIs and TUIs use `control-… ``
- [x] L15 [cursor:cursor-team-kit] `cursor-team-kit` in `` …eb UIs use `control-ui` from `cursor-team-kit`. CLIs and TUIs use `control-… ``
- [x] L59 [cursor:deslop] `deslop` in `` - [x] Run `/deslop` before each commit and `/pcl… ``
- [x] L71 [cursor:control-ui] `control-ui` in `` …t the PR head. Drive through `control-ui` or `control-cli` from `curso… ``
- [x] L71 [cursor:control-cli] `control-cli` in `` …rive through `control-ui` or `control-cli` from `cursor-team-kit`. ``
- [x] L71 [cursor:cursor-team-kit] `cursor-team-kit` in `` …ol-ui` or `control-cli` from `cursor-team-kit`. ``

### pclaude-poteto-mode/playbooks/perf-issue.md

- [x] L17 [cursor:grok] `grok` in `` …ed perf-issue model (default `grok-4.7-xhigh-fast`). Pick each s… ``

### pclaude-poteto-mode/playbooks/worktree-cleanup.md

- [x] L3 [cursor:.cursor] `.cursor` in `` …/x` misses one that lives at `.cursor/worktrees/myrepo/x` (principl… ``
- [x] L8 [cursor:Cursor] `Cursor` in `` …~/Library/Application Support/Cursor` (`state.vscdb.backup`, and `… ``

## Ticket 13

babysit, shipping and watch-pr over every PR comment.

### pclaude-poteto-mode/playbooks/babysit.md

- [x] L3 [cursor:Cursor] `Cursor` in `…ins.** This playbook replaces Cursor's built-in babysit skill for…`

### pclaude-poteto-mode/playbooks/shipping.md

- [x] L5 [cursor:control-ui] `control-ui` in `` …ching control skill (such as `control-ui` or `control-cli` from `curso… ``
- [x] L5 [cursor:control-cli] `control-cli` in `` …ill (such as `control-ui` or `control-cli` from `cursor-team-kit`), par… ``
- [x] L5 [cursor:cursor-team-kit] `cursor-team-kit` in `` …ol-ui` or `control-cli` from `cursor-team-kit`), parent against head, and p… ``
- [x] L5 [cursor:Cursor] `Cursor` in `…. One verifier per PR, each a Cursor cloud agent, runs the change…`

### pclaude-poteto-mode/scripts/bun.lock

- [x] L6 [cursor:cursor-name] `cursor-skill` in `"name": "@cursor-skill/poteto-mode-tools",`

### pclaude-poteto-mode/scripts/package.json

- [x] L2 [cursor:cursor-name] `cursor-skill` in `"name": "@cursor-skill/poteto-mode-tools",`

### pclaude-poteto-mode/scripts/watch-pr/github.test.ts

- [x] L258 [cursor:cursor-name] `CURSOR_AUTOMATION_ID` in `body: "CURSOR_AUTOMATION_ID: run-2 severity high",`
- [x] L262 [cursor:cursor-name] `"cursor"` in `…author: { login: "cursor" },`

### pclaude-poteto-mode/scripts/watch-pr/github.ts

- [x] L335 [cursor:cursor-name] `"cursor"` in `(author === "cursor" &&`
- [x] L338 [cursor:cursor-name] `cursor_automation_id` in `"cursor_automation_id",`
- [x] L349 [cursor:cursor-name] `CURSOR_AUTOMATION_ID` in `/CURSOR_AUTOMATION_ID:\s*([a-zA-Z0-9_.:-]+)/,`

## Ticket 14

Autopilots and orchestrate.

### pclaude-poteto-mode/playbooks/autopilot-full.md

- [x] L8 [cursor:Cursor] `Cursor` in `` …phite (`gt`). Each owner is a Cursor cloud agent that builds, open… ``
- [x] L10 [cursor:deslop] `deslop` in `` …ly after the slop-strip (the `deslop` skill from the `cursor-team-… ``
- [x] L10 [cursor:deslop] `deslop` in `` …ly after the slop-strip (the `deslop` skill from the `cursor-team-… ``
- [x] L10 [cursor:cursor-team-kit] `cursor-team-kit` in `` …(the `deslop` skill from the `cursor-team-kit` plugin (`/deslop`)) and the… ``
- [x] L14 [cursor:control-ui] `control-ui` in `` …h its control skill (such as `control-ui` or `control-cli` from `curso… ``
- [x] L14 [cursor:control-cli] `control-cli` in `` …ill (such as `control-ui` or `control-cli` from `cursor-team-kit`) or a… ``
- [x] L14 [cursor:cursor-team-kit] `cursor-team-kit` in `` …ol-ui` or `control-cli` from `cursor-team-kit`) or a named driver, and audi… ``

### pclaude-poteto-mode/playbooks/orchestrate.md

- [x] L15 [cursor:Task-tool] `the Task` in `…med, and drained only through the Task tool. Pick each subagent's re…`
- [x] L16 [cursor:Task-tool] `Task schema` in `` …d a nested spawn has the full Task schema including `environment`). Rol… ``
- [x] L17 [cursor:control-ui] `control-ui` in `` …the task needs this machine: `control-ui` or `control-cli` runtime ver… ``
- [x] L17 [cursor:control-cli] `control-cli` in `` …his machine: `control-ui` or `control-cli` runtime verification (from `… ``
- [x] L17 [cursor:cursor-team-kit] `cursor-team-kit` in `` …` runtime verification (from `cursor-team-kit`). Reading local transcripts… ``
- [x] L96 [cursor:Cursor] `Cursor` in `…e cloud agent's status in the Cursor dashboard. Transcript mtime i…`
- [x] L102 [cursor:Cursor] `Cursor` in `- After a Cursor restart: local agents are dea…`

## Ticket 15

Rewrite docs/guide for Claude Code.

### docs/01-setup.md

- [x] L7 [cursor:Cursor] `Cursor` in `In a Cursor chat, run:`
- [x] L13 [cursor:Cursor] `Cursor` in `Cursor confirms the plugin is instal…`
- [x] L20 [pstack] `pstack` in `/setup-pstack`
- [x] L20 [unported-skill] `setup-pstack` in `/setup-pstack`
- [x] L23 [cursor:.cursor] `.cursor` in `` …r the questions. It writes `~/.cursor/rules/pclaude-models.mdc`, a… ``
- [x] L23 [cursor:.mdc] `.mdc` in `` …~/.cursor/rules/pclaude-models.mdc`, a small rule every pclaude… ``
- [x] L23 [pstack] `pstack` in `` [`/setup-pstack`](../../skills/setup-pstack/S… ``
- [x] L23 [pstack] `pstack` in `` [`/setup-pstack`](../../skills/setup-pstack/S… ``
- [x] L23 [unported-skill] `setup-pstack` in `` [`/setup-pstack`](../../skills/setup-pstack/S… ``
- [x] L23 [unported-skill] `setup-pstack` in `` [`/setup-pstack`](../../skills/setup-pstack/S… ``
- [x] L23 [dangling-link] `../../skills/setup-pstack/SKILL.md` in `` [`/setup-pstack`](../../skills/setup-pstack/SKILL.md) detects the models you have… ``
- [x] L23 [unknown-skill] `pclaude-models` in `` …s. It writes `~/.cursor/rules/pclaude-models.mdc`, a small rule every pcla… ``
- [x] L25 [cursor:grok] `Grok` in `` …to `max`. Opus goes to `max`. Grok tops out at `xhigh`, so it st… ``
- [x] L27 [pstack] `pstack` in `` …le's line. A rerun of `/setup-pstack` keeps any role whose model d… ``
- [x] L27 [pstack] `pstack` in `` …le's line. A rerun of `/setup-pstack` keeps any role whose model d… ``
- [x] L27 [unported-skill] `setup-pstack` in `` …hat role's line. A rerun of `/setup-pstack` keeps any role whose model d… ``
- [x] L27 [unported-skill] `setup-pstack` in `` …hat role's line. A rerun of `/setup-pstack` keeps any role whose model d… ``
- [x] L33 [pstack] `pstack` in `` At the end of setup, `/setup-pstack` looks for a way to prove app… ``
- [x] L33 [unported-skill] `setup-pstack` in `` At the end of setup, `/setup-pstack` looks for a way to prove app… ``
- [x] L35 [cursor:.cursor] `.cursor` in `` Say yes and it writes `.cursor/skills/verify-<app>/`, a proj… ``
- [x] L45 [pstack] `pstack` in `` - Rerun `/setup-pstack` and pick a smaller reasoning… ``
- [x] L45 [unported-skill] `setup-pstack` in `` - Rerun `/setup-pstack` and pick a smaller reasoning… ``
- [x] L60 [cursor:cursor.com] `cursor.com` in `…es it a [Custom Mode](https://cursor.com/docs/skills), which stays in…`

### docs/02-poteto-mode.md

- [x] L99 [cursor:cursor.com] `cursor.com` in `…is a [cloud subagent](https://cursor.com/docs/subagents#cloud-subagent…`

### docs/04-design.md

- [x] L47 [pstack] `pstack` in `` …anel comes from your [`/setup-pstack`](../../skills/setup-pstack/S… ``
- [x] L47 [pstack] `pstack` in `` …anel comes from your [`/setup-pstack`](../../skills/setup-pstack/S… ``
- [x] L47 [unported-skill] `setup-pstack` in `` The panel comes from your [`/setup-pstack`](../../skills/setup-pstack/S… ``
- [x] L47 [unported-skill] `setup-pstack` in `` The panel comes from your [`/setup-pstack`](../../skills/setup-pstack/S… ``
- [x] L47 [dangling-link] `../../skills/setup-pstack/SKILL.md` in `` …s from your [`/setup-pstack`](../../skills/setup-pstack/SKILL.md) configuration, and you can a… ``

### docs/05-build-and-clean.md

- [x] L59 [cursor:deslop] `deslop` in `` …books/opening-a-pr.md) runs `/deslop` on the diff before each comm… ``
- [x] L59 [cursor:deslop] `deslop` in `` …books/opening-a-pr.md) runs `/deslop` on the diff before each comm… ``
- [x] L59 [cursor:cursor-team-kit] `cursor-team-kit` in `` …dies. `/deslop` ships in the `cursor-team-kit` plugin, not in pclaude. If y… ``
- [x] L79 [cursor:deslop] `deslop` in `` …is worth keeping straight. `/deslop` cleans slop out of the code,… ``
- [x] L81 [cursor:deslop] `deslop` in `` …f the diff feels padded, say `deslop it` before you commit, not af… ``

### docs/06-verify-and-ship.md

- [x] L61 [cursor:.cursor] `.cursor` in `` It writes `.cursor/skills/verify-<app>/`, agent-… ``

### docs/07-overnight.md

- [x] L35 [cursor:Cursor] `Cursor` in `` - `/loop` is Cursor's built-in wake mechanism, no… ``
- [x] L40 [cursor:Cursor] `Cursor` in `…bout to go offline or restart Cursor. The [Pause safely playbook](…`
- [x] L94 [cursor:Cursor] `Cursor` in `A [Cursor Project](https://cursor.com/b…`
- [x] L94 [cursor:cursor.com] `cursor.com` in `A [Cursor Project](https://cursor.com/blog/projects) gives one coor…`
- [x] L116 [dangling-link] `../../automations/benny/README.md` in `…s a dormant [automation pack](../../automations/benny/README.md) for Slack issue reports. One…`
- [x] L116 [dangling-link] `../../automations/benny/FOR_AGENTS.md` in `` …gent at its [`FOR_AGENTS.md`](../../automations/benny/FOR_AGENTS.md) and name the target reposito… ``

### docs/09-make-it-yours.md

- [x] L13 [cursor:.cursor] `.cursor` in `` …ns are really you. It drafts `.cursor/skills/<your-name>-mode/SKILL… ``
- [x] L13 [cursor:Cursor] `Cursor` in `` …-name>-mode/SKILL.md` through Cursor's built-in `create-skill` flo… ``
- [x] L60 [cursor:Cursor] `Cursor` in `` …ill.md), which routes through Cursor's built-in `create-skill`, va… ``
- [x] L94 [unported-skill] `make-bot-ui` in `` ## Build a bot UI with `/make-bot-ui` ``
- [x] L96 [cursor:grok] `Grok` in `` One situational skill is for Grok Bot users. [`/make-bot-ui`](.… ``
- [x] L96 [unported-skill] `make-bot-ui` in `` …ill is for Grok Bot users. [`/make-bot-ui`](../../skills/make-bot-ui/SK… ``
- [x] L96 [unported-skill] `make-bot-ui` in `` …ill is for Grok Bot users. [`/make-bot-ui`](../../skills/make-bot-ui/SK… ``
- [x] L96 [dangling-link] `../../skills/make-bot-ui/SKILL.md` in `` …k Bot users. [`/make-bot-ui`](../../skills/make-bot-ui/SKILL.md) builds a small page whose bu… ``
