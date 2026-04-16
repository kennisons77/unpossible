# Structural Vocabulary

A shared index of named abstractions for describing the shape of code above the
implementation level. These are shortcuts — not gospel. They exist to accelerate
communication between human and agent during planning, review, and build.

Origin: the idea that proficient musicians talk about chord progressions, not
individual notes. A shared structural vocabulary lets us describe what code *does*
at a level that's portable across paradigms and languages.

Influences: Sandi Metz, Martin Fowler — practical pattern thinkers who prioritize
communicability over formalism.

## Goals

1. **Agent shorthand** — plan and review loops reference patterns by name instead of
   describing structure from scratch each time
2. **Human skill-building** — maintaining this vocabulary sharpens pattern recognition
   and the ability to articulate structural decisions to other humans
3. **Shared mental model** — when a plan says "extract a pure transform," both human
   and agent know the structural properties that implies

## How to Read an Entry

Each pattern has:
- **Name** — the shorthand we use in plans and reviews
- **Shape** — one sentence describing the structural properties
- **Reach for it when** — the situation where this pattern fits
- **Gotchas** — where the pattern breaks down or misleads
- **Example** — terse, generic, paradigm-neutral where possible

Some entries are families with sub-concepts (e.g., Dependency Graph → DAG, Workflow,
Graph). The family heading describes the shared idea; sub-entries describe the
specific shapes.

Entries are paradigm-neutral unless tagged otherwise. Where a concept has well-known
paradigm-specific names, those are noted in parentheses.

## Patterns

### Pure Transform
(OOP: value object · FP: pure function)

Shape: Takes input, produces output, no side effects, no state.

Reach for it when: You need a computation that's safe to call from anywhere, easy to
test, and trivial to reason about.

Gotchas: Purity is contagious upward — a function that calls an impure function is
itself impure. Watch for hidden state (time, randomness, ENV reads) sneaking in.
Also easy to over-apply: not everything needs to be pure, and forcing purity on
inherently stateful operations creates awkward workarounds.

Example: `Amount.new(cents, currency).to_formatted_string` — same input always
produces same output.

### Gateway
(OOP: adapter/wrapper · FP: effect boundary)

Shape: Boundary object that isolates your code from an external system. All
interaction with the external thing goes through the gateway.

Reach for it when: You're calling an API, database, filesystem, or any dependency
you don't control. The gateway translates between their interface and yours.

Gotchas: Gateways that leak the external system's abstractions defeat the purpose —
if callers need to know about HTTP status codes, the gateway isn't translating enough.
Conversely, over-abstracting a gateway makes it hard to use features specific to the
external system. Find the boundary that matches your actual usage, not a universal
wrapper.

Example: `LlmGateway.complete(prompt)` — wraps the provider's HTTP API. Internal
code never constructs HTTP requests directly.

### Pipeline
(OOP: chain of responsibility · FP: function composition)

Shape: A sequence of steps where each step's output feeds the next step's input.
Steps are independently testable and reorderable.

Reach for it when: You have a multi-step transformation and want to add, remove, or
reorder steps without rewriting the whole flow.

Gotchas: Pipelines assume each step has a uniform interface (same shape in, same
shape out). When a step needs context from two steps back, the pipeline abstraction
starts fighting you — you end up threading a growing context object through every
step, which is state soup in disguise. Also, error handling in the middle of a
pipeline is awkward; consider combining with result branch.

Invisible steps: Some pipelines include infrastructure steps that run between
visible steps but aren't part of the main flow's logic — audit logging, activity
tracking, lint checks. These should fail open (see coding.md § Error Handling).
If an invisible step starts affecting the pipeline's output or control flow, it's
no longer invisible — make it a named step or extract it.

Example: `input |> validate |> normalize |> enrich |> persist` — each step is a
pure transform or a gateway call.

### Result Branch
(OOP: result object · FP: Either/Maybe monad)

Shape: An operation that returns a value representing success or failure. The caller
branches on the result rather than catching exceptions.

Reach for it when: An operation can fail in expected ways and the caller needs to
decide what to do — continue the pipeline, retry, or handle the error.

