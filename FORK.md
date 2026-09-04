# Fork conventions

This repo is Billy's fork of `mattpocock/skills` (`upstream`). These rules keep local customisations safe across upstream merges.

## Language

**Upstream-owned**: a file whose path exists in `upstream/main` (`mattpocock/skills`). Examples: `skills/productivity/grilling/SKILL.md`, `CONTEXT.md`.

**Fork-owned**: a path that does not exist upstream. Merges never touch it. Examples: `skills/personal/`, `skills/personal/my-grilling/`.

**Vendored skill**: a skill copied verbatim from a third-party repo into `skills/personal/` by `update-skills.sh` on every run, keeping its upstream name. Fork-owned by path, but read-only in practice: the sync deletes and re-copies it each run, so local edits are destroyed. Currently `thermo-nuclear-code-quality-review` (from `cursor/plugins`) and `show-me` (from `humanlayer/skills`). To change one, fork it under the `my-*` convention instead.
_Avoid_: synced skill (that is the `gcp-`/`android-` whole-repo bucket mechanism, which prefixes names and tracks a manifest)

## Rules

- Never edit upstream-owned files to make personal changes — the edit will conflict or be wiped on the next `upstream` merge. Copy the content into a fork-owned path instead.
- Personal copies of upstream skills live in `skills/personal/` under a `my-*` prefix:
  - `my-grilling` — the grilling flow, but asked in rounds and tuned for voice-typed replies
  - `my-grill-me`, `my-grill-with-docs` — wrappers routing to `/my-grilling`
  - `my-wayfinder` — wayfinder, diverged only by an **Orient** step that opens each HITL session with a `/sitrep`, and by `/my-grilling` in place of `/grilling`. A full copy, not a wrapper: `wayfinder` is user-invoked, so no skill can invoke it. Re-sync by hand when upstream changes `wayfinder`.
- `my-*` skills are deliberately absent from the router (`ask-matt` is upstream-owned) and from the top-level `README.md` / `plugin.json` (promoted skills only). Invoke them by name.
- `scripts/link-skills.sh` and `scripts/link-opencode-commands.sh` glob the whole repo, so new fork-owned skills are linked everywhere (Claude, `~/.agents`, Cursor, OpenCode) by `scripts/update-skills.sh` with no extra wiring.
- A **Vendored skill** is never edited in place. Any fix belongs in a `my-*` fork of it, or upstream.
