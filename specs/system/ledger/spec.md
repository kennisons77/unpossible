# Ledger

## What It Does

Provides the universal data model underlying every artifact in the system. A pitch, a
PRD, a spec, a beat, a commit, a bug, a form submission, a deployment — all are nodes
in one recursive structure: questions and answers.

## Why It Exists

Every existing model (Story, Task, AgentProfile, PlanFile, ActivityLog) is a
specialisation of the same pattern: intent declared, work recorded, summary produced.
Unifying them into one model makes the system queryable across artifact types, eliminates
duplicate status tracking, and gives the loop a single primitive to operate on.

The same pattern holds at every layer of the stack — from a pitch to a button click.
The primitive does not change. Only the scope does.

## Core Model

```
Node
  id                     UUID
  kind                   question | answer
  answer_type            terminal | generative  (answers only)
  scope                  intent | code | deployment | ui | interaction
  body                   content (markdown)
  title                  short label (derived from body first line if not set)
  spec_path              relative path to associated file on disk (nullable)
  author                 human | agent | system
  stable_ref             SHA256 of normalized(title + primary_parent_id) — see open questions
  version                integer, incremented on each status transition
  status                 open | in_progress | blocked | closed  (questions only)
  resolution             done | duplicate | deferred | wont_do | icebox  (questions only, set on close)
  accepted               true | false | pending  (answers only)
  accepted_by[]          author IDs who have accepted this answer
  acceptance_threshold   integer — how many acceptances required to close the question
  conflict               boolean — true when disk and DB state diverge unresolvably
  conflict_disk_state    snapshot of file content at conflict time (nullable)
  conflict_db_state      snapshot of DB state at conflict time (nullable)
  org_id                 for multi-tenancy (present from day one)
  recorded_at            when this node entered the ledger (system clock)
  originated_at          when the underlying event actually happened (nullable — defaults to recorded_at)
```

Relationships between nodes are stored in a separate join table rather than columns on
Node. This supports fan-in — a node can have multiple parents, multiple dependencies,
and multiple cross-links without schema changes.

```
NodeEdge
  id          UUID
  parent_id   FK → Node
  child_id    FK → Node
  edge_type   contains | depends_on | refs
  ref_type    git_sha | vector_chunk_id | spec_path | node_id  (nullable — for refs edges only)
  primary     boolean — marks the canonical parent when a node has multiple contains edges
```

- `contains` — the parent owns the child. A beat belongs to a spec. A spec belongs to a PRD. A beat that satisfies both a spec *and* closes a bug has two `contains` edges, one marked `primary`.
- `depends_on` — the child cannot move to `in_progress` until the parent is `closed`. Crosses the containment tree freely.
- `refs` — a cross-link with no ownership or ordering semantics. A commit refs the git SHA it produced. A node refs a vector chunk from a related conversation.

This is a standard adjacency list in Postgres — two foreign keys and a type column. No graph database required.

A **question** is a node that declares intent or poses a problem. It is open until
explicitly closed. It can have child nodes — answers, or further questions spawned by
those answers.

An **answer** is a node that responds to a question. Answers are immutable once written.

Answers are one of two types:

- **Terminal** — closes the question, spawns no child questions. Work is done at this
  level. Example: a passing commit, a health check reading, a form submission response.
- **Generative** — closes the question, but spawns child questions that must be resolved
  before the parent tree is complete. Example: a PRD answers a pitch but generates spec
  questions; a spec answers a PRD question but generates beat questions.

A generative answer is a **shared understanding checkpoint** — it exists so that all
parties (human + human, human + agent) confirm they are solving the same problem before
work continues deeper. The `acceptance_threshold` enforces this: a PRD requires sign-off
from multiple parties before its child questions are opened.

Answers have an acceptance state:

```
Node (answer)
  accepted               true | false | pending
  accepted_by[]          who has accepted so far
  acceptance_threshold   how many must accept
```

A question is `closed` only when an answer's `accepted_by` count reaches its
`acceptance_threshold`. An answer with `accepted: false` is a **rebuttal** — it
re-opens the question. An answer with `accepted: pending` is a **candidate** — the
question remains open while verdicts are awaited.