Gotchas: Result objects proliferate quickly — every layer wraps and unwraps. If you
find yourself writing `result.success? ? Result.success(transform(result.value)) :
result` at every level, the ceremony is outweighing the benefit. Also, mixing result
objects with exceptions (some failures are results, some are raised) creates two
error paths that callers must handle.

Sub-concept — **Retryable Error**: A result branch where the failure carries retry
semantics. The error itself knows whether it's worth retrying (`retryable?`), so
the retry loop lives in the gateway, not scattered across callers. See
`practices/retry.md` for the full retry strategy.

Example: `result = Gateway.call(params)` → `result.success? ? next_step(result.value) : handle_error(result.error)`

### State Machine

Shape: An object with a finite set of named states and explicit transitions between
them. Invalid transitions are rejected, not silently ignored.

Reach for it when: Something has a lifecycle with rules about what can happen when —
and violating those rules is a bug, not an edge case.

Gotchas: State machines get complex fast when transitions depend on external
conditions or when you need parallel states. If you find yourself adding guard
clauses to every transition, the machine may be modeling the wrong thing. Also,
retrofitting a state machine onto code that already manages state implicitly is a
rewrite, not a refactor — treat it as such.

Example: An agent run that moves through `pending → running → completed/failed`.
You can't go from `completed` back to `running`.

### Boundary Guard

Shape: Validation at the entry point of a module or system. Rejects bad input before
it propagates. Internals trust that input has already been validated.

Reach for it when: You want to fail fast and keep validation logic in one place
rather than sprinkling checks throughout internal code.

Gotchas: The trust boundary must be clear — if there are multiple entry points and
only some have guards, internals can't actually trust their input. Also, guards that
validate too deeply (business rules, not just shape/type) end up duplicating logic
that belongs in the domain layer.

Example: A controller validates params and returns 422 before calling the service.
The service assumes valid input.

### Projection
(OOP: presenter/view model · FP: selector)

Shape: A read-only transformation that reshapes data for a specific consumer without
modifying the source.

Reach for it when: Different consumers need different views of the same data and
you don't want the source model to know about every consumer's needs.

Gotchas: Projections that reach back into the database (N+1 queries, lazy-loaded
associations) aren't really read-only transformations — they're query objects in
disguise. Also, one projection per consumer can lead to a proliferation of nearly
identical classes. If two projections differ by one field, consider parameterizing
rather than duplicating.

Example: `AgentRunPresenter.new(run).as_json` — selects and formats fields for the
API response without changing the run record.

### Interchangeable Implementation
(OOP: polymorphism/interface · Ruby: duck typing · FP: functions with same signature)

Shape: Multiple implementations that share a behavioral contract. Callers are
decoupled from which concrete implementation they're using. New implementations
can be added without changing callers.

Reach for it when: A caller shouldn't care *which* thing it's talking to — only
*what* it can do. The set of implementations is expected to grow.

Gotchas: The contract must be explicit enough that new implementations know what
to fulfill, but implicit contracts (duck typing) are fine when the interface is
small and obvious. The danger is when the contract grows silently — one
implementation adds a method, callers start depending on it, and other
implementations break. Also, if there's only one implementation and no concrete
plan for a second, this is speculative generality.

A registry (lookup structure mapping keys to implementations) is one wiring
mechanism for this pattern. Registries add runtime indirection that static analysis
can't follow — a missing registration is a runtime error. Use a simple conditional
until the set actually grows.

Example: `provider = ProviderRegistry.fetch(:claude)` / `provider.complete(prompt)`
— the caller knows the contract (`complete`), not the implementation.

### Dependency Graph
A family of related planning abstractions that describe how work or modules relate
to each other structurally. The core concept: *things have dependencies, and the
shape of those dependencies determines what's possible*.

#### DAG (Directed Acyclic Graph)

Shape: Nodes with directed edges and no cycles. Every node can be reached by
following edges forward, and you can never return to where you started.

Reach for it when: You're modeling task dependencies, build order, or module
relationships where circular dependencies are a bug.

