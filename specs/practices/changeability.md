# Changeability

Code that is easy to change for both humans and LLMs. Loaded by plan and review loops;
build loop loads on demand.

## Guiding Principle

Shared understanding is the goal. Code should be navigable by a human with an IDE,
an LLM reading files linearly, or a new team member on day one. If any of those three
can't figure out what a module does and why it exists without asking someone, the code
is too hard to change.

## LOOKUP.md Convention

Every module directory gets a `LOOKUP.md` that maps its contents:
- Purpose (one sentence)
- Public interface (classes/methods that other modules may call)
- Cross-module rules (what's off-limits)

LOOKUP files describe boundaries and interfaces, not implementation. They change when
the boundary changes, not on every commit. They are the cheapest form of documentation
that LLMs actually use — a map at the top of each directory.

## Change Justification

Not every change needs a justification. Most changes are obvious from the diff. Record
the "why" only when it would be non-obvious to a future reader.

| Situation | Where to record | Example |
|---|---|---|
| Routine implementation | Git commit message | "Add Node#closed? predicate" |
| Non-obvious trade-off | Inline `# why:` comment | `# why: raw SQL here because AR .scope conflicts with column name` |
| Load-bearing decision | `specs/decisions/NNNN-title.md` | Choosing pgvector over Qdrant |
| Rejected alternative | Same decision record | "Considered X, rejected because Y" |

Rules:
- Commit messages are free — write good ones, but don't over-invest
- Inline `# why:` comments go at decision points only, not on every method
- Decision records are for choices you'll question in 3 months. If you won't, skip it
- Never duplicate justification across locations — pick one and reference it

## Decision Records

Lightweight ADRs in `specs/decisions/`. One file per decision, numbered sequentially.

```markdown
# NNNN — Title

**Status:** accepted | superseded by NNNN
**Date:** YYYY-MM-DD

## Context
What prompted the decision.

## Decision
What we chose.

## Consequences
What changes as a result. What gets easier. What gets harder.
```

Don't create these speculatively. Create them when you catch yourself explaining the
same decision twice, or when a review surfaces a "why did we do it this way?" question.

## Structural Rules for Small Blast Radius

Code that's easy to change is code where changing one thing doesn't break five others.

- One concept per file — a reader should know what a file does from its name
- Explicit module boundaries — cross-module calls go through public interfaces only
  (see LOOKUP.md). No reaching into another module's internals
- Flat over deep — prefer composition over inheritance. Deep class hierarchies and
  metaprogramming are hard for LLMs to follow and hard for humans to debug
- Fewer indirections — if understanding a call requires tracing through 4 layers of
  delegation, the abstraction isn't helping. Name things so the reader can stop drilling
- Small public interfaces — the fewer methods a module exposes, the less coupling exists
  and the safer it is to change internals
- No speculative generality — don't add extension points, config options, or abstractions
  for future needs. Add them when the need arrives. YAGNI is a changeability rule

## LLM-Specific Considerations

LLMs read code differently than humans. They don't use an IDE, can't jump to definition
on hover, and lose context across large files. What helps:

- Self-documenting names that encode domain intent (`TransitionService.call` not
  `Service.run`)
- LOOKUP.md files as entry points — an LLM reads these first to orient before diving
  into source files
- Consistent patterns — if every service follows the same shape, the LLM predicts
  correctly and makes fewer mistakes
- Avoid magic — `method_missing`, dynamic `define_method`, and convention-based loading
  (e.g. Rails' autoload magic) are invisible to an LLM reading a single file. When you
  must use them, add a `# why:` comment explaining what's happening
