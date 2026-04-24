---
name: structural-vocabulary-extended
kind: practice
domain: Structural vocabulary
description: Coordination, data flow, and lifecycle patterns — loaded on demand alongside the core vocabulary
loaded_by: [plan, review]
---

# Structural Vocabulary — Extended

Coordination, data flow, and lifecycle patterns. Loaded on demand alongside
`structural-vocabulary.md`. For an overview of the full system see
`structural-vocabulary-README.md`.

Every entry has a concrete example from unpossible's own design. The same format
applies as in the core file: Name, Shape, Reach for it when, Gotchas, Example.

## Coordination Patterns

How components work together over time — the shape of interactions between pieces,
not the pieces themselves.

### Fire-and-Forget
(OOP: async dispatch · FP: effect without continuation)

Shape: A caller dispatches work and returns immediately without waiting for a result.
The caller has no way to observe success or failure of the dispatched work.

Reach for it when: The work is best-effort and the caller's flow must not be slowed
by it. Logging, metrics, and audit events are canonical examples.

Gotchas: "Fire-and-forget" is not the same as "doesn't matter." The work still needs
to happen — it just happens asynchronously. If the work is actually important, you
need a buffered queue (so nothing is lost) or a result branch (so failures are
observable). Silently dropping events on queue overflow is a silent swallow.

Example: `POST /capture` returns 202 immediately. The analytics ingest queue handles
the write asynchronously. The caller never knows if the event was stored.

### Buffered Queue
(OOP: producer-consumer · FP: channel with backpressure)

Shape: A producer enqueues work into an in-memory or durable buffer. A consumer
drains the buffer in batches, decoupling the production rate from the consumption
rate.

Reach for it when: A producer generates work faster than a consumer can process it,
or when you want to absorb bursts without blocking the producer. Batch writes to a
database are the canonical use case.

Gotchas: In-memory queues lose their contents on process death — if durability
matters, use a durable queue (database-backed, Redis, etc.). Unbounded queues can
exhaust memory under sustained load; set a max size and decide what happens when
it's full (drop, block, or spill to disk). The flush trigger (time-based vs
size-based) affects both latency and throughput — tune for your use case.

Example: Analytics ingest buffers events in memory and flushes every 5 seconds or
100 events, whichever comes first. The Rails app never waits for a Postgres write.

### Idempotent Receiver
(OOP: dedup key · FP: memoization with side effects)

Shape: An operation that can be called multiple times with the same input and
produces the same result as if called once. The receiver detects duplicate calls
and returns the cached result without re-executing.

Reach for it when: A caller may retry on failure, and re-executing the operation
would cause duplicate side effects (duplicate charges, duplicate records, duplicate
LLM calls). The dedup key is derived from the input, not assigned by the caller.

Gotchas: The dedup window matters — a key that expires too quickly allows duplicates;
one that never expires accumulates forever. The dedup check must be atomic with the
operation it guards, or a race condition allows two concurrent calls to both pass the
check. Content-derived keys (hashes of the input) are more reliable than
caller-assigned IDs, but require stable serialization.

Example: Before calling the LLM provider, the agent runner computes `prompt_sha256`
and checks for a recent successful run with the same hash. A hit returns the cached
AgentRun — no provider call made.

### Competing Consumers
(OOP: worker pool · FP: parallel map with bounded concurrency)

Shape: Multiple consumers pull work from a shared queue. Each unit of work is
processed by exactly one consumer. Consumers are interchangeable — the queue doesn't
care which one picks up a given item.

Reach for it when: You have more work than one consumer can handle and the work is
parallelizable. The queue provides natural load balancing.

Gotchas: Work items must be independent — if two items share state, concurrent
processing causes races. Exactly-once delivery is hard; most queues provide
at-least-once, so consumers must be idempotent (see Idempotent Receiver). Concurrency
limits (max N consumers for a given work type) prevent a burst from overwhelming
downstream dependencies.

Example: solid_queue concurrency key on `source_ref` ensures only one active agent
run per actor at a time. A second run request while one is active returns 409.

### Circuit Breaker

