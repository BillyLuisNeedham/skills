# Fork conventions

This repo is Billy's fork of `mattpocock/skills` (`upstream`). These rules keep local customisations safe across upstream merges.

## Language

**Upstream-owned**: a file whose path exists in `upstream/main` (`mattpocock/skills`). Examples: `skills/productivity/grilling/SKILL.md`, `CONTEXT.md`, `skills/personal/README.md` — including the whole `personal/` bucket's existing contents, which are Matt's.

**Fork-owned**: a path that does not exist upstream. Merges never touch it.

## Rules

- Never edit upstream-owned files to make personal changes — the edit will conflict or be wiped on the next `upstream` merge. Copy the content into a fork-owned path instead.
- Personal copies of upstream skills live in `skills/personal/` under a `my-*` prefix:
  - `my-grilling` — the grilling flow, but asked in rounds and tuned for voice-typed replies
  - `my-grill-me`, `my-grill-with-docs` — wrappers routing to `/my-grilling`
- `my-*` skills are deliberately absent from the router (`ask-matt` is upstream-owned) and from the top-level `README.md` / `plugin.json` (promoted skills only). Invoke them by name.
- `scripts/link-skills.sh` and `scripts/link-opencode-commands.sh` glob the whole repo, so new fork-owned skills are linked everywhere (Claude, `~/.agents`, Cursor, OpenCode) by `scripts/update-skills.sh` with no extra wiring.
