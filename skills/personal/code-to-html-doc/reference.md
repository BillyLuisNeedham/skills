# Reference — code-to-html-doc

Detailed material the agent reads only when building the doc. The CSS design
system lives in `template.html`; this file covers the section table, the diagram
decision tree, reusable inline-SVG patterns, and the sub-agent prompt.

## Full section table

Include relevant rows; skip what the source lacks.

| Section | Format | Diagram? |
|---|---|---|
| Title + subtitle + meta badges (id, branch, status, merge target) | header | No |
| Table of contents | `<nav class="toc">` anchor links | No |
| Overview | 1–2 paragraphs + responsibilities list | No |
| Glossary | `<dl>` definition list | No |
| Epic / ticket placement | table | No |
| Architecture / module map | short prose + one SVG | **Yes** if branching |
| Entry points / callers | table(s), split by contract if needed | No |
| Result / event propagation | table + one SVG | **Yes** if fan-out |
| Internal data flow / state machine | `<pre>` ASCII or numbered list | No |
| Work-item → capability mapping | table | No |
| In / out of scope | two-column table | No |
| Legacy / reference parity | table | No |
| Verification commands | `<code>` in list | No |
| Mental model Q&A | `.qa-item` cards | No |
| Footer | muted centered line | No |

## Diagram decision tree

```
Is the relationship branching or directional (fan-in / fan-out / layered)?
├── No  → table, <dl>, numbered list, or <pre>. STOP.
└── Yes → Does a table already make it obvious?
          ├── Yes → table. STOP.
          └── No  → draw ONE inline-SVG diagram. Budget across whole doc: max 2.
```

Never diagram: ticket lists, glossaries, scope tables, key/value pairs, linear
sequences, footer state machines. A clear table beats a cramped diagram.

## Inline-SVG patterns

Hand-author SVG — no Mermaid, no CDN. Reuse the `.node`, `.edge`, `arrow` marker
defined in `template.html`. Two patterns cover almost everything.

### Pattern A — vertical layered stack

Already in `template.html` (`#architecture`). Boxes stacked top→bottom, each
edge from bottom of one to top of next. Tag the entry node `class="node key"`.
Rules: box height 40, vertical gap 30, edge `y1 = box.bottom`, `y2 = next.top − 2`.

### Pattern B — fan-out propagation (one source → many consumers)

```html
<div class="diagram">
  <svg viewBox="0 0 420 220" role="img" aria-label="Result propagation">
    <defs>
      <marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4"
              orient="auto" markerUnits="userSpaceOnUse">
        <path d="M0,0 L8,4 L0,8 Z" fill="#5c6370"></path>
      </marker>
    </defs>
    <rect class="node key" x="20" y="90" width="140" height="40" rx="6"></rect>
    <text class="node-label" x="90" y="115" text-anchor="middle">Source / contract</text>

    <rect class="node" x="260" y="20"  width="140" height="40" rx="6"></rect>
    <text class="node-label" x="330" y="45"  text-anchor="middle">Consumer 1</text>
    <rect class="node" x="260" y="90"  width="140" height="40" rx="6"></rect>
    <text class="node-label" x="330" y="115" text-anchor="middle">Consumer 2</text>
    <rect class="node" x="260" y="160" width="140" height="40" rx="6"></rect>
    <text class="node-label" x="330" y="185" text-anchor="middle">Consumer 3</text>

    <path class="edge" d="M160,110 C210,110 210,40  258,40"  marker-end="url(#arrow)"></path>
    <path class="edge" d="M160,110 L258,110"                  marker-end="url(#arrow)"></path>
    <path class="edge" d="M160,110 C210,110 210,180 258,180" marker-end="url(#arrow)"></path>
  </svg>
  <div class="caption">Source fans out to its consumers.</div>
</div>
```

### SVG authoring rules

- Set `viewBox` to roughly `width × height` of content; box width ~140–160.
- Center labels: `text-anchor="middle"`, `x` = box center, `y` = box top + 25.
- Keep labels short (≤ ~22 chars); wrap long ones into two `<text>` lines.
- Edges: straight `<line>` for vertical stacks; cubic `<path>` curves for fan-out.
- Always end edges with `marker-end="url(#arrow)"`.
- Colours come from CSS classes only — don't hard-code hex in shapes (the marker
  fill is the one exception, since `<marker>` can't inherit `currentColor` reliably).

## Sub-agent prompt template

When delegating the build to a `Task` sub-agent (long source / many sections),
paste a prompt like this — the sub-agent has none of this chat's context:

> Create one self-contained HTML file at `{path}`. Use this exact CSS design
> system and structure: {paste template.html}. Content to render: {paste the
> source bullets / zoom-out / walkthrough}. Rules: embedded CSS only, no external
> CDN or web fonts; inline-SVG diagrams only; **max 2 diagrams**, and only for
> branching relationships (architecture stack, result fan-out) — use tables /
> `<pre>` for everything else. Sections to include: {list relevant rows from the
> section table}. Footer: "Personal reference — {topic}". Redact any secrets,
> keys, or PII. Output the file only; report the absolute path when done.

For very large inputs, split: one sub-agent drafts the prose/tables, a second
authors the SVG diagrams from the architecture description, then merge.

## Verification

After writing, sanity-check:
- File is valid HTML5, `lang="en"`, single file, no external `href`/`src`.
- Diagram count ≤ 2 and each is genuinely branching.
- Open it: `open "/absolute/path/to/file.html"` — layout centered, SVG renders,
  arrows visible, tables zebra-striped.