Shape: A proxy that tracks failure rate for a downstream dependency. When failures
exceed a threshold, the breaker opens and subsequent calls fail immediately without
attempting the dependency. After a cooldown, the breaker half-opens and allows a
probe call through. If the probe succeeds, the breaker closes.

Reach for it when: A downstream dependency is unreliable and you want to fail fast
rather than accumulating timeouts. Prevents a slow dependency from exhausting your
thread pool or budget.

Gotchas: The threshold and cooldown must be tuned per dependency — too sensitive and
the breaker trips on normal variance; too lenient and it doesn't protect you. A
half-open breaker that lets through too many probes can re-overwhelm a recovering
service. Circuit breakers add state — that state must be shared across all instances
if you're running multiple processes.

Example: An LLM gateway that has failed 5 times in 60 seconds opens the breaker.
Subsequent calls return a retryable error immediately. After 30 seconds, one probe
call is allowed through.

### Supervisor
`status: proposed`

Shape: A process (or object) whose only job is to watch other processes and restart
them when they fail. The supervisor defines a restart strategy: restart only the
failed child, restart all children, or restart the failed child and everything
started after it.

Reach for it when: You have long-running workers that must stay alive despite
failures, and you want failure recovery to be declarative rather than scattered
across callers.

Gotchas: Supervisors that restart too aggressively can mask bugs — a process that
crashes immediately on restart will loop forever. Set a max restart rate (N restarts
in T seconds) and escalate if exceeded. Supervisors are most natural in
process-per-actor runtimes (Erlang/Elixir OTP); in thread-based runtimes (Ruby, Go),
the pattern is approximated with job queues and health checks.

Example: A supervision tree where each agent run is a child process. If a run
crashes, the supervisor restarts it from the last recorded turn. If it crashes 3
times in 60 seconds, the supervisor marks it failed and stops restarting.

## Data Flow Patterns

How information moves and transforms across a system — the shape of data in motion.

### Append-Only Log
(OOP: event log · FP: persistent sequence)

Shape: A sequence of records that can only be appended, never modified or deleted.
The current state of the system is derived by reading the log from the beginning
(or from a snapshot). Past records are immutable.

Reach for it when: You need an audit trail, a history of state transitions, or a
source of truth that can be replayed. The log is the primary artifact; derived views
are secondary.

Gotchas: Logs grow forever — define a retention policy before they become a storage
problem. Replaying a long log from the beginning is slow; snapshots checkpoint the
derived state so replay starts from a recent point. Schema changes are hard — you
can't alter past records, so new event types must be additive and old consumers must
handle unknown types gracefully.

Example: `LEDGER.jsonl` — one JSON object per line, append-only. Status transitions,
blocks, and spec changes are recorded as events. The reference graph is derived by
replaying the log. `AgentRunTurn` records follow the same shape — turns are appended,
never modified.

### Derived View
(OOP: computed property / read model · FP: fold / reduce)

Shape: A representation of data computed from a source of truth on demand, never
stored as primary state. The derived view is always reconstructable from the source.
If the source changes, the view is recomputed.

Reach for it when: Different consumers need different shapes of the same data, and
you don't want to maintain multiple copies in sync. The source is the authority; the
view is a convenience.

Gotchas: Expensive derivations that run on every read need caching — but cached
derived views introduce staleness. If the derivation is slow enough to need a cache,
consider whether it should be a materialized view (stored and updated incrementally)
instead. Derived views that reach back into the source for additional data on each
access are N+1 queries in disguise.

Example: The Go reference parser walks spec files, git history, and `LEDGER.jsonl`
on demand and produces a JSON graph. The graph is never stored — it's recomputed from
the source artifacts each time. The repo-map is the same shape: computed from AST
analysis of the codebase, token-budgeted, never persisted.

### Token Budget
(OOP: resource cap · FP: bounded fold)

Shape: A hard limit on the size of a resource (usually a context window or a
response) expressed in tokens. Content is selected, trimmed, or summarized to fit
within the budget. The budget is a first-class constraint, not an afterthought.

Reach for it when: You're assembling content for an LLM context window and must stay
within provider limits. Also applies to any resource with a hard size constraint
(memory, bandwidth, disk).

