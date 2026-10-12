# Fork conventions

This repo is Billy's fork of `mattpocock/skills` (`upstream`). These rules keep local customisations safe across upstream merges.

## Language

**Upstream-owned**: a file whose path exists in `upstream/main` (`mattpocock/skills`). Examples: `skills/productivity/grilling/SKILL.md`, `GLOSSARY.md`.

**Fork-owned**: a path that does not exist upstream. Merges never touch it. Examples: `skills/personal/`, `skills/personal/my-grilling/`.

**Vendored skill**: a skill copied verbatim from a third-party repo into `skills/personal/` by `update-skills.sh` on every run, keeping its upstream name. Fork-owned by path, but read-only in practice: the sync deletes and re-copies it each run, so local edits are destroyed. Currently `thermo-nuclear-code-quality-review` (from `cursor/plugins`) and the six Effective HTML skills `html`, `design-artifact`, `html-wireframe`, `html-prototype`, `html-plan`, `html-diagram` (from `plannotator/effective-html`). To change one, fork it under the `my-*` convention instead. The one exception is `make_user_invoked` in `update-skills.sh`, which re-applies the user-invoked flags (`disable-model-invocation: true`, `allow_implicit_invocation: false`) to the Effective HTML skills after every copy; it is a scripted patch, so it survives the sync.
_Avoid_: synced skill (that is the `gcp-`/`android-`/`addy-`/`pstack-` whole-repo bucket mechanism, which prefixes names and tracks a manifest)

**Synced bucket**: a whole upstream skill collection copied by `sync_source` in `update-skills.sh` into `skills/<prefix>/<prefix>-<name>/`, with a manifest (`.skills-sync-<prefix>.list`) so skills dropped upstream are removed here. Currently `gcp/` (google/skills), `android/` (android/skills), `addy/` (addyosmani/agent-skills) and `pstack/` (the `pstack/` plugin of cursor/plugins). Like a vendored skill it is read-only in practice, and frontmatter `name:` fields are left as upstream wrote them (the dir name carries the prefix).
- **Agents**: `addy/` and `pstack/` also ship subagents. `sync_agents` copies them into `skills/<prefix>/agents/<prefix>-<name>.md`, prefixing the frontmatter `name:` (an agent is addressed by that field). The dir holds no `SKILL.md`, so the manifest, the stale sweep and `link-skills.sh`'s skill discovery all pass over it.
- **Reference rewrite**: after each sync, `rewrite_bucket_refs` rewrites references to the bucket's own skills and agents to the prefixed names across every `.md` in the bucket, so `/poteto-mode` becomes `/pstack-poteto-mode`. Only `/name` slash commands, exact `` `name` `` backtick spans, `../name/` relative links, and bare `principle-*` skill names are touched; plain words are not, since pstack has skills called `how`, `why`, `bro` and `tdd`. It is idempotent and re-applied every run, like `make_user_invoked`.

**Skill set**: which of the switchable buckets is linked into the harness dirs: `pocock` (`engineering/`, `productivity/`, `in-progress/`; the default), `addy`, `pstack`, or `all`. `gcp/`, `android/` and `personal/` are always on. Switch with `scripts/use-skills.sh <set>`; the choice persists in the git-ignored `.skill-set`, and `link-skills.sh`, `link-opencode-commands.sh` and `update-skills.sh` all honour it. The sets exist because the three collections overlap heavily (each has its own TDD, review and planning flow), so running more than one at once mostly adds noise.

## Rules

- Never edit upstream-owned files to make personal changes — the edit will conflict or be wiped on the next `upstream` merge. Copy the content into a fork-owned path instead.
- Personal copies of upstream skills live in `skills/personal/` under a `my-*` prefix:
  - `my-grilling` — the grilling flow, but asked in rounds and tuned for voice-typed replies
  - `my-grill-me`, `my-grill-with-docs` — wrappers routing to `/my-grilling`
  - `my-wayfinder` — wayfinder, diverged only by an **Orient** step that opens each HITL session with a `/sitrep`, and by `/my-grilling` in place of `/grilling`. A full copy, not a wrapper: `wayfinder` is user-invoked, so no skill can invoke it. Re-sync by hand when upstream changes `wayfinder`.
- `my-*` skills are deliberately absent from the router (`ask-matt` is upstream-owned) and from the top-level `README.md` / `plugin.json` (promoted skills only). Invoke them by name.
- `scripts/link-skills.sh` and `scripts/link-opencode-commands.sh` glob the whole repo, so new fork-owned skills are linked everywhere (Claude, `~/.agents`, Cursor, OpenCode) by `scripts/update-skills.sh` with no extra wiring, as long as they sit in an always-on bucket or the active **Skill set**. A new bucket needs a case in `skill_path_set` in `scripts/skill-sets.sh`; anything unmatched is treated as always on.
- A **Vendored skill** is never edited in place. Any fix belongs in a `my-*` fork of it, or upstream.
