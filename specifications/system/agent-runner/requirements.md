---
name: agent-runner
kind: requirements
status: draft
description: AgentRun schema, turn recording, provider adapter interface, cost tracking
modules: [agents]
---

# Requirements: Agent Runner

## Intent

The Agent Runner executes beats from the implementation plan against LLM providers. It assembles
prompts, manages multi-turn conversations including human input pauses, records results,
and deduplicates repeated calls. There is no sidecar — provider calls are made directly
from Rails via HTTP.

## Personas

- **Loop:** needs to execute a beat and get a result back without managing provider
  details
- **Human:** needs to answer agent questions from the UI or CLI without blocking the
  loop for other work
- **System:** needs a complete audit trail of every LLM call — tokens, cost, duration,
  which context was loaded
- **Reflect loop:** needs to query execution history to find patterns in cost and errors

## User Scenarios

**Scenario 1 — Normal beat execution:**
The build loop picks an open beat from `IMPLEMENTATION_PLAN.md`. The runner assembles the instruction + context +
principles into a prompt, calls the provider, and records the result.

**Scenario 2 — Dedup hit:**
The same beat is submitted with identical context within 24 hours. The runner returns
the cached AgentRun without making a provider call.

**Scenario 3 — Agent pauses for human input:**
Mid-run, the agent determines it needs clarification. It writes a question as a turn,
sets status to `waiting_for_input`, and suspends. The human sees the question in the UI
or CLI, submits an answer via `POST /runs/:id/input`. The run re-enqueues and resumes
with the answer injected as a user message into the next provider call.

**Scenario 4 — Multiple pauses:**
A run pauses and resumes several times across a long-running task. Each pause/resume
cycle appends turns to the run's turn history. The full turn history is passed as
context on each provider call.

**Scenario 5 — Token limit exceeded:**
The assembled prompt exceeds the provider's context limit. The runner aborts with
`RALPH_WAITING` before making any provider call.

**Scenario 6 — Concurrent run attempt:**
A second run is enqueued while one is active for the same actor. solid_queue concurrency
limits reject it with a 409.

## Functional Requirements

**MVP:**
- Assemble prompt from: skill body + context chunks + principles files
- Check `prompt_sha256` dedup before calling provider — return cached run if hit
- Call provider HTTP API directly (no sidecar)
- Support pause/resume with human input injected as user message turns
- Multiple pause/resume cycles per run
- Resume via `POST /runs/:id/input` — same endpoint for UI and CLI
- Record AgentRun with tokens, cost, duration, status, source node IDs
- Record each turn in AgentRunTurn (agent questions, human inputs, LLM calls, tool results)
- Abort with `RALPH_WAITING` if prompt exceeds provider token limit
- Link subagent runs to parent via `parent_run_id`
- Concurrency: one active run per actor via solid_queue concurrency key

**Post-MVP:**
- Streaming output
- Multi-provider fallback
- Resume timeout / expiry

## Specs

| Spec file | Description |
|---|---|
| [`concept.md`](concept.md) | AgentRun schema, turn model, assembly pipeline, dedup, provider adapter interface |