Gotchas: Token counting is approximate — different tokenizers produce different counts
for the same text. Budget for the worst case, not the average. Trimming strategies
matter: trimming from the end loses recent context; trimming from the middle loses
coherence; the Pinned + Sliding Window pattern (see Lifecycle Patterns) is a
principled approach for conversation history.

Example: The repo-map is generated with a token budget. If the full AST summary
exceeds the budget, lower-priority symbols are dropped. The agent runner applies a
token budget to turn history before each provider call.

### Event
(OOP: domain event · FP: message / signal)

Shape: An immutable record that something happened. Events are named in the past
tense, carry a payload describing what happened, and are produced by the thing that
experienced the change. Consumers react to events without the producer knowing who
they are.

Reach for it when: A state change in one part of the system should trigger reactions
in others, and you want the producer decoupled from the consumers. Events are the
data complement to the Observer pattern — Observer describes the wiring; Event
describes the data.

Gotchas: Event schemas are a public contract — once consumers depend on a field,
removing it is a breaking change. Version events explicitly if the schema will
evolve. Events that carry too much data couple producer and consumer tightly; events
that carry too little force consumers to query back for context (chatty consumers).
Find the payload size that lets consumers act without additional queries.

Example: `llm.run_completed` — fired by the agent runner with provider, model,
tokens, cost, mode, node_id, duration_ms. The analytics module consumes it. The
runner doesn't know analytics exists.

## Lifecycle Patterns

How things are born, transition, and die — the shape of objects over time.

### Ephemeral Worker
(OOP: transient object · FP: scoped effect)

Shape: A worker that is created for a single unit of work and destroyed when that
work is complete. No state persists between invocations. Each invocation starts from
a clean slate.

Reach for it when: You need isolation between work units — a failure in one should
not affect another. Also when the work requires a clean environment (no leftover
state from previous runs).

Gotchas: Ephemeral workers have higher startup cost than persistent workers — if
startup is expensive (container boot, JVM warmup), the overhead may dominate. Warm
pools (pre-started workers waiting for work) trade isolation for startup cost. Truly
ephemeral workers can't accumulate state — if you find yourself passing state between
invocations via an external store, the worker isn't really ephemeral.

Example: `docker run --rm` — each agent loop run gets a fresh container. The
container is destroyed on completion. No state leaks between runs.

### Tombstone
(OOP: soft delete · FP: marked-inactive record)

Shape: A record that has reached end-of-life is marked inactive rather than deleted.
The record is retained for audit, history, or reference integrity. Queries exclude
tombstoned records by default but can include them explicitly.

Reach for it when: You need to preserve history, maintain referential integrity, or
support audit requirements. Deleting records that other records reference causes
integrity violations; tombstoning avoids this.

Gotchas: Tombstoned records accumulate forever — define a hard-delete policy for
records old enough that history no longer matters. Queries that forget to filter
tombstoned records return stale data; make the filter the default, not the exception.
Tombstoning is not the same as archiving — an archived record may still be active;
a tombstoned record is permanently inactive.

Example: `FeatureFlag` with `status: archived` — the flag is never deleted;
`FeatureFlag.enabled?` returns false for archived flags without raising.
`AgentRunTurn` with `purged_at` set — the turn skeleton is retained for audit; only
the content is cleared.

### Pinned + Sliding Window

Shape: A sequence is divided into pinned items (always included, never trimmed) and
sliding items (trimmed from oldest first when the sequence exceeds a budget). The
pinned items represent load-bearing context that cannot be reconstructed; the sliding
items are recoverable.

Reach for it when: You have a sequence that must fit within a hard size limit, and
some items are more important than others. The key insight is that not all items are
equal — some must survive trimming.

Gotchas: The pinned set must be small enough that it doesn't consume the entire
budget on its own. If the pinned set grows unbounded, the sliding window disappears
and you're back to a hard limit with no flexibility. The definition of "pinned" must
be stable — if it changes between invocations, the trimming behavior becomes
unpredictable.

Example: Agent runner context window management — system prompt, all
`agent_question` and `human_input` turns are pinned (always included).
`llm_response` and `tool_result` turns are sliding (trimmed from oldest first). If
still over budget after trimming all sliding turns, abort with `RALPH_WAITING`.
