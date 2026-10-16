# Steer with principle names

pclaude ships 24 principles as leaf files in [`pclaude-principles`](../pclaude-principles/SKILL.md). `/pclaude-poteto-mode` reads their index at the start of every run, applies the ones the task triggers, and names each applied principle in its reply along with the decision it changed.

You don't invoke principles. You use their names to steer. Each name points at a complete rule the agent has already read, so one phrase redirects the work more precisely than a paragraph of instructions.

## Steering in practice

Say the agent is about to bolt a new adapter onto three existing ones:

```text
use subtract before you add. delete the obsolete adapters first, then design what's left.
```

Say it claims success because the build passed:

```text
apply prove it works. run the real import flow and show me the written records.
```

Say two parallel attempts are about to write to the same branch:

```text
separate before serializing shared state. give each attempt its own worktree, no locks.
```

Each phrase lands because the rule behind it is specific. The agent still has to say, in its reply, which decision the rule changed. A principle citation with no decision behind it is the tell that it name-dropped instead of applying.

## The 24, briefly

The core principles decide how much to build and when to rethink the design:

- [Laziness Protocol](../pclaude-principles/laziness-protocol.md) prefers deletion and the smallest change that solves the problem.
- [Foundational Thinking](../pclaude-principles/foundational-thinking.md) chooses the core data structures before writing logic.
- [Redesign from First Principles](../pclaude-principles/redesign-from-first-principles.md) integrates a new requirement as if it had been there from day one.
- [Attack the Premise](../pclaude-principles/attack-the-premise.md) writes down the premise that two or more failed fixes shared and tests it directly before the next fix.
- [Subtract Before You Add](../pclaude-principles/subtract-before-you-add.md) removes dead weight before building on top of it.
- [Minimize Reader Load](../pclaude-principles/minimize-reader-load.md) collapses layers and hidden state a reader must hold in their head.
- [Outcome-Oriented Execution](../pclaude-principles/outcome-oriented-execution.md) converges rewrites on the target design instead of preserving throwaway compatibility states.
- [Experience First](../pclaude-principles/experience-first.md) chooses the user's result over implementation convenience.
- [Exhaust the Design Space](../pclaude-principles/exhaust-the-design-space.md) builds two or three competing prototypes when there's no precedent.
- [Build the Lever](../pclaude-principles/build-the-lever.md) builds the script that does or proves the work, so a reviewer can rerun it. When an agent keeps doing the same thing by hand, have it write the tool or skill it wishes it had. If a script can do a step the same way every time, use the script, and save agents for the judgment calls.

The architecture principles decide where state, validation, and compatibility live:

- [Model the Domain](../pclaude-principles/model-the-domain.md) encodes repeated rules in one structure, not scattered conditionals.
- [Boundary Discipline](../pclaude-principles/boundary-discipline.md) validates at the boundary and trusts internal types.
- [Type System Discipline](../pclaude-principles/type-system-discipline.md) makes illegal states unrepresentable.
- [Make Operations Idempotent](../pclaude-principles/make-operations-idempotent.md) converges retries on the same end state.
- [Migrate Callers Then Delete Legacy APIs](../pclaude-principles/migrate-callers-then-delete-legacy-apis.md) migrates and deletes in one wave.
- [Separate Before Serializing Shared State](../pclaude-principles/separate-before-serializing-shared-state.md) removes the sharing before adding coordination.

The verification principles define what counts as proof:

- [Prove It Works](../pclaude-principles/prove-it-works.md) verifies the real artifact, not a proxy.
- [Fix Root Causes](../pclaude-principles/fix-root-causes.md) reproduces and traces to the cause before changing code.
- [Sequence Work into Verifiable Units](../pclaude-principles/sequence-verifiable-units.md) ends each small unit in a check before starting the next.
- [Test Behavior, Not Implementation](../pclaude-principles/test-behavior-not-implementation.md) asserts what the code's users can observe, so a test fails when that behavior breaks and survives a change to the internals.
- [Explain the Number](../pclaude-principles/explain-the-number.md) names what limits a measured number and rules out that it measured something else, before anyone trusts or reports it. [`/pclaude-benchmark-checklist`](../pclaude-benchmark-checklist/SKILL.md) turns it into seven questions you answer from real runs.

The delegation principles keep parallel work sane:

- [Guard the Context Window](../pclaude-principles/guard-the-context-window.md) routes bulk reading to subagents and keeps findings in the main chat.
- [Never Block on the Human](../pclaude-principles/never-block-on-the-human.md) proceeds on reversible work and presents the result.

And one meta principle:

- [Encode Lessons in Structure](../pclaude-principles/encode-lessons-in-structure.md) turns advice you've repeated twice into a lint, check, or script. [`/pclaude-correct`](../pclaude-correct/SKILL.md) applies it to a whole repo, as shown in [Make it yours](./09-make-it-yours.md#fix-the-environment-with-pclaude-correct).

Don't memorize the list. Skim it now, then come back when you catch the agent doing something a name here would have prevented. That's how the vocabulary sticks.

Next: [Make it yours](./09-make-it-yours.md).
