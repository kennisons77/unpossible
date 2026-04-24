---
name: structural-vocabulary-faults
kind: practice
domain: Structural vocabulary
description: Fault taxonomy — what can go wrong in distributed systems and how to classify it
loaded_by: [plan, review]
---

# Structural Vocabulary — Faults

What can go wrong in distributed systems and how to classify it. Loaded on demand
alongside `core.md`. For an overview of the full system see `README.md`.

Naming faults precisely matters for two reasons: it determines what the system must
tolerate (design), and it determines what tests must inject (verification). A system
that says "handles failures" without naming which failures is underspecified.

## Process Faults

Failures of individual nodes or processes.

### Crash-Recover

Shape: A node stops executing and later restarts. State in memory is lost; state on
disk may survive depending on sync behavior. The node rejoins the system after
recovery.

Reach for it when: Designing the normal fault model for any persistent service. Most
production failures are crash-recover, not crash-stop. The system must handle nodes
that disappear and reappear with stale or partial state.

Gotchas: A node that crashes and recovers may have partially applied an operation —
it wrote to disk but didn't acknowledge, or acknowledged but didn't replicate. The
recovery path must handle these partial states explicitly. Amnesia (see below) is a
special case of crash-recover where in-memory state is lost.

Example: A Postgres primary crashes mid-transaction. On restart, it replays the WAL
to recover committed state and rolls back uncommitted transactions. Replicas detect
the gap and re-sync.

### Crash-Stop

Shape: A node stops executing and never recovers. From the system's perspective, it
has permanently left.

Reach for it when: Modeling the worst case for availability calculations. A system
that tolerates crash-stop faults can handle any number of permanent node losses up
to its fault tolerance threshold.

Gotchas: In practice, crash-stop is rare — most nodes eventually recover. Designing
only for crash-stop may leave the system unprepared for the more common crash-recover
scenario, where a recovered node brings stale state back into the cluster.

Example: A hard disk failure that destroys all data. The node cannot recover without
replacement hardware and a full data restore.

### Amnesia

Shape: A node forgets some or all of its state. Total amnesia occurs when a node
loses everything (crash without durable state). Partial amnesia occurs when in-memory
state is lost but disk state survives.

Reach for it when: Reasoning about what a node knows after a restart. Ephemeral
workers (see `extended.md`) are designed with intentional total amnesia — each
invocation starts clean. Persistent services must handle partial amnesia in their
recovery path.

Gotchas: A node with amnesia may rejoin a cluster and make decisions based on stale
or absent state — voting in an election it already participated in, accepting a write
it already rejected. Protocols must account for amnesiac nodes explicitly.

Example: The agent runner reconstructs full turn history from the database on each
job execution — it never relies on in-memory state from a previous execution. This
is intentional amnesia: the job is stateless by design.

### Pause

Shape: A process pauses for an unpredictable duration, then resumes. The pause may
be caused by garbage collection, OS scheduling, hypervisor migration, or I/O stalls.
From the outside, a paused process is indistinguishable from a crashed one until it
resumes.

Reach for it when: Designing timeout logic or lease-based coordination. A process
that holds a lock or lease may pause past the lease expiry, then resume believing it
still holds the lease — while another process has already taken over.

Gotchas: Pauses invalidate time-based assumptions. A process that checks a condition
and then acts on it may have paused between the check and the action, allowing the
condition to change. This is the "check-then-act" race condition in distributed form.

Example: A leader holds a lease for 10 seconds. It pauses for 15 seconds due to GC.
It resumes believing it is still leader and serves reads — but a new leader was
elected during the pause. The reads are stale.

### Byzantine Fault

Shape: A node takes arbitrary actions, including malicious ones — sending conflicting
messages to different peers, corrupting data, impersonating other nodes, or voting
multiple times. The node does not simply fail; it actively misbehaves.

Reach for it when: Designing systems where nodes are not fully trusted — public
blockchains, multi-party computation, systems where a compromised node is a realistic
threat. Byzantine fault tolerance requires 2/3 of nodes to be honest.

