Skills are organized into bucket folders under `skills/`:

- `engineering/`: daily code work
- `productivity/`: daily non-code workflow tools
- `misc/`: kept around but rarely used, not promoted
- `in-progress/`: beta: public on purpose, feedback wanted, not shipped in the plugin
- `deprecated/`: no longer used
- `personal/`: fork-owned and not promoted. My own `my-*` skills, plus individually vendored third-party skills that `update-skills.sh` re-copies verbatim on every run (see [FORK.md](./FORK.md)).
- `gcp/`: Google Cloud skills, not promoted, synced from upstream
- `android/`: Android skills, not promoted, synced from upstream
- `addy/`: Addy Osmani's agent skills and agents, not promoted, synced from upstream
- `pstack/`: the pstack skills and agents from Cursor's plugins repo, not promoted, synced from upstream

`gcp/`, `android/`, `addy/` and `pstack/` are upstream-synced, non-promoted buckets. `update-skills.sh` clones https://github.com/google/skills.git into `skills/gcp/`, https://github.com/android/skills.git into `skills/android/`, https://github.com/addyosmani/agent-skills.git into `skills/addy/`, and the `pstack/` plugin of https://github.com/cursor/plugins.git into `skills/pstack/`, keeping each skill's `gcp-`/`android-`/`addy-`/`pstack-` prefixed name, and regenerates each bucket's `README.md` every run. `addy/` and `pstack/` also carry their upstream subagents in `agents/`, `addy/` also gets its upstream slash commands as user-invoked `addy-<cmd>` skills, and the sync rewrites references to each bucket's own skills and agents to the prefixed names (see [FORK.md](./FORK.md)). None of these buckets may appear in the top-level `README.md`, `.claude-plugin/plugin.json`, `docs/`, or `ask-matt`.

Every skill in `engineering/` or `productivity/` (the **promoted** buckets) must have a reference in the top-level `README.md` and an entry in `.claude-plugin/plugin.json`'s `skills` array (the Claude Code plugin ships exactly the promoted set). Skills in the non-promoted buckets (`misc/`, `in-progress/`, `deprecated/`, `personal/`, `gcp/`, `android/`, `addy/`, `pstack/`) must not appear in either.

Install commands are copied verbatim from [.agents/install-block.md](./.agents/install-block.md). `.claude-plugin/marketplace.json` is the repo's own marketplace. Every agent except Claude Code installs from it to get automatic updates, and Claude Code uses `claude-plugins-official`. Run `claude plugin validate . --strict` after touching either manifest. [ADR 0002](./.agents/adr/0002-ship-as-a-claude-code-plugin.md) records why.

Each skill entry in the top-level `README.md` must link the skill name to its `SKILL.md`.

Each bucket folder has a `README.md` that lists every skill in the bucket with a one-line description, with the skill name linked to its `SKILL.md`. The promoted buckets' `README.md`s and the top-level `README.md` group entries into **User-invoked** and **Model-invoked**; non-promoted bucket `README.md`s (`misc/`, `in-progress/`, `personal/`, `gcp/`, `android/`, `addy/`, `pstack/`) use a flat list.

Skills in `engineering/` and `productivity/` also have a human-facing docs page at `docs/<bucket>/<skill-name>.md` (the docs tree mirrors those two bucket folders under `skills/`). The published URL is `https://aihero.dev/skills-<skill-name>` regardless of bucket: the docs path is repo organisation only. When you add, rename, or change the behaviour of a skill in `engineering/` or `productivity/`, create or re-sync its docs page following [.agents/writing-docs.md](./.agents/writing-docs.md). A finished page carries four sections: **What it does**, **When to reach for it**, **Common questions**, and **It's working if**. `writing-docs.md` holds the template, the section order, and where to hunt for the questions. Skills in the non-promoted buckets (`misc/`, `in-progress/`, `deprecated/`, `personal/`, `gcp/`, `android/`, `addy/`, `pstack/`) get **no** docs page. The one exception is a promoted skill removed outright: its page stays, marked archived (see `writing-docs.md`).

Every `SKILL.md` is either user-invoked (`disable-model-invocation: true` plus `policy.allow_implicit_invocation: false` in `agents/openai.yaml`, reachable only by the human) or model-invoked (model- or user-reachable). See [.agents/invocation.md](./.agents/invocation.md).

[`ask-matt`](./skills/engineering/ask-matt/SKILL.md) is the router that maps every user-reachable skill and how they relate. The same trigger that re-syncs a docs page applies to it: whenever you add, rename, remove, or change how a user-reachable skill fits the flows, re-read `ask-matt`'s `SKILL.md` and update it so the map stays accurate: a new skill it never mentions, or a stale one it still routes to, is a router that lies.

To (re)link the active skills into the local harness skill directories (`~/.claude/skills`, `~/.agents/skills`, `~/.cursor/skills`), run `scripts/link-skills.sh`. Each entry is a symlink into this repo, so a `git pull` keeps installed skills current; re-run the script after adding, removing, or renaming a skill. Cursor is the exception: it gets real copies, because its picker won't follow symlinks.

Which skills are active is decided by **skill sets**, changed with `scripts/use-skills.sh` (no argument prints the active list). Every bucket is a set: `pocock` (`engineering/`, `productivity/`, `in-progress/`), `addy`, `pclaude`, `personal`, `gcp` and `android`. Several can be active at once: `use-skills.sh pocock pclaude personal` sets an exact list, `+set` and `-set` edit it, and `all` turns on every set. The default is `pocock personal gcp android`. Root-level skills such as `peer-review/` are always on, and `deprecated/` and `misc/` are never linked. `pstack/` is not a set: it is never linked into Claude Code, and is copied into `~/.cursor/skills` only while `pclaude` is active (`pclaude` itself never goes to Cursor). When two active sets hold the same skill or agent name, the set listed later wins and the link script warns. The list lives in the git-ignored `.skill-set` file, one set per line, and the set definitions in `scripts/skill-sets.sh`, which both link scripts source. Changing it re-runs both link scripts: they add the new sets, remove only the entries they own from inactive sets, and symlink the active sets' agents into `~/.claude/agents` (regular files there are never touched). Restart Claude afterwards.

OpenCode needs a second step, `scripts/link-opencode-commands.sh`. It finds skills on its own by globbing `~/.claude/skills` and `~/.agents/skills`, but it builds its `/` palette only from its own config dir and never reads `~/.claude/commands`, so without this a user-invoked skill (`disable-model-invocation: true`) is unreachable there, not merely unlisted. The script writes one pointer stub per active skill into `~/.config/opencode/command/`, and no-ops when OpenCode isn't installed. `update-skills.sh` runs both scripts.

No em-dashes anywhere in this repo's prose (`SKILL.md` files, docs, `README.md`, `CHANGELOG.md`, ADRs, changesets, code comments). Where a sentence reaches for one, rewrite it instead with a comma, colon, period, parentheses, or a conjunction, whichever the sentence actually wants; never do a blind character substitution.

## Agent skills

### Triage labels

Canonical names, unchanged. See `docs/agents/triage-labels.md`. Issues are judged against [`SCOPE.md`](./SCOPE.md).
