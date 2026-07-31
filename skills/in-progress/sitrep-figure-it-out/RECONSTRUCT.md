# Reconstructing the situation from the record

You are the first of two agents. Your job is to read the session transcript and turn it into a **brief** — an account of where the work stands. A second agent then turns your brief into the HTML page.

The split matters: mining a transcript fills your context with raw conversation, which is poor conditions for designing a page. Hand off a clean brief and let the second agent start fresh.

## The record

The transcript is JSONL — one JSON object per line, appended live, so the last lines are the most recent moments of a conversation still in progress. It can run to hundreds of kilobytes. Pull from it with `jq`; reading it whole would cost you the context this design exists to save.

The lines you want:

- `.type == "user"` with `.message.content` a **string** — a real human turn. This is the user speaking in their own words, and it is the highest-signal content in the file.
- `.type == "user"` with `.message.content` an **array** — tool results, not the human.
- `.type == "assistant"` — `.message.content` is an array of typed blocks: `text` (what the agent said aloud), `thinking` (its reasoning), `tool_use` (what it did).
- `.isSidechain == true` — subagent traffic. Skip it unless you're chasing a specific finding.

Four recipes, cheapest and highest-signal first:

```bash
# 1. Every human turn — the mission, the corrections, the priorities
jq -r 'select(.type=="user" and (.message.content|type=="string"))
       | "--- \(.timestamp)\n\(.message.content)"' "$F"

# 2. Files written or edited — the surface the work touched
jq -r 'select(.type=="assistant") | .message.content[]?
       | select(.type=="tool_use" and (.name=="Write" or .name=="Edit"))
       | .input.file_path' "$F" | sort -u

# 3. The action trail — what was actually done, in order
jq -r 'select(.type=="assistant") | .message.content[]?
       | select(.type=="tool_use")
       | "\(.name): \((.input.description // .input.file_path // .input.command // .input.prompt // "") | tostring | .[0:160])"' "$F"

# 4. What the agent said aloud — its account of the work
jq -r 'select(.type=="assistant") | .message.content[]?
       | select(.type=="text") | .text' "$F"
```

Reach for `thinking` blocks only when a decision's reasoning is missing everywhere else — they are long, and much of what matters in them resurfaces in the spoken text.

## Order of work

1. **Recipe 1 first.** The opening human turn usually states the mission; later ones carry the corrections, reversals and priorities that testimony tends to smooth over. Read them all — there are rarely many.
2. **Recipe 2**, to see which files are in play.
3. **Recipe 4, weighted to the tail.** The most recent turns tell you where things actually stand.
4. **Recipe 3**, to check that what was said matches what was done.
5. **Read the files themselves.** The transcript says what was intended; the repo says what exists. Run `git status` and `git diff --stat`, and open the files from recipe 2.

You are done when you can state the mission, the current position, and the next move without hedging — or can name precisely which of the three the record leaves ambiguous.

## Write the brief

Cover:

- **The mission** — what's being solved, and why. Quote the user's own framing where they gave one.
- **The position** — what exists now, what's in flight, what's untouched.
- **The decisions** — what was chosen, the reasoning, and any option explicitly rejected. Reversals and user corrections are the most valuable thing in a transcript; carry them forward.
- **The open ground** — unresolved questions, blockers, deliberately parked items.
- **The pointers** — paths to files, commands, tests and errors that matter, so the second agent can verify rather than take your word.

You are reading a record, not remembering an intent. Where you inferred something rather than read it, mark it as inference. Where the transcript is genuinely ambiguous about the current state, say so plainly instead of smoothing it into a confident account — a flagged gap is useful, a confident guess is a trap.

## Hand off

Dispatch **one** `general-purpose` subagent and wait for it — run it in the foreground, so you can relay its result. Its prompt:

> Read `<absolute path to ../sitrep/REPORT.md, resolved from this skill's directory>` first and follow it. Everything below is your brief.

…followed by your brief. That guide is shared with the `sitrep` skill on purpose: both skills build the page the same way, so the only thing that differs between them is how the brief was obtained.

If you cannot spawn a subagent, read `REPORT.md` and build the page yourself.

Your final message is the absolute path to the page, plus a few sentences on what the sitrep says and anything the record left ambiguous.