Gotchas: Cycles are the primary failure mode — they make execution order
undecidable. In code, circular dependencies between modules are a DAG violation
and usually signal that the module boundaries are wrong. In planning, a cycle
means two tasks each depend on the other, which is a spec problem, not an
implementation problem.

Example: Module dependency graph — analytics depends
on agents, but no module depends on itself through any chain.

#### Workflow

Shape: A DAG with a defined execution order — steps have dependencies and run in
a specific sequence (or in parallel where dependencies allow).

Reach for it when: You have ordered work where some steps depend on others
completing first, and the order matters for correctness.

Gotchas: Workflows that look linear but have hidden parallel paths are under-modeled
as pipelines. Workflows that look parallel but have implicit ordering dependencies
are under-modeled as DAGs. Pick the model that matches the actual constraints.

Example: The ralph loop — plan → build → review → reflect. Each phase depends on
the previous phase's output.

#### Task DAG (Workflow Instance)

Shape: A workflow template defines a set of tasks with dependency edges. An instance
is created from a template, and tasks are materialized as their dependencies complete.
The instance advances itself: when a task completes, it checks which new tasks have
all dependencies satisfied and creates them. When all tasks are complete, the instance
completes.

Reach for it when: You need to orchestrate multi-step work where steps have
prerequisites, assignees, and due dates — and the shape of the work is defined by a
reusable template, not hardcoded.

Gotchas: The advance logic must be idempotent — calling it twice should not create
duplicate tasks. Due date calculation relative to events (start date, publication
date) requires the target entity to exist and have the relevant date populated.
Closing a workflow must close all open tasks — orphaned open tasks are a data
integrity bug.

Relevance to the reference graph: a collection of planning and implementation specs forms a
dependency graph. A bug can be traced back through the graph to the planning or
implementation decision that caused it — `depends_on` refs in `IMPLEMENTATION_PLAN.md`
are the same structural concept as task dependencies in a workflow.

#### Graph (with cycles)

Shape: Nodes and edges with no acyclicity constraint. Cycles are allowed and
sometimes intentional.

Reach for it when: You're modeling relationships where circular references are
valid — social graphs, bidirectional links, recursive structures.

Gotchas: Traversal must handle cycles explicitly (visited sets, depth limits) or
it loops forever. Most dependency relationships should be DAGs; if you're reaching
for a cyclic graph to model dependencies, reconsider the boundaries.

Example: A knowledge graph where documents reference each other — A links to B,
B links to A. Valid structure, but traversal needs cycle detection.

### Strategy
(OOP: strategy pattern · FP: higher-order function / function parameter)

`status: proposed`

Shape: An algorithm is extracted into a separate object (or function) and passed to
a context that delegates to it. The context's behavior changes by swapping the
strategy, not by branching internally.

Reach for it when: A single operation has multiple behavioral variants and the
variant is selected at runtime. The context shouldn't know the details of each
variant — only that the strategy fulfills a contract.

Gotchas: Strategy and interchangeable implementation overlap — the difference is
emphasis. Interchangeable implementation focuses on the *set* of implementations
and how callers are decoupled from them. Strategy focuses on *runtime selection*
of behavior by a context object. If the "strategy" is selected once at boot and
never changes, it's just dependency injection. If the context contains a conditional
to pick the strategy, you've moved the branching, not removed it.

Example: `Scheduler.new(strategy: RoundRobin).assign(tasks)` — swap `RoundRobin`
for `LeastLoaded` without changing `Scheduler`.

### Decorator
(OOP: decorator pattern · FP: function wrapping / middleware)

`status: proposed`

Shape: An object wraps another object with the same interface, adding behavior
before or after delegating to the wrapped object. Multiple decorators can be
stacked. The caller doesn't know whether it's talking to the original or a
decorated version.

Reach for it when: You need to layer on cross-cutting behavior (logging, caching,
retry, metrics) without modifying the original object or subclassing it.

Gotchas: Deep decorator stacks are hard to debug — a bug could live in any layer,
and stack traces don't make the wrapping order obvious. Identity checks break
(`decorated == original` is false). If every call site needs the same set of
decorators, the wrapping is boilerplate — consider baking the behavior into the
object or using a pipeline instead.

