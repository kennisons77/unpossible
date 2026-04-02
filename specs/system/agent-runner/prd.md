# PRD: Agent Runner

- **Status:** Draft
- **Created:** 2026-04-01
- **Last revised:** 2026-04-01

## Intent

The Agent Runner is the execution bridge between a beat in the ledger and a provider
call. It assembles instructions into provider-specific prompts, calls the Go sidecar,
records the result, and deduplicates repeated calls.

## Personas

- **Loop:** needs to execute a beat and get a result back without managing provider
  details
- **System:** needs a complete audit trail of every LLM call — tokens, cost, duration,
  which knowledge was loaded
- **Reflect loop:** needs to query execution history to find patterns in cost and errors

## User Scenarios

**Scenario 1 — Normal beat execution:**
The build loop picks an open beat. The runner assembles the instruction + context +
principles into a prompt, checks dedup, calls the sidecar, records the result, and posts
the answer node back to the ledger.

**Scenario 2 — Dedup hit:**
The same beat is submitted twice within 24 hours with identical context. The runner
returns the cached AgentRun without calling the sidecar.

**Scenario 3 — Token limit exceeded:**
The assembled prompt exceeds the provider's safe limit. The runner aborts with
`RALPH_WAITING` before making any provider call.

## Functional Requirements

**MVP:**
- Assemble instruction from: skill body + context chunks + principles files
- Check `prompt_sha256` dedup before calling sidecar — return cached run if hit
- Call Go sidecar with assembled prompt and ActorProfile config
- Record AgentRun with tokens, cost, duration, exit code, source node IDs
- Abort with `RALPH_WAITING` if prompt exceeds provider token limit
- Link subagent runs to parent via `parent_run_id`

**Post-MVP:**
- Streaming output
- Multi-provider fallback

## Specs

| Spec file | Description |
|---|---|
| [`spec.md`](spec.md) | AgentRun schema, assembly pipeline, dedup, adapter interface |