Gotchas: Byzantine fault tolerance is significantly more expensive than crash fault
tolerance — it requires larger quorums, more message rounds, and more complex
protocols. Most internal distributed systems (databases, queues, service meshes)
assume crash faults only. Reach for Byzantine tolerance only when the threat model
requires it.

Example: A blockchain validator that has been compromised sends conflicting votes to
different peers in an attempt to cause a fork. A Byzantine fault-tolerant consensus
protocol detects the equivocation and ignores the validator.

## Network Faults

Failures of communication between nodes.

### Network Partition

Shape: All messages on a network link are lost for some duration. Nodes on either
side of the partition cannot communicate. The partition may be one-directional (A
can send to B but not receive) or bidirectional. It may isolate one node or split
the cluster into two groups.

Reach for it when: Designing any distributed system. Network partitions are not
exceptional — they happen in production regularly due to misconfigured firewalls,
switch failures, and cloud provider incidents. A system that cannot tolerate
partitions is not production-ready.

Gotchas: During a partition, a system must choose between consistency (refuse
operations until the partition heals) and availability (continue operating with
potentially stale or conflicting state). This is the CAP theorem trade-off. Most
systems choose availability for reads and consistency for writes, or use quorum
to balance both.

Example: A network switch fails, splitting a 5-node cluster into a group of 3 and
a group of 2. The group of 3 has quorum and continues operating. The group of 2
refuses writes to avoid split-brain. When the partition heals, the group of 2
re-syncs from the group of 3.

### Message Omission

Shape: A message is sent but never received. The sender does not know whether the
message was lost in transit or simply delayed. Indistinguishable from an infinite
delay.

Reach for it when: Designing retry logic and timeout handling. Any operation that
sends a message and waits for a response must handle the case where the message
was lost — the response will never arrive.

Gotchas: Message omission is the reason indefinite errors exist (see `guarantees.md`
§ Definite vs Indefinite Error). A timeout after a message omission does not mean
the operation failed — it means the acknowledgment was lost. The operation may have
succeeded.

Example: A client sends a write request to a database. The request is lost in a
congested network switch. The client times out and retries. If the write was not
idempotent, the retry may create a duplicate.

### Clock Skew

Shape: The clocks on two nodes disagree by some amount. All real clocks drift; clock
skew is the instantaneous difference between them. When skew is large enough to
affect application logic, it becomes a fault.

Reach for it when: Designing any system that uses wall-clock time for ordering,
expiry, or conflict resolution. Last-write-wins conflict resolution, lease expiry,
and rate limiting based on timestamps are all vulnerable to clock skew.

Gotchas: NTP reduces but does not eliminate clock skew — typical production skew is
milliseconds to seconds. Systems that require tight clock synchronization (e.g.
Google Spanner's TrueTime) use specialized hardware. For most systems, use logical
clocks (Lamport timestamps, vector clocks) for ordering rather than wall clocks.

Example: Two nodes both write to the same key with last-write-wins conflict
resolution. Node A's clock is 2 seconds ahead. Node A writes at T=100; Node B
writes at T=99 (real time T=101). Node B's write wins despite being later in real
time — a lost write caused by clock skew.

## Storage Faults

Failures of persistent storage.

### Storage Corruption

Shape: A storage device silently returns incorrect data. The data may have been
written correctly but degraded over time (bit rot), written to the wrong location
(misdirected write), or corrupted in transit across the storage bus. The device
does not report an error — it returns wrong data as if it were correct.

Reach for it when: Designing systems with strong durability requirements. Storage
corruption is rare but not negligible — studies show measurable rates of silent
corruption in production storage systems. Checksums at the application layer (not
just the filesystem) are the primary defense.

Gotchas: Filesystem checksums (e.g. ZFS) detect corruption at the block level but
not at the application level. An application that reads a block, checksums it, and
finds it valid may still receive logically incorrect data if the corruption happened
at a higher level. End-to-end checksums (hash the data before writing, verify after
reading) are the only reliable defense.

Example: A database page is silently corrupted on disk. The database reads it,
finds the page checksum valid (the checksum was also corrupted), and returns wrong
query results. The corruption is only discovered when a backup restore produces
different results.
