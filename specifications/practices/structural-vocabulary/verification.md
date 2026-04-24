---
name: structural-vocabulary-verification
kind: practice
domain: Structural vocabulary
description: Verification techniques — how to test that a system behaves correctly under normal and fault conditions
loaded_by: [plan, build]
---

# Structural Vocabulary — Verification

How to test that a system behaves correctly under normal and fault conditions. Loaded
on demand alongside `core.md`. For an overview of the full system see `README.md`.

These are techniques, not patterns — they describe *how to verify* a design, not how
to structure it. See also `specifications/practices/verification.md` for unpossible's
specific verification practices and acceptance criteria conventions.

## Techniques

### Property

Shape: A claim about system behavior that must hold across all inputs, states, or
executions. Properties are the *what* of verification — they define correctness.
A test is an attempt to falsify a property.

Reach for it when: Specifying acceptance criteria. A property is more durable than
an example — "the system never returns a negative balance" survives implementation
changes; "the system returns 0 for this specific input" does not.

Gotchas: Properties that are too broad are untestable ("the system is correct").
Properties that are too narrow are just examples in disguise ("the system returns 42
for input 6 × 7"). A good property names an invariant that must hold across a class
of inputs or states. Properties should be derived from acceptance criteria in concept
files, not invented during implementation.

Example: "A completed agent run always has a non-null `finished_at`." "An archived
feature flag always returns false from `enabled?`." "Turn content GC never purges
runs with status `waiting_for_input`."

### Example-Based Testing

Shape: A specific input is applied to the system and a specific output is expected.
The test passes if the output matches. The test is a single data point, not a claim
about a class of inputs.

Reach for it when: The behavior is deterministic and the interesting cases are known
in advance. Example-based tests are easy to write, easy to read, and fast to run.
They are the right tool for most unit and integration tests.

Gotchas: Example-based tests only cover the cases you thought of. They give false
confidence when the interesting failure modes are in the cases you didn't think of —
edge cases, concurrent executions, fault conditions. Complement with property-based
testing for operations with large input spaces or subtle invariants.

Example: `expect(FeatureFlag.enabled?(org_id: 1, key: 'x')).to eq(false)` for an
archived flag. A specific input, a specific expected output.

### Property-Based Testing

Shape: A generator produces random inputs. The system under test is applied to each
input. A property (invariant) is checked after each application. If the property is
violated, the test fails and the input is shrunk to the minimal failing case.

Reach for it when: The input space is large, the interesting failure modes are not
obvious, or you want confidence that an invariant holds across all inputs rather than
just the ones you thought of. Particularly valuable for pure transforms, data
structure invariants, and protocol correctness.

Gotchas: Property-based tests require well-defined generators and properties — vague
properties produce useless tests. Shrinking (reducing a failing input to its minimal
form) is essential for debuggability; without it, a failing test may produce a
10,000-element list when a 3-element list would demonstrate the same bug. Runtime is
higher than example-based tests; run fewer iterations in CI, more in nightly builds.

Example: For any sequence of agent run turns, applying the pinned+sliding window
algorithm must always include all `agent_question` and `human_input` turns in the
output, regardless of token budget. A generator produces random turn sequences and
budgets; the property is checked for each.

### Fault Injection

Shape: Failures are deliberately introduced into the system during a test to verify
that the system handles them correctly. The test harness controls which faults occur,
when, and how often. The system's behavior under fault is compared against its
specified guarantees.

Reach for it when: Testing fault tolerance claims. A system that claims to handle
network partitions, node crashes, or storage errors must be tested with those faults
actually injected — not just with happy-path tests. Without fault injection, fault
tolerance is untested speculation.

Gotchas: Fault injection tests are harder to write and maintain than happy-path
tests. Start with the faults most likely to occur in production (network timeouts,
process restarts) before exotic faults (Byzantine behavior, storage corruption).
Fault injection in integration tests requires infrastructure support — a test double
that can simulate failures, or a real system with a fault injection layer.

Example: During an analytics ingest test, the Postgres connection is severed after
50 events are buffered. The test verifies that no events are dropped — the buffer
holds them until the connection is restored and they are flushed. The fault is the
Postgres unavailability; the property is "zero events dropped on brief outage."

### Deterministic Simulation Testing

Shape: The system under test runs inside a controlled environment where all sources
of nondeterminism (network, clock, disk, scheduler) are replaced with deterministic
simulators. The test can reproduce any execution exactly by replaying the same
sequence of simulated events. Bugs found in simulation are reproducible by
construction.

Reach for it when: Testing distributed systems where bugs depend on specific
interleavings of concurrent operations that are impossible to reproduce reliably in
a real environment. The gold standard for distributed systems correctness testing.

Gotchas: Deterministic simulation requires the system to be designed for it — all
nondeterministic components must be injectable. Retrofitting simulation onto an
existing system is expensive. The simulation environment must faithfully model the
real environment's failure modes, or it will miss bugs that only occur in production.
Start with fault injection in integration tests; graduate to deterministic simulation
when the system's complexity justifies the investment.

Example: FoundationDB runs its entire test suite inside a deterministic simulator.
Every network message, disk write, and clock tick is controlled by the test harness.
A bug found in simulation can be reproduced by replaying the exact same event
sequence — no flaky tests, no "works on my machine."

### Oracle

Shape: A component that determines whether a test run was correct. A simple oracle
detects crashes or assertion failures. A complex oracle takes all inputs and outputs
from a test run and decides whether the behavior was valid — for example, by checking
that a history of database operations satisfies a consistency model.

Reach for it when: The correct output cannot be computed from the input alone, or
when correctness depends on the relationship between multiple operations over time.
Oracles are essential for testing distributed systems where the correct behavior
depends on the order and interleaving of operations.

Gotchas: An oracle that is too strict rejects valid behaviors and produces false
positives. An oracle that is too lenient misses real bugs. The oracle must encode
the same invariants as the system's specification — if the spec is wrong, the oracle
is wrong. A reference implementation (a simpler, slower version of the system) is
a useful oracle when one exists.

Example: A test runs 100 concurrent transactions against a database claiming
Snapshot Isolation. The oracle (a consistency checker like Jepsen's Elle) analyzes
the history of reads and writes and verifies that no Write Skew anomalies occurred.
The oracle encodes the Snapshot Isolation invariant; the test generates the history.
