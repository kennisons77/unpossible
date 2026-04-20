# 0001 — Replace ledger with reference graph; rename spec hierarchy

**Status:** accepted
**Date:** 2026-04-18

## Context

The Postgres-backed ledger module introduced a sync problem: files on disk and rows in
the database had to agree, requiring SpecWatcherJob, PlanFileSyncService, conflict
detection, and stable_ref hashing. The complexity was not justified by the value
delivered. The question/answer mental model was sound, but the storage layer should be
files and git, not a parallel database.

Separately, the terminology was causing collisions: "spec" referred to both the broad
behavioral definition and RSpec test files. "PRD" was positioned as the first artifact
in the chain, but conceptually the broad plan should precede the precise technical
translation.

## Decision

1. **Replace ledger with reference graph.** All project state lives in files and git.
   Postgres is retained only for operational metrics (AgentRun, analytics). The
   reference graph parser derives relationships from files at query time.

2. **Delete superseded specs.** Ledger and knowledge module specs are removed from the
   tree. `spec_removed` events are appended to LEDGER.jsonl before deletion. Git
   history preserves the full content.

3. **Rename the artifact hierarchy:**
   - `pitch` → `brief` (ideology level)
   - `spec.md` → `concept.md` (concept level — broad behavioral definition)
   - `prd.md` → `requirements.md` (specification level — precise technical translation)
   - `specs/` directory → `specifications/`
   - `make prd` → `make requirements`
   - `make spec` → `make concept`

4. **New chain:** `interview → concept → requirements → plan → build → review`

## Consequences

- All file references across the project updated (specifications/, concept.md,
  requirements.md).
- Agent configs, PROMPT files, Makefile, loop.sh, validate-refs.sh updated.
- Ruby test files with source_ref strings updated.
- The plan loop no longer encounters dead specs when scanning specifications/.
- Future superseded specs follow the same pattern: append spec_removed to LEDGER.jsonl,
  write a decision record, delete the files.
