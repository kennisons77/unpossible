---
name: structural-vocabulary-readme
kind: practice
domain: Structural vocabulary
description: Overview of the structural vocabulary system — what it is, how it's organized, and how to use it
loaded_by: human
---

# Structural Vocabulary — Overview

Human reference. Never loaded by agents. For the vocabulary itself, see
`structural-vocabulary.md` (core) and `structural-vocabulary-extended.md` (extended).

## What It Is

A shared index of named abstractions for describing the shape of code above the
implementation level. The analogy: proficient musicians talk about chord progressions,
not individual notes. A shared structural vocabulary lets human and agent describe what
code *does* at a level that's portable across paradigms and languages.

The vocabulary is not a rulebook. It's shorthand. When a plan says "extract a pure
transform," both human and agent know the structural properties that implies — no
further description needed.

Influences: Sandi Metz, Martin Fowler — practical pattern thinkers who prioritize
communicability over formalism.

## The Taxonomy

The vocabulary is organized into four levels. Each level describes a different aspect
of a design.

| Level | Question | File |
|---|---|---|
| **Object-level** | How are individual pieces shaped? | `structural-vocabulary.md` |
| **Coordination** | How do components work together over time? | `structural-vocabulary-extended.md` |
| **Data flow** | How does information move and transform? | `structural-vocabulary-extended.md` |
| **Lifecycle** | How are things born, transition, and die? | `structural-vocabulary-extended.md` |

Object-level patterns are the most frequently referenced — they're always loaded by
plan and review agents. Coordination, data flow, and lifecycle patterns are loaded on
demand.

## How to Decompose a Design

To describe a design using the vocabulary:

1. Identify the components — what are the distinct pieces?
2. For each component, ask which level it operates at
3. Name the pattern(s) that describe its shape

**Worked example — the Agent Runner:**

| Component | Level | Pattern |
|---|---|---|
| Assembly pipeline (skill → context → principles → prompt) | Object | Pipeline |
| Provider adapter (`build_prompt`, `parse_response`, `max_context_tokens`) | Object | Interchangeable Implementation |
| Prompt dedup via `prompt_sha256` | Coordination | Idempotent Receiver |
| Pause on agent question, resume on human input | Object | State Machine |
| `POST /capture` analytics fire-and-forget | Coordination | Fire-and-Forget |
| Turn content GC (`purged_at`) | Lifecycle | Tombstone |
| Context window trimming (pinned turns vs sliding turns) | Lifecycle | Pinned + Sliding Window |
| `AgentRunTurn` records — appended, never modified | Data flow | Append-Only Log |

The output of a decomposition is a list like this — not a diagram, not a document.
Short enough to fit in a plan comment or a review note.

## The Two Files

**`structural-vocabulary.md`** — object and function-level patterns. Always loaded by
plan and review agents. Keep this file focused; it's in every agent's context window.

**`structural-vocabulary-extended.md`** — coordination, data flow, and lifecycle
patterns. Loaded on demand. Patterns here are drawn from unpossible's own design —
every entry has a concrete example from the codebase.

## Pattern Lifecycle

Each entry has a status tracking how battle-tested it is.

| Status | Meaning |
|---|---|
| `proposed` | Noticed during work, named and defined, not yet used in a real cycle |
| `adopted` | Used in at least one plan or review cycle and held up |
| `merged` | Absorbed into another pattern — entry kept with a pointer to the new home |
| `split` | Broken into more specific patterns — entry kept with pointers to the children |
| `retired` | Removed from active use — entry kept with a note on why |

All entries are `adopted` unless marked otherwise.

Retired, merged, and split entries stay in their file with status and a note. This
prevents re-proposing something already tried, and gives agents context when they
encounter references to old pattern names in committed code.

## Process for Changes

### Proposing a New Pattern

Either human or agent can propose. During planning or review, if a recurring structural
concept doesn't have a name in this vocabulary:

1. Name it
2. Write the shape, reach-for-it-when, and a terse example
3. Add it with `status: proposed` to the appropriate file
4. Use it in the current cycle

### Adopting

After a proposed pattern has been used in at least one real plan or review cycle and
both human and agent found it useful, change status to `adopted`.

### Altering

If a pattern's definition needs refinement based on use, update it in place. The
commit message should note what changed and why.

### Merging / Splitting

If two patterns turn out to describe the same thing, merge them: keep both entries,
mark one `merged`, and point it at the survivor. If a pattern is too broad, split it:
mark the original `split` and point it at the children.

### Retiring

If a pattern isn't pulling its weight — confusing, redundant, or never referenced —
mark it `retired` with a one-line reason. Don't delete it.

### Agent Responsibility

When an agent encounters a pattern reference in code or a plan that points to a
`merged`, `split`, or `retired` entry, it should update the reference to the current
pattern name as part of the work it's already doing. This is housekeeping, not a
separate task.
