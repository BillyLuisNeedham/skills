---
name: code-to-html-doc
description: >-
  Turn a code walkthrough, zoom-out, feature explanation, or handoff into a
  single self-contained HTML reference doc with embedded CSS, tables, and
  selective inline-SVG diagrams (no external CDN, fully offline). Use when the
  user wants code or architecture turned into a digestible HTML page they can
  open in a browser, says "make this HTML", "html of this", "diagram this",
  "code to diagram", or wants a personal browser-openable map of a feature.
---

# Code to HTML doc

Produce **one self-contained `.html` file** that explains a piece of code,
feature, or architecture. Diagrams are **inline SVG only** — no CDN, opens
offline with `open file.html`.

## North star (the prompt this skill encodes)

> use sub agents to create a html of this. use diagrams where they bring value,
> do not use them where they don't. I want the information to be easy to digest
> and laid out well. this is for my use only

Every decision serves that line: **digestible**, **well laid out**, **diagrams
only where they earn their place**, **personal reference** (not marketing).

## Inputs

Whatever "this" is: a markdown zoom-out, a handoff doc, a feature explanation, a
ticket + caller list, pasted code, or a `git diff` summary. If working in a
repo, gather glossary/domain terms first so labels stay consistent. If no repo,
"sources provided in chat" is enough — never invent paths.

## Process

```
- [ ] 1. Extract glossary + section outline from the source material
- [ ] 2. Decide which (if any) topics deserve a diagram — see decision rule
- [ ] 3. Copy template.html, fill sections, keep prose tight
- [ ] 4. Draw diagrams as inline SVG (adapt patterns in reference.md)
- [ ] 5. Write the file; offer the open command
```

**Sub-agents:** for long source material (>~12 sections, huge caller lists, or
several diagrams), delegate the HTML build to a `Task` sub-agent — one per major
concern works well (e.g. one agent drafts section content, one authors the SVG
diagrams). Paste the section checklist + design constraints into each sub-agent
prompt; sub-agents do **not** see this chat. A prompt template is in
[reference.md](reference.md). A single agent is fine for small inputs.

## Diagram decision rule

Inline SVG diagrams are expensive to hand-author — use them only when they beat
a table. Default budget: **0–2 diagrams** per doc.

**Diagram it** when the relationship is **branching / directional**:
- architecture or layer stack (entry → screen → VM → domain → data)
- result / event propagation (one source fanning out to several consumers)

**Do NOT diagram** (use a table, `<dl>`, numbered list, or `<pre>`):
- ticket/issue lists, glossaries, scope (in/out), legacy parity
- linear sequences or state machines → `<pre>` ASCII or ordered list
- anything that is really just key/value or a flat list

If unsure, table it. A clear table always beats a cramped diagram.

## Section checklist

Include the relevant rows (skip what the source lacks). Full table + formats in
[reference.md](reference.md).

| Section | Format |
|---|---|
| Title + subtitle + meta badges | header |
| Table of contents | `<nav class="toc">` anchor links |
| Overview | 1–2 paragraphs + responsibilities list |
| Glossary | `<dl>` definition list |
| Architecture / module map | short prose + **one** SVG (if branching) |
| Entry points / callers | table(s) |
| Result / event propagation | table + **one** SVG (if fan-out) |
| Internal data flow / state | `<pre>` or numbered list — **no** diagram |
| Work-item → capability mapping | table |
| In / out of scope | two-column table |
| Verification commands | `<code>` in list |
| Mental model Q&A | `.qa-item` cards |
| Footer | muted line, e.g. "Personal reference — {topic}" |

## Design system

All styling lives in `<style>` in the template — never link external CSS.
Use [template.html](template.html) as the skeleton: centered ~52rem column,
light-gray page / white surfaces, green accent, system-ui type, standardized
`.badge`, `.callout`, `.diagram`, `.qa-item`, table, and `pre`/`code` components.
Adapt content; keep the CSS.

## Output

- Default filename: `<feature-slug>-doc.html` or `<ticket>-<topic>-doc.html`.
- Default location: `docs/` in a repo, else `~/Documents/`. Ask if ambiguous.
- Finish by giving the open command: `open "/absolute/path/to/file.html"`.

## Anti-patterns

- A diagram in every section, or any diagram for a flat list → table it.
- Mermaid / external CDN / web fonts → breaks offline; use inline SVG + system-ui.
- Walls of prose → prefer tables and short cards.
- Multi-file output, JS frameworks, print/PDF export → out of scope.
- Pasting raw `git diff` or full specs → summarise; link/name sources instead.
- Leaking secrets, API keys, PII → redact.
