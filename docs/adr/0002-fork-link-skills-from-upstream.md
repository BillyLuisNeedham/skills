# Fork `scripts/link-skills.sh` from upstream

This fork's `link-skills.sh` has permanently diverged from `mattpocock/skills`, and we resolve the recurring merge conflict in favour of **our** version every sync.

Upstream's version scans only `skills/` and links into `~/.claude/skills` + `~/.agents/skills` as symlinks. Ours scans the **whole repo root** (so the `android-*` and `gcp-*` skill dirs that `update-skills.sh` drops at the top level get linked at all), links into `~/.claude/skills` + `~/.cursor/skills`, copies **real dirs** for Cursor (its slash-command picker won't follow symlinks), and prunes stale/deprecated/orphan entries.

Adopting upstream's would silently stop linking ~50 root-level android/gcp skills and drop Cursor support; we use `~/.cursor` and not `~/.agents`. So we keep ours.

## Consequences

- Every future `mattpocock` sync that touches `link-skills.sh` will re-conflict. Resolve it the same way: `git checkout --ours scripts/link-skills.sh`, then continue the merge.
- We forgo upstream improvements to that file (e.g. the `~/.agents/skills` destination). If we ever adopt a pi / Agent-Skills-standard harness, graft that destination into our version rather than taking upstream's wholesale.
