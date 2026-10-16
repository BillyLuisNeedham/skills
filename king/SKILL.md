---
name: king
description: Front door for Billy's skills repo. Show and change the active skill sets, list a set's skills, sync upstream, and hand off to the pclaude update.
disable-model-invocation: true
---

`/king` runs this repo's skill sets for Billy. Read what he typed after `/king` and do the one matching job below. With nothing after it, do **Show**. Ask only when a request names a set that does not exist or could mean two jobs. Number the questions, give your recommendation with each, and ask them all at once.

## Find the repo

```sh
REPO="$(dirname "$(readlink -f ~/.claude/skills/king)")"
```

Every command below runs from `$REPO`. `king/king.sh` and `scripts/use-skills.sh` are the only levers. Never edit `.skill-set` or the symlinks by hand.

## Sets

A **skill set** is a switchable group of skill buckets. `scripts/skill-sets.sh` defines them: `pocock`, `addy`, `pclaude`, `personal`, `gcp`, `android`. Several are active at once, in order. When two active sets hold the same skill or agent name, the set listed later wins and the link script prints a warning. `king/` and `peer-review/` sit outside every set and are always on. `skills/pstack` is Cursor's copy of pclaude, not a set.

## Show

Run `king/king.sh sets`. It prints the active list in order, then every set with its position (`#1` is first), skill count, agent count and one-line description, then the always-on skills. Relay it as is.

## List a set's skills

Run `king/king.sh skills <set>`. Relay the names with a short gloss of each description, not the full text. Keep `gcp` (over 150 skills) to names grouped by product unless Billy asks for more.

## Change sets

Map the request to one `scripts/use-skills.sh` call:

| Billy says | Command |
| --- | --- |
| an exact list ("pocock and pclaude") | `scripts/use-skills.sh pocock pclaude` |
| add a set | `scripts/use-skills.sh +pclaude` |
| remove a set | `scripts/use-skills.sh -gcp` |
| add and remove together | `scripts/use-skills.sh +pclaude -gcp` |
| everything | `scripts/use-skills.sh all` |

Plain names and `+`/`-` edits cannot share one call. `+set` appends at the end, so it wins any clash; say so when the added set clashes. An exact list replaces the whole list, so read back what drops out before running it if Billy did not name it.

The script rewrites `.skill-set`, re-links `~/.claude/skills`, `~/.agents/skills`, `~/.cursor/skills` and `~/.claude/agents`, and regenerates OpenCode commands. Relay every `warning: name clash` line it prints. Then run `king/king.sh sets` and show the new state.

Then tell Billy what picks the change up:

- **This Claude Code session picks the change up live.** Claude Code watches `~/.claude/skills/` and `~/.claude/agents/`, so added skills appear in `/` and removed ones drop out within seconds, with no restart. If a skill is still missing, `/reload-skills` re-scans.
- **A skill already loaded in this conversation stays in context** until the session ends. Removing its set stops new invocations, not the text already read.
- **Restart only** if `~/.claude/agents/` did not exist when the session started (the first agent ever linked creates it, and the watcher only covers directories that existed at start).
- **Cursor, Codex and OpenCode need a restart** to see the change.

## Sync upstream

`./update-skills.sh` pulls mattpocock/skills, re-syncs `gcp`, `android`, `addy`, `pstack` and the vendored personal skills, re-links, then **commits and pushes to origin**. Confirm the push with Billy before running it, unless his `/king` request already said to sync.

Run it with `run_in_background: true` and wait for it to finish. It stops at an `(o)verwrite / (s)kip / (a)bort` prompt when a synced directory collides with an untracked one. The Bash tool has no terminal to answer that, so the script exits. If it does, report the colliding path and tell Billy to run `! ./update-skills.sh` himself to answer the prompt.

Report what changed: the commit it made, which buckets gained or lost skills, and any clash warnings.

## pclaude update

The pclaude bucket is not synced by `update-skills.sh`. It is updated from the pstack clone at `~/repos/pstack` by a three-way merge, which needs judgment on conflicts. `/my-pclaude-update` owns that job, and it is user-only, so `/king` cannot run it. Tell Billy to run `/my-pclaude-update`.