This means answers can judge other answers. A test run is not an answer to the beat — it
is a verdict on the commit's claim to answer the beat:

```
beat (question, threshold: 1)
  └── commit (answer, terminal, pending)     ← candidate
      └── test run verdict (false)           ← rebuttal — beat re-opens
  └── commit (answer, terminal, pending)     ← new candidate
      └── test run verdict (true)            ← accepted — beat closes

pitch (question, threshold: 2)
  └── PRD (answer, generative, pending)      ← candidate
      └── human verdict (true)              ← 1 of 2
      └── agent verdict (true)              ← 2 of 2 — pitch closes, spec questions open
```

The same pattern covers code review: a review comment is a verdict of `false` on a
commit, re-opening the beat. An approval is a verdict of `true`.

## Scopes

Scope describes which layer of the stack a node lives at. It does not change the
primitive — it is a filter and a rendering hint.

| Scope | Questions look like | Answers look like |
|---|---|---|
| `intent` | Pitch, PRD question, spec question | PRD, spec, research finding, digest |
| `code` | Beat, spike, bug investigation | Commit, test run, fix |
| `deployment` | "Is this code running?", health check | Environment record, uptime reading |
| `ui` | Button, form, navigation element | Page render, form submission response |
| `interaction` | User action (implicit question: "what happens if I do this?") | System response, error, confirmation |

## How Existing Artifacts Map

| Artifact | Kind | Answer type | Scope | Notes |
|---|---|---|---|---|
| Pitch | question | — | intent | Root node — no parent |
| PRD | answer | generative | intent | Answers the pitch; spawns spec questions; threshold ≥ 2 |
| Spec | answer | generative | intent | Answers a PRD question; spawns beat questions; threshold ≥ 1 |
| Beat | question | — | code | A unit of work to be executed |
| Commit | answer | terminal | code | Closes a beat; threshold: 1 (test runner) |
| Spike | question | — | code | Time-boxed investigation question |
| Research log entry | answer | generative | code | Closes a spike; spawns follow-on questions if needed |
| Bug report | answer + question | — | code | Surfaces a problem; opens investigation question |
| Fix commit | answer | terminal | code | Closes the bug investigation question |
| Deployment | question | — | deployment | "Is this code running at this SHA?" |
| Health check | answer | terminal | deployment | Continuously re-answered; latest is current state |
| Page render | answer | terminal | ui | The system's answer to "what is the state of X?" |
| Button | question | — | ui | Pending — not yet asked |
| Form | question | — | ui | Structured question — fields are the question's shape |
| Form submission | answer | terminal | interaction | The form filled and sent |
| Error page | answer | terminal | interaction | A failed answer — spawns a bug question |
| Digest / summary | answer | terminal | any | Summarises a range of prior answers; does not close a question |

## Actor and ActorProfile

An `ActorProfile` is a reusable role definition — the config for how a class of agent
answers questions. An `Actor` is the instance — the assignment of a profile to a
specific node, with a record of what actually happened.

```
ActorProfile
  id
  name               e.g. "Ralph — build loop"
  provider           LLM provider
  model              LLM model
  allowed_tools[]    tools this actor is permitted to use
  prompt_template    nullable — falls back to PROMPT_{mode}.md

Actor
  id
  actor_profile_id   FK → ActorProfile
  node_id            FK → Node
  tools_used[]       actual tools used during execution (recorded after, not before)
```

`allowed_tools` is the permission boundary. `tools_used` is the audit record. The
difference matters for the reflect loop — it can compare what was permitted vs what was
actually needed, and tighten or loosen profiles over time.

A Node gets an Actor assigned when it moves to `in_progress`. The Actor record is
completed (tools_used populated) when the answer is posted.

## Stable Identity and Plan File Sync

Every node has a `stable_ref` — a content-derived identifier that survives re-syncs
from external sources (plan files, activity logs). It is computed as:

```
stable_ref = SHA256(normalize(title) + parent_id)
```

where `normalize` lowercases and strips punctuation.

This is used for idempotent sync: before creating a node, compute its `stable_ref` and
check if one already exists in the ledger under the same parent. If found, skip. If not,
create.

