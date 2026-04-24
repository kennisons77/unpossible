---
name: structural-vocabulary-guarantees
kind: practice
domain: Structural vocabulary
description: Consistency and coordination guarantees — what a system promises about concurrent operations
loaded_by: [plan, review]
---

# Structural Vocabulary — Guarantees

What a system promises about concurrent operations. Loaded on demand alongside
`core.md`. For an overview of the full system see `README.md`.

These are not patterns you implement — they are properties you choose when selecting
a data layer, designing a protocol, or specifying what a component must provide.
Naming the guarantee in a requirements file makes the design decision explicit and
testable.

## Consistency Guarantees

How a system behaves when multiple processes read and write the same data.

### Linearizability

Shape: Every operation appears to execute atomically at a single point in real time.
If operation A completes before operation B begins, A appears to execute before B.
The strongest single-object consistency guarantee.

Reach for it when: You need a single source of truth that all processes agree on
instantly — leader election, distributed locks, counters that must never go
backwards.

Gotchas: Linearizability requires coordination between nodes — it cannot be achieved
in a totally available system (see CAP theorem). Any network partition will cause
some operations to block or fail. The cost is latency and availability; the benefit
is simplicity of reasoning.

Example: A distributed lock service — once a process acquires the lock, no other
process can acquire it until it's released, regardless of which node they talk to.

### Serializability

Shape: All transactions appear to execute in some total serial order, even if they
ran concurrently. The outcome is equivalent to running them one at a time. The
strongest multi-object consistency guarantee.

Reach for it when: You have transactions that touch multiple objects and need to
reason about them as atomic units. The canonical guarantee for ACID databases.

Gotchas: Serializability does not require that the apparent order matches real time
— a transaction that committed first may appear to execute after one that committed
later. For real-time ordering, see Strong Serializability. Most databases that claim
"serializable" isolation actually implement Snapshot Isolation, which is weaker.

Example: A bank transfer — debit account A and credit account B must appear atomic.
No other transaction should see A debited without B credited.

### Snapshot Isolation

Shape: Each transaction reads from a consistent snapshot of the database taken at
transaction start. Writes are applied atomically at commit time. Two transactions
can write different objects concurrently without conflict, but cannot write the same
object (one will be aborted).

Reach for it when: You need good read consistency without the full cost of
serializability. The default isolation level in Postgres and most modern databases.

Gotchas: Snapshot Isolation allows Write Skew — two transactions each read a value,
make a decision based on it, and write different objects. Neither sees the other's
write. The combined result may violate an invariant that neither transaction violated
individually. Requires explicit locking (`SELECT FOR UPDATE`) or application-level
checks to prevent.

Example: Two doctors both check that at least one doctor is on call, then both go
off call. Each transaction sees the other doctor as on call at read time; neither
sees the other's write. Result: no doctors on call — a Write Skew anomaly.

### Eventual Consistency

Shape: After updates cease, given sufficient time and message passing, all nodes
converge to the same value. No guarantee about when convergence happens or what
intermediate states look like.

Reach for it when: You need total availability — reads and writes must succeed even
during network partitions. Acceptable when stale reads are tolerable and conflicts
can be resolved automatically (last-write-wins, CRDTs).

Gotchas: "Eventually consistent" is not a single model — it covers a wide range of
behaviors. Two eventually consistent systems may behave very differently under
concurrent writes. Conflict resolution must be designed explicitly; ignoring it
leads to lost writes or data corruption.

Example: DNS — a record update propagates to all resolvers eventually, but a client
may see the old value for minutes or hours after the update.

### Causal Consistency

Shape: If operation A causally precedes operation B (A happened before B, or A's
result was observed before B was issued), all processes observe A before B. Operations
with no causal relationship may be observed in any order.

Reach for it when: You need to preserve cause-and-effect ordering without the cost
of full serializability. Common in collaborative systems where "you always see your
own writes and their consequences."

Gotchas: Causal consistency requires tracking causal dependencies (vector clocks,
logical timestamps). It is stronger than eventual consistency but weaker than
linearizability. Two causally unrelated writes may be observed in different orders
by different processes — this is correct behavior, not a bug.

Example: A comment thread — if you post a reply to a comment, anyone who sees your
reply must also see the original comment. But two unrelated comments may appear in
different orders to different users.

### Read Your Writes

Shape: After a process performs a write, any subsequent read by that same process
reflects that write. Other processes may still see stale data.

Reach for it when: You need session-level consistency — a user who submits a form
must see their submission reflected immediately, even if other users see stale data.

Gotchas: Read-your-writes is a session guarantee, not a global one. If the user
switches devices or sessions, the guarantee may not hold. Implementing it in a
distributed system typically requires routing the user's reads to the same node
that processed their write, or using a version token.

Example: After a user updates their profile, their next page load shows the updated
profile — even if the write hasn't propagated to all read replicas yet.

## Coordination Guarantees

How a distributed system makes decisions when nodes may disagree.

### Quorum

Shape: An operation succeeds only when a majority (or configured fraction) of nodes
acknowledge it. Reads and writes both require quorum acknowledgment. A system with
N nodes can tolerate ⌊N/2⌋ failures.

Reach for it when: You need strong consistency guarantees in a distributed system
while tolerating node failures. The coordination mechanism underlying Raft, Paxos,
and most strongly-consistent distributed databases.

Gotchas: Quorum requires that a majority of nodes be reachable — a network partition
that isolates the minority will cause the minority to become unavailable. Quorum
size is a trade-off: larger quorums are more fault-tolerant but slower. Read and
write quorums must overlap (R + W > N) to guarantee that reads see the latest write.

Example: A 5-node Raft cluster requires 3 nodes to agree before committing a log
entry. If 2 nodes fail, the cluster continues. If 3 nodes fail, the cluster halts
rather than risk split-brain.

### Definite vs Indefinite Error

Shape: A **definite error** means the operation definitely did not happen — the
system is in the same state as before the call (e.g. 400 Bad Request, transaction
abort). A **indefinite error** means the operation may or may not have happened —
the caller cannot know without querying (e.g. timeout, network error, 503).

Reach for it when: Designing error handling for any operation with side effects.
The distinction determines whether it is safe to retry: definite errors are safe
to retry (nothing happened); indefinite errors require idempotency before retrying.

Gotchas: Most network errors are indefinite — a timeout does not mean the server
didn't process the request. Treating indefinite errors as definite leads to lost
writes; treating definite errors as indefinite leads to duplicate operations. This
distinction is the conceptual foundation of the Idempotent Receiver pattern and the
retry strategy in `practices/retry.md`.

Example: `POST /payments` returns a network timeout. The payment may have been
processed. Retrying without an idempotency key may charge the customer twice.
`POST /payments` returns 422 Unprocessable Entity — the payment definitely was not
processed; retry is safe.