Example: `LoggingProvider.new(CachingProvider.new(ClaudeProvider.new))` — each
layer adds behavior while preserving the `complete(prompt)` interface.

### Observer
(OOP: observer/listener · Ruby: `ActiveSupport::Notifications` · FP: callback / event stream)

`status: proposed`

Shape: A subject emits events. Observers subscribe to those events and react
independently. The subject doesn't know what the observers do — it only knows
how to notify them.

Reach for it when: A change in one object should trigger reactions in others, but
you don't want the source to depend on (or even know about) the reactors. The set
of reactions is expected to grow or vary by context.

Gotchas: Invisible control flow — reading the subject's code doesn't reveal what
happens when it fires an event. Debugging requires tracing through the subscription
registry. Ordering between observers is usually undefined; if observers depend on
each other's side effects, you have hidden coupling. Synchronous observers that
raise exceptions can break the subject's flow — decide whether observers fail open
or closed.

Example: `run.on(:completed) { |r| Metrics.record(r) }` — the run doesn't know
about metrics; it just fires the event.

### Singleton
(OOP: singleton pattern · Ruby: module with `self.` methods · FP: module-level state)

`status: proposed`

Shape: Exactly one instance of a thing exists for the lifetime of the process.
Access goes through a well-known global point rather than being passed as a
dependency.

Reach for it when: A resource is genuinely process-global (connection pool, config
registry, logger) and passing it everywhere would thread a parameter through every
layer with no decision point.

Gotchas: Singletons are global mutable state with a fancy name. They make testing
painful — every test shares the same instance, so test isolation requires explicit
reset. They hide dependencies: a class that uses `Config.instance` has an invisible
dependency on `Config` that doesn't appear in its constructor. Prefer dependency
injection for anything that might vary between contexts (test vs. production,
tenant A vs. tenant B). Reach for singleton only when the "exactly one" constraint
is a real invariant, not a convenience.

Example: `ConnectionPool.instance` — one pool per process, shared across all
threads.

### Facade

`status: proposed`

Shape: A single entry point that provides a simplified interface to a complex
subsystem. The facade delegates to internal objects but hides their interactions
from callers.

Reach for it when: A subsystem has multiple collaborating objects and external
callers shouldn't need to know the wiring. The facade gives them one method to
call instead of orchestrating three objects themselves.

Gotchas: A facade that grows to expose every method of every internal object is
just an indirection layer, not a simplification. If callers routinely need to
bypass the facade to access internals, the facade's abstraction level is wrong.
Also, facades can mask complexity that should be addressed — wrapping a tangled
subsystem in a clean interface doesn't untangle it.

Example: `Sandbox.run(code)` — internally coordinates container creation, code
injection, execution, and cleanup. Callers see one method.

## Anti-patterns

Structural smells that predict problems. Not every instance is wrong — but when you
see one, pause and evaluate.

### Hidden Coupling

Shape: Two things that look independent but break together. A change in one requires
a change in the other, but nothing in the code makes that relationship visible.

Watch for: Shared mutable state, implicit ordering dependencies, convention-based
wiring with no enforcement.

Gotchas: Not all coupling is hidden — some is intentional and correct. Two things
that change together because they represent the same concept *should* be coupled.
The smell is when the coupling is invisible, not when it exists.

### Shotgun Change

Shape: One conceptual change requires edits scattered across many unrelated files.

Watch for: A feature spread across multiple modules with no unifying boundary. Adding
a field requires touching model, serializer, controller, view, test, and migration
with no shared abstraction tying them together.

Gotchas: Some shotgun changes are inherent to the domain — adding a database column
*will* touch migration, model, and test. The smell is when the scatter is avoidable
but no one has extracted the unifying concept. Also, over-consolidating to avoid
shotgun change can create god objects.

### State Soup

Shape: Mutable state shared across boundaries with no clear owner. Multiple callers
read and write the same data, and the valid states aren't enforced.

