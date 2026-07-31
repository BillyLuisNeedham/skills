# Building the sitrep

You are writing a **sitrep** — a situation report on work in flight. Its reader is the person doing that work, who wants to look at one page and see exactly where they stand.

Accuracy is the point. Take the time the report needs.

## Establish ground truth

The brief is one agent's account of the work, written from memory. Before you write a word of the page, go and check it.

- Read every file the brief names, and follow the references you find in them.
- Run `git status` and `git diff --stat` to see what has actually changed on disk.
- Run the tests, build, or type-check the brief mentions, if running them is cheap and safe.
- Chase anything the brief asserts but does not evidence.

Where the repo and the brief disagree, the repo is right — say so on the page, and show what's actually true. Where the brief left a gap you can fill by reading, fill it.

You are done establishing ground truth when every claim on the page traces back to something you read or ran, or is marked as the brief's account rather than verified fact.

## Let the form fit the situation

There is no template. Pick the shapes that carry *this* situation, and let a different sitrep look completely different.

- **Mermaid diagram** — when the thing has structure or moving parts. A `flowchart` for architecture and data flow, a `sequenceDiagram` for a request path or protocol, a `stateDiagram` for a machine, a `gitGraph` for branch state.
- **Table** — when items are being tracked or compared: files changed, options weighed against criteria, tests passing and failing, endpoints done and outstanding.
- **Annotated code block** — when the situation lives in a specific function or config, and seeing it beats describing it. Quote the real lines, with the file path and line numbers as the heading.
- **Checklist with a marked position** — when the work is a sequence and the useful fact is how far along it is.
- **Callout** — for the blocker, the open question, the thing that will bite next.
- **Prose** — when the situation is a narrative, and the reasoning is the substance.

Every element earns its place by carrying information the reader would otherwise have to reconstruct. Reach for the shape that makes the fact land fastest; a page of three well-chosen elements beats a page of nine dutiful ones.

## What the page answers

However you arrange it, a reader must come away with three things:

1. **The mission** — what we're solving, and why it matters.
2. **The situation** — what is true right now. What's built, what's broken, what's decided, what's still open.
3. **The next move** — what happens next, and what it depends on.

Open with a short orienting summary so the reader gets the shape of it before the detail.

## The page itself

A single self-contained HTML file.

- **Tailwind via CDN** for layout and typography, **Mermaid via CDN** for diagrams. Initialise Mermaid after the DOM loads.
- Comfortable reading measure, generous spacing, a clear heading hierarchy, syntax-styled code blocks. Something the reader is happy to look at.
- Wide content — tables, diagrams, code — scrolls inside its own container so the page body never scrolls sideways.
- Title the page with the mission and a timestamp.

## Write it and open it

Resolve the temp directory from `$TMPDIR`, falling back to `/tmp`. Write to `<tmpdir>/sitrep-<YYYYMMDD-HHMMSS>.html`, so every run leaves a fresh file and two sitreps can be compared.

Then open it for the user, handling both platforms:

```bash
command -v xdg-open >/dev/null && xdg-open "$FILE" || open "$FILE"
```

Your final message is the absolute path, plus two or three sentences on what the sitrep says and anything you found that contradicted the brief.