**Agent title drift** — an agent assigning slightly different titles to the same intent
("Add rate limiting to ingest" vs "Add rate limiting for ingest") will produce different
hashes and create duplicate nodes. This is an open research question — see Open
Questions. The interim mitigation is requiring agents to derive beat titles directly from
spec acceptance criteria text, which is stable and human-authored.

**Plan file sync** — when a plan file is synced into the ledger:
1. For each checkbox item: compute `stable_ref`, look up in ledger. If found, no-op. If not, create node.
2. For each node in the ledger sourced from this file: if its `stable_ref` is no longer present in the file, mark it `orphaned`.

Orphaned nodes are not deleted. They are flagged in the sync response and excluded from
the active queue. Resolution is manual.

**Backfill** — when backfilling from `specs/activity.md`: derive `stable_ref` from each
iteration entry title + project root node ID. Create a closed node only if no matching
`stable_ref` exists. Idempotent — re-running produces no duplicates.



The ledger is the ordered sequence of all nodes by `originated_at`. It is append-only.
Answers are never edited — corrections are new answer nodes that ref the node they
correct.

A **digest** is an answer node that summarises a range of prior nodes. It acts as a
checkpoint — the system can truncate nodes before the digest without losing meaning,
because the digest carries compressed state forward. This is what `activity.md` trimming
does, what a git squash does, what an accounting period close does.

## Ideas

Raw ideas live in `IDEAS.md` on disk before they become nodes. This file is
human-authored, git-tracked, and readable without the app.

```
Idea (in IDEAS.md)
  id
  title
  description
  status      parked | ready | promoted
  created_at
  promoted_at
```

Only `ready` ideas can be promoted. Promotion is atomic — it creates a question node
in the ledger (`scope: intent`) and updates `IDEAS.md` in the same operation. If either
fails, both are rolled back.

The DB mirrors `IDEAS.md` (parsed on file change) for UI display and querying. The file
is never replaced by the DB.



Common work item types and their canonical names. Use these everywhere — in node titles,
API responses, and UI labels.

| Type | Aliases avoided | Scope | Example |
|---|---|---|---|
| `project` | initiative | intent | "Build knowledge module" |
| `feature` | epic, story, ticket | intent | "User can search specs by query" |
| `spike` | research task | code | "Evaluate pgvector vs Qdrant" |
| `beat` | task, work_item | code | "Add ContextRetriever#retrieve" |
| `bug` | defect, issue | code | "Embedder silently swallows 429s" |

These are not a `type` field on Node — they are human labels that map to scope + context.
A `spike` is a question with scope `code` that produces a research answer. A `bug` is an
answer that spawns a question. The Node model is the same; the vocabulary is the lens.

## Refs

`refs` edges are cross-links with no ownership or ordering semantics. A node can ref
any number of other nodes. The `ref_type` on the `NodeEdge` record names what the
relationship is:

| ref_type | Example |
|---|---|
| `git_sha` | commit SHA that answered a beat |
| `vector_chunk_id` | knowledge base chunk from an LLM conversation |
| `spec_path` | on-disk file path associated with this node |
| `node_id` | any other node in the ledger |

Querying by ref: `SELECT parent_id FROM node_edges WHERE child_id = X AND edge_type = refs`.

## Disk ↔ DB Sync

Nodes with a `spec_path` have a corresponding file on disk. The file is the
human-readable view; the ledger is the authoritative state. The two are kept in sync by
`SpecWatcherJob`.

**File → DB** (file created or changed):
- Detect new or modified `specs/**/*.md` files (10-second poll in Phase 0)
- If no node exists for the path, create one (`scope: intent`, `status: open`)
- Parse the status header block and apply to the node
- Set `originated_at` to the file's mtime

**DB → File** (API or UI state change):
- On any status transition, rewrite the spec file header:
  ```
  **Status:** <status>
  **Version:** <version>
  **Last Updated:** <date>
  ```

**Conflict detection**:
- On every sync, compare file mtime vs `recorded_at`
- Last-write-wins — the newer side is applied to the older
- Exception: if the file's content SHA matches a previously seen older SHA (git revert),
  never auto-resolve. Set `conflict: true`, store both states, surface in conflict queue.

