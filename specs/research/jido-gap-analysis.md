# Research: Jido Gap Analysis

**Created:** 2026-04-17
**Source:** https://github.com/agentjido/jido (v2.2.0, Apache 2.0)

## What Jido Is

An autonomous agent framework for Elixir. It provides the runtime primitives for defining agents, routing signals between them, executing actions, and managing agent lifecycle — all built on OTP. AI is optional; the core is a deterministic workflow engine.

**Key distinction from Unpossible:** Jido is an *agent runtime* — it answers "how does a single agent process inputs and produce effects." Unpossible is an *agent platform* — it answers "how do we orchestrate loops, store their artifacts, and use evidence to improve over time." They operate at different layers. Jido would sit inside something like Unpossible, not replace it.

## Concepts Worth Knowing

### The cmd/2 Pattern (Elm/Redux in Elixir)

Jido's core operation: `{agent, directives} = MyAgent.cmd(agent, action)`. The agent struct is immutable. `cmd/2` is a pure function — same inputs, same outputs. It returns the new agent state *and* a list of directives (typed effect descriptions). The runtime interprets directives; the agent logic never performs side effects directly.

**Why it matters:** This makes agent logic testable without processes, effects inspectable as data, and the boundary between "thinking" and "acting" explicit. Unpossible's agent runner already has a version of this separation (the runner assembles prompts and records results; the provider adapter handles the actual LLM call), but it's implicit in the service layer rather than enforced by a type system.

**Gap?** Not really. Unpossible's single-threaded loop with explicit turn recording achieves the same testability. The cmd/2 pattern would add value if Unpossible needed to compose agent behaviors or run agents in-process — neither is on the roadmap.

### Directives as Data

Actions return directive structs (Emit, Spawn, SpawnAgent, Schedule, Stop, etc.) rather than performing side effects. The runtime decides when and how to execute them. This is an inversion of control — the agent says *what* should happen, the runtime decides *how*.

**Unpossible equivalent:** The skill frontmatter's `enrich` and `callable` tool declarations serve a similar purpose — the skill declares what it needs, the runner decides execution order. The difference is granularity: Jido's directives are per-action, Unpossible's are per-skill.

### Signal Routing

Signals are CloudEvents-compliant messages routed by pattern matching with priority layers (strategy routes > agent routes > plugin routes). Agents communicate exclusively through signals.

**Unpossible equivalent:** Solid Queue job dispatch + the `source_ref` concurrency key. Unpossible doesn't need signal routing yet because loops are sequential and single-agent. This becomes relevant if/when Unpossible runs multiple agents on the same project concurrently.

### Plugin Composition

Agents compose capabilities via plugins with isolated state namespaces, lifecycle hooks, and their own signal routes. Plugins are the unit of reuse.

**Unpossible equivalent:** Provider adapters + skill frontmatter. Unpossible's composition model is file-based (skills, practices, principles) rather than code-based. This is simpler and appropriate for the current phase.

## Gaps That Matter for Unpossible's Trajectory

### 1. Subagent Lifecycle Management

Jido has a formal parent-child hierarchy: parent spawns children via directives, tracks them with process monitors, and handles their death (stop, continue as orphan, or emit orphan signal). Children can be adopted by new parents.

Unpossible has `parent_run_id` on AgentRun and the recursive LLM calls research note, but no lifecycle management beyond that FK. When subagent dispatch becomes real, Unpossible will need:
- A way to cancel child runs when a parent fails
- A decision on what happens to orphaned runs
- Cost attribution up the parent chain

**Recommendation:** Not urgent, but when subagent dispatch ships, design the lifecycle model explicitly rather than discovering it through bugs. Jido's three death policies (stop, continue, emit_orphan) are a good vocabulary to borrow.

### 2. Structured Error Classification

Jido defines six error types: Validation, Execution, Routing, Timeout, Compensation, Internal. Each has different retry semantics and aggregation behavior.

Unpossible's agent runner has `status: failed` but no error taxonomy. As loops accumulate evidence, the reflect loop will need to distinguish "the LLM hallucinated" from "the provider timed out" from "the prompt was malformed." These have different remediation paths.

**Recommendation:** Worth adding to the AgentRun schema before the reflect loop ships. Even a simple enum (provider_error, prompt_error, tool_error, timeout, internal) would make reflect-loop analysis much more useful.

### 3. Completion via State, Not Process Death

Jido agents signal completion by setting terminal status in state. The process stays alive for result retrieval. This avoids the race condition where a consumer tries to read results from a process that's already gone.

