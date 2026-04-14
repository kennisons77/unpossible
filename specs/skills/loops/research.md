---
name: research
kind: loop
command: ./loop.sh research <feature-id>
description: Deepen a spec through interview and source collection
actor: default
runs: once per invocation — re-run to append a second pass
principles: [planning, cost]
---

Run a research pass on a spike node. Each invocation is one pass.

## Each Pass

1. Read the spike node from `IDEAS.md` and any existing research log at
   `specs/research/{feature}.md`. Query the knowledge base for related research
   (`ContextRetriever#retrieve` scoped to `specs/research/`) — surface any prior
   findings relevant to this topic before asking the human anything.
2. Run `interview` — focused questions on scope, edge cases, failure modes, prior art.
   Pause with `RALPH_WAITING` for answers before proceeding.
3. Run `research` — collect sources, write findings, back-reference the spec.
4. **Promote best practices** — for any finding with high confidence (a clear pattern,
   a library recommendation, a "always do X" rule), write it to the relevant platform
   spec under `specs/platform/{platform}/`. Mark uncertain findings as
   `status: deferred` — they are saved for later but not yet promoted to default
   practice. Low-confidence findings stay in the research log only.
5. Trigger knowledge indexing for the updated spec, research log, and any platform files written.
6. Output `RALPH_COMPLETE`.

## Acceptance Criteria

- Runs exactly 1 iteration and exits
- Pauses with `RALPH_WAITING` before writing anything
- Research log created or appended — never overwritten
- Spec gains `## Research` section with back-references
- Re-running appends a second dated section
- High-confidence findings written to `specs/platform/{platform}/` with source reference
- Deferred findings marked `status: deferred` in the platform file — not yet default practice
- Video sources stored as title + URL only — no content fetched

## Investigation → Resolution Workflow

When the problem isn't "what should we build?" but "what's broken in what we built?",
use a two-phase approach:

**Phase 1 — Investigation loop** (research variant):
- Scope: a running system, not external sources
- Goal: find what's broken and classify the failures
- Permissions: read logs, add temporary logging, exercise APIs — but do not fix
- Output: a findings document listing each failure with its category and location

**Phase 2 — Resolution loop** (targeted build):
- Input: the investigation findings
- Goal: fix one category of failure at a time
- Plan from the findings — don't re-investigate during the build

The separation matters because investigation and resolution have different failure
modes. Investigation that also fixes tends to fix symptoms instead of causes.
Resolution without investigation tends to fix the wrong thing. Keep them apart.