**Conflict resolution**:
- UI shows diff of `conflict_disk_state` vs `conflict_db_state`
- User chooses: "Use file" / "Use DB" / "Edit manually"
- Resolution clears `conflict` and writes chosen state to both sides atomically

**Deleted file**: node status set to `resolution: deferred`, record preserved.

After any file change, `Knowledge::IndexerJob` is triggered to keep the vector store current.

## Comments

Comments are answer nodes (scope: intent, terminal, threshold: 0) attached to any node.
They are append-only human or agent observations that don't belong in the spec file.

```
Comment (Node subtype)
  parent_id    FK → Node being commented on
  kind         answer
  answer_type  terminal
  scope        intent
  author       human | agent
  body         markdown
```

After a comment is saved, `Knowledge::IndexerJob` indexes the body as a single chunk
tagged with the parent node's ID. This makes comments available to `ContextRetriever`
for future LLM interactions scoped to that node tree.

Comments are immutable — no edits, no deletes. Corrections are new comments.



## Graph Structure

Nodes form a directed acyclic graph via `NodeEdge`. Two axes:

- **Contains** — ownership. A spec belongs to a PRD. A beat belongs to a spec. A node
  can have multiple `contains` parents — one is marked `primary` for display and
  `stable_ref` computation. Fan-in is valid: a beat that implements a spec *and* closes
  a bug has two `contains` edges.
- **Depends on** — ordering. A beat cannot start until its dependency is closed.
  Crosses the containment tree freely.

```
ledger-prd.md (question, intent)
├── ledger.md (question, intent)
│
└── beat: "build Node model" (question, code)
      contains ← ledger-prd.md  (primary)
      contains ← ledger.md
      depends_on → beat: "create DB schema"
```

## Status and Resolution

A question's status is derived from its answers and children:

| Status | Condition |
|---|---|
| `open` | No accepted answer yet, or last verdict was `false` |
| `in_progress` | Has a candidate answer with `accepted: pending` |
| `blocked` | Has one or more unresolved `depends_on` questions |
| `closed` | Has an accepted answer, or closed by human decision |

When a question closes, `resolution` records why:

| Resolution | Meaning |
|---|---|
| `done` | Closed by an accepted answer — work completed |
| `duplicate` | Same intent exists elsewhere in the ledger |
| `deferred` | Valid but not now — moved to icebox |
| `wont_do` | Explicitly out of scope, will not be answered |
| `icebox` | Paused indefinitely — excluded from active queue, preserved in history |

`done` is set automatically when an answer is accepted. All others are set by human
decision. Icebox and deferred questions can be re-opened; duplicate and wont_do cannot.

## Success Metrics

| Goal | Metric |
|---|---|
| Loop correctness | Loop never works on a question with unresolved dependencies |
| Dedup reliability | Zero duplicate nodes created from re-syncing an unchanged plan file |
| Status accuracy | Node status reflects reality within one loop iteration |
| Query performance | Next open question query responds in < 100ms under normal load |

## User Acceptance Tests

**UAT-1 — Question lifecycle**
1. Create a question node (open) with no dependencies
2. Assign an Actor → status becomes `in_progress`
3. Post a terminal answer (pending) → question remains `in_progress`
4. Submit a false verdict → answer rebutted, question re-opens
5. Post a new answer, submit true verdict → question closes, resolution: `done`

**UAT-2 — Dependency enforcement**
1. Create question A and question B (depends_on: A)
2. Query open unblocked questions → only A returned
3. Attempt to move B to `in_progress` → rejected, A not closed
4. Close A, then move B to `in_progress` → succeeds

**UAT-3 — Generative answer opens children**
1. Create a pitch question (threshold: 2)
2. Post a generative answer (PRD)
3. Submit one true verdict → answer still pending (1 of 2)
4. Submit second true verdict → pitch closes, child spec questions open

**UAT-4 — Plan file sync**
1. Sync a plan file with two unchecked and one checked item → 3 nodes created, checked item closed
2. Re-sync same file → no duplicate nodes created
3. Remove one item, re-sync → removed item flagged orphaned, not deleted