Unpossible's Solid Queue jobs complete by updating the AgentRun record, which is the same idea implemented through the database rather than process state. No gap here — the DB-backed approach is actually more durable.

## Telecom Engineering Principles and the BEAM

This is the broader context for why Jido's patterns exist. The BEAM VM (Erlang's runtime, which Elixir compiles to) was designed at Ericsson in the late 1980s for telephone switches. The design requirements were: 99.999% uptime, hot code upgrades with no downtime, and graceful handling of hardware failures. These constraints produced a runtime model that's unusually well-suited to agent infrastructure.

### Let It Crash (Supervision)

The core insight: don't try to handle every possible error inline. Instead, let processes crash and have a supervisor restart them in a known-good state. This is the opposite of defensive programming — you write the happy path and let the supervision tree handle the rest.

A supervisor watches its children and applies a restart strategy:
- **one_for_one** — restart only the failed child
- **one_for_all** — restart all children (for tightly coupled groups)
- **rest_for_one** — restart the failed child and everything started after it

Supervisors are nested into trees. A crash propagates up only as far as needed. The top-level supervisor is the last line of defense.

**Why this matters for agents:** LLM calls fail unpredictably — timeouts, rate limits, malformed responses, provider outages. A supervision model means you don't need to anticipate every failure mode. You define "what does a clean restart look like" and let the runtime handle the rest. Unpossible's retry practices (`specs/practices/retry.md`) are the manual equivalent of this — explicit retry logic per failure type. A supervision model would make that declarative rather than imperative.

### Process Isolation

Every BEAM process has its own heap, its own garbage collector, and communicates only via message passing. A crash in one process cannot corrupt another's memory. There's no shared mutable state.

This is fundamentally different from Ruby threads (shared memory, GIL) or Go goroutines (shared memory, channels for coordination). BEAM processes are closer to OS processes in isolation but closer to threads in cost (~2KB initial memory, microsecond spawn time).

**Why this matters for agents:** Each agent can be its own process with its own state, and a misbehaving agent cannot take down the system. In Ruby, a runaway thread can corrupt shared state or exhaust the GIL. Unpossible sidesteps this by using Solid Queue (separate job processes), which provides similar isolation at higher overhead.

### Preemptive Scheduling

The BEAM scheduler preemptively switches between processes based on "reductions" (roughly, function calls). No process can monopolize a scheduler. This is why Erlang/Elixir systems stay responsive under load — a long-running computation doesn't block other work.

Most language runtimes use cooperative scheduling (Go, Ruby fibers, JavaScript async/await), where a task must yield voluntarily. If it doesn't, everything else waits.

**Why this matters for voice AI specifically:** Voice chat requires consistent low-latency response. Preemptive scheduling guarantees that audio processing isn't starved by a slow LLM response handler. This is why telecom systems used it and why it's relevant to the voice AI team you're considering.

### Hot Code Reloading

BEAM supports loading new code into a running system without stopping it. Two versions of a module can coexist — existing processes finish on the old version, new processes start on the new one. This was designed for telephone switches that couldn't go down for deployments.

**Relevance to agents:** Less directly applicable to Unpossible (Docker restarts are fine for Phase 0), but interesting for long-running agent processes that need behavior updates without losing state.

### Distribution

BEAM nodes can form clusters and send messages to processes on remote nodes transparently. A process doesn't need to know whether the process it's messaging is local or remote. This was designed for multi-rack telephone switches.

**Relevance to agents:** If you ever need to distribute agent work across machines, BEAM gives you this for free. In Ruby/Rails, you'd need an explicit message broker (Redis, RabbitMQ, or Solid Queue's database-backed approach).

## Key Takeaway

Jido is a well-designed agent runtime that leverages BEAM's strengths. But it solves a different problem than Unpossible. The useful things to take from it are:

1. **Vocabulary** — directives, death policies, error classification. These are good names for concepts Unpossible will need as it grows.
2. **Subagent lifecycle** — design this explicitly when the time comes, don't let it emerge accidentally.
3. **Error taxonomy** — add this to AgentRun before the reflect loop ships.
4. **Telecom principles** — "let it crash" supervision and process isolation are the BEAM's real contribution. They're worth understanding deeply for the voice AI work, even if Unpossible doesn't adopt Elixir.

Unpossible's simplicity (single-threaded loops, DB-backed state, file-based composition) is a strength at this phase, not a gap. Don't add Jido-style complexity until there's evidence it's needed.