Watch for: Instance variables set in one method and read in another with no guarantee
about call order. Global or class-level mutable state.

Gotchas: Shared state isn't always soup — a database is shared mutable state with
clear ownership and transaction boundaries. The smell is the absence of those
boundaries, not the sharing itself.

### Silent Swallow

Shape: An error is caught and discarded. The caller has no idea something went wrong.

Watch for: Empty rescue/catch blocks, logging without re-raising or returning an
error result, `rescue => e; nil`.

Gotchas: Sometimes swallowing is correct — a best-effort notification that shouldn't
crash the main flow, for instance. The smell is when the swallow is *silent* (no log,
no metric, no comment explaining why it's safe to ignore).

### Speculative Generality

Shape: Abstraction built for a future use case that hasn't arrived. The code is more
complex than the current requirements justify.

Watch for: Interfaces with one implementation, configuration options nobody uses,
"just in case" parameters.

Gotchas: This is the hardest smell to call correctly. Sometimes the second use case
arrives next week and the abstraction pays off. The test: can you name the concrete
future scenario, or are you abstracting "just in case"? If you can't name it, it's
speculative.

## Pattern Lifecycle

Each entry has a status. The status tracks how battle-tested the pattern is.

| Status | Meaning |
|---|---|
| `proposed` | Noticed during work, named and defined, not yet used in a real cycle |
| `adopted` | Used in at least one plan or review cycle and held up |
| `merged` | Absorbed into another pattern — entry kept with a pointer to the new home |
| `split` | Broken into more specific patterns — entry kept with pointers to the children |
| `retired` | Removed from active use — entry kept with a note on why |

All current entries above are `adopted` unless marked otherwise.

### Registry (dispatch) — `status: merged` → Interchangeable Implementation
Registry-as-dispatch is a wiring mechanism for the interchangeable implementation
pattern — an explicit lookup table mapping keys to implementations. Kept as a
sub-concept there rather than a standalone entry.

Not to be confused with Self-Registering Plugin (below), which is about *how*
implementations get into the registry, not how callers look them up.

### Self-Registering Plugin — `status: adopted`
(Python: `@register` decorator · Ruby: `inherited` hook · OOP: plugin pattern)

Shape: Implementations register themselves into a shared lookup as a side effect
of being loaded (via decorator, metaclass, or lifecycle hook). Adding a new
implementation requires only creating it — no central manifest to update.

Reach for it when: The set of implementations grows frequently, contributors
shouldn't need to touch a central file to add one, and you want open/closed
behavior at the module level.

Gotchas: Registration is invisible — nothing in the call site reveals what's
registered or in what order. Load-order bugs are subtle: if a module isn't
imported, its decorator never fires and the implementation silently doesn't exist.
Static analysis and IDE navigation can't follow the indirection. In small
codebases with a stable set of implementations, explicit wiring (the dispatch
registry in Interchangeable Implementation) is simpler and easier to trace. Reach
for this only when manual registration is an actual maintenance burden, not a
theoretical one.

Example: `@register("claude") class ClaudeProvider: ...` — importing the module
adds `"claude"` → `ClaudeProvider` to a global dict. Callers use the dispatch
registry; they never know registration was automatic.

Retired, merged, and split entries stay in the file with their status and a note.
This prevents re-proposing something we already tried, and gives agents context when
they encounter references to old pattern names in committed code.

## Process for Changes

### Proposing a New Pattern

Either human or agent can propose. During planning or review, if a recurring
structural concept doesn't have a name in this vocabulary:

1. Name it
2. Write the shape, reach-for-it-when, and a terse example
3. Add it with `status: proposed`
4. Use it in the current cycle

### Adopting

After a proposed pattern has been used in at least one real plan or review cycle
and both human and agent found it useful, change status to `adopted`.

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

## Code References

When code implements a pattern from this vocabulary, a soft reference is acceptable:

```ruby
# structural-vocabulary: pure-transform
class Amount
  def to_formatted_string
    # ...
  end
end
```

These references are optional and lightweight. They exist so agents (and humans doing
code review) can quickly map implementation back to intent. They are not enforced.