**UAT-5 — Activity log backfill**
1. Start with empty ledger, populate `specs/activity.md` with 3 iteration entries
2. Run backfill → 3 closed nodes created with `originated_at` set to iteration dates
3. Run backfill again → no new nodes created

**UAT-6 — Icebox**
1. Create a question, set resolution: `icebox` → question closes, excluded from active queue
2. Query open questions → icebox question not returned
3. Re-open icebox question → status returns to `open`, appears in queue

**UAT-7 — Disk ↔ DB conflict**
1. Edit a spec file and simultaneously update the same node via API
2. SpecWatcherJob detects divergence → `conflict: true` set on node
3. Conflict queue shows diff of both states
4. Choose "Use file" → DB updated, conflict cleared, both sides consistent

**UAT-8 — Comments**
1. POST a comment to a node → comment node created, body indexed as knowledge chunk
2. Query `ContextRetriever` with node ID → comment chunk returned alongside spec chunks
3. Attempt to edit or delete comment → rejected

## The Loop's Job

Find the oldest open question with scope `code` and no unresolved dependencies. Answer it.

The UI's job: render closed questions as text. Render open questions as interactive
elements. The frontier of open questions is the application's current state.

## Acceptance Criteria

- A node can be created as `question` or `answer` with any valid scope
- An answer node is immutable after creation
- An answer node is created with `accepted: pending` by default
- A terminal answer has no child questions — the system rejects child question creation on a terminal answer
- A generative answer may have child questions — they are opened once the answer is accepted
- Child questions of a generative answer are not opened until `accepted_by` count reaches `acceptance_threshold`
- An answer's `accepted_by` list grows as each party submits a verdict; `accepted` flips to `true` when threshold is reached
- An answer is rebutted (`accepted: false`) when any party submits a false verdict — this re-opens the parent question regardless of threshold
- A question is `closed` only when a child answer's `accepted_by` count reaches its `acceptance_threshold`
- A question re-opens (status → `open`) when its accepted answer is rebutted
- A failed test run submits a false verdict on the parent commit, re-opening the beat
- A passing test run submits a true verdict on the parent commit; if threshold met, beat closes
- A question cannot transition to `in_progress` while any `depends_on` question is not `closed`
- `refs[]` on a node returns all nodes that node cross-links to
- Querying by ref returns all nodes that ref a given node ID
- Querying by scope returns all nodes at that layer
- A digest node summarises a range of prior nodes without closing any question
- The ledger query returns all nodes ordered by `originated_at`
- Backfilled nodes set `originated_at` to the historical event time and `recorded_at` to the time of backfill
- Deleting a parent node orphans children — it does not cascade delete
- An error response node spawns a child bug question automatically
- `SpecWatcherJob` polls every 10 seconds and detects new, changed, and deleted spec files
- Deleted spec file → node `resolution` set to `deferred`, record preserved
- `SpecWatcherJob` triggers `Knowledge::IndexerJob` after any file change
- Last-write-wins sync: newer mtime overrides the older side
- Git revert detected (file SHA matches prior known SHA) → `conflict: true`, never auto-resolved
- Conflict queue surfaces diff of both states with resolve actions
- Resolving a conflict writes chosen state to both disk and DB atomically
- `version` increments on every status transition
- `org_id` present on all records from day one
- `GET /api/nodes` filters by scope, status, resolution, author, parent_id
- `POST /api/nodes/:id/comments` creates a comment node and triggers indexing
- Comment body indexed as a knowledge chunk tagged with parent node ID
- `ContextRetriever` with `node_id` returns relevant comment and spec chunks
- Unauthenticated requests return 401

## Open Questions

| Question | Notes |
|---|---|
| Agent title drift — SHA256 of normalized title + parent_id breaks when agents paraphrase the same intent. Semantic dedup (embedding similarity), fuzzy string matching, human-in-the-loop conflict flagging, and canonical title enforcement (titles derived from AC text) are all candidates. Needs a spike before stable_ref design is locked. | Run `./loop.sh research stable-ref` |

---

See [`prd.md`](prd.md) for intent, personas, scenarios, and success metrics.
