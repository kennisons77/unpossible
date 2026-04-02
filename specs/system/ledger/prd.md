# PRD: Ledger

- **Status:** Draft
- **Created:** 2026-04-01
- **Last revised:** 2026-04-01

## Intent

The Ledger is the universal record of everything that has been asked and answered in a
project — from a pitch to a button click. It replaces the fragmented collection of
markdown files, database models, and status fields with one recursive structure: nodes
that are either questions or answers, ordered by time.

## Personas

- **Solo developer (you):** wants to see the full history of a project — what was
  asked, what was tried, what was accepted — without stitching together five different
  files
- **Loop agent:** needs a single queryable surface to find the next open question and
  record its answer
- **Future contributor:** onboarding to a project; needs to understand what was decided
  and why without tribal knowledge
- **The system itself:** every layer — code, deployment, UI, user interaction — records
  its state as questions and answers in the same structure

## User Scenarios

**Scenario 1 — Following a decision:**
A contributor wants to understand why the vector index uses HNSW. They find the spike
node, read the research answer that closed it, and see the commit that implemented it —
all linked by refs. No digging through git blame, Slack, or separate docs.

**Scenario 2 — The loop picks up work:**
The loop queries for the oldest open question with scope `code` and no unresolved
dependencies. It finds a beat, works on it, posts a commit as a candidate answer. The
test runner posts a verdict. If the verdict is false, the beat re-opens and the loop
tries again. If true, the beat closes and the loop moves to the next question.

**Scenario 3 — A user hits an error:**
A form submission fails. The system records a failed answer and automatically opens a
bug question. A developer sees the bug in the open questions list, investigates, posts a
fix commit. The test runner accepts it. The bug question closes.

**Scenario 4 — Reviewing project history:**
A developer wants to know what happened in the last two weeks. They query the ledger by
time range. They see every question asked, every answer posted, every verdict rendered —
across code, deployment, and UI layers — in one ordered list.

**Scenario 5 — A deployment question:**
A new version is deployed. The system posts a deployment question. The health check
runner continuously posts answers. The latest accepted answer is the current deployment
state. A degraded health check posts a false verdict, re-opening the deployment question
and triggering an alert.

## User Stories

- As the loop, I want to query open questions by scope and dependency state so I can
  find the next unit of work without reading files.
- As the loop, I want to post an answer to a question so the system reflects what was
  done.
- As the test runner, I want to post a verdict on a candidate answer so the question
  closes or re-opens automatically.
- As a developer, I want to query the full history of a node and its children so I can
  understand what was tried and why.
- As a developer, I want to see all open questions across all scopes so I know what the
  system is waiting on.
- As the system, I want a failed interaction to automatically open a bug question so
  nothing falls through the cracks.

## Success Metrics

| Goal | Metric |
|---|---|
| Single source of truth | Zero status fields outside the ledger for any artifact type |
| Loop correctness | Loop never works on a question with unresolved dependencies |
| History completeness | Every accepted answer is traceable to the question it closed |
| Verdict reliability | A false verdict always re-opens its parent question within one cycle |

## Functional Requirements

**MVP:**

- **Node CRUD** — create, read, and query nodes. Questions and answers are both nodes.
  Answers are immutable after creation.
- **Question lifecycle** — questions transition through open → in_progress → closed,
  derived from the acceptance state of their child answers. No manual status setting.
- **Verdict** — an answer's `accepted` field can be set to `true` or `false` exactly
  once. A true verdict closes the parent question. A false verdict re-opens it.
- **Dependency enforcement** — a question cannot move to `in_progress` while any node
  in its `depends_on` list is not closed.
- **Refs** — a node can ref multiple other nodes. Querying by ref returns all nodes that
  cross-link to a given node.
- **Scope filter** — nodes can be queried by scope: intent, code, deployment, ui,
  interaction.
- **Ledger query** — returns all nodes ordered by timestamp. Supports filtering by
  scope, status, author, and ref.
- **Digest** — an answer node that summarises a range of prior nodes. Acts as a
  checkpoint. Does not close any question.
- **Auto-open bug** — a failed interaction answer (scope: interaction, accepted: false)
  automatically creates a child bug question (scope: code).

**Post-MVP:**

- Backfill from existing artifacts (activity.md, IMPLEMENTATION_PLAN.md, git log)
- Ledger export as markdown snapshot
- Webhook / event stream on node state changes
- Multi-author conflict resolution on question closure

## Features Out

- Deletion — nodes are never deleted; corrections are new answer nodes
- Manual status setting on questions — status is always derived, never set directly
- Real-time push — polling only in Phase 0

## Specs

| Spec file | Description |
|---|---|
| [`spec.md`](spec.md) | Node schema, NodeEdge, Actor/ActorProfile, disk↔DB sync, query behaviour |



## Open Questions

| Question | Answer | Date |
|---|---|---|
| Should the ledger be one global table or partitioned by scope? | | |
| How does the ledger relate to the existing Story and Task models during migration? | | |
| What is the retention policy for rebutted candidate answers? | | |
