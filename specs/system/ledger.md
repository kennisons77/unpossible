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
  parent_id              FK → Node (nullable — root nodes have none)
  depends_on[]           FK → Node[] (questions only — must be closed before this opens)
  refs[]                 IDs of other nodes this node touches (cross-links)
  author                 human | agent | system
  status                 open | in_progress | blocked | closed  (questions only)
  accepted               true | false | pending  (answers only)
  accepted_by[]          author IDs who have accepted this answer
  acceptance_threshold   integer — how many acceptances required to close the question
  recorded_at            when this node entered the ledger (system clock)
  originated_at          when the underlying event actually happened (nullable — defaults to recorded_at)
```

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

## The Ledger

The ledger is the ordered sequence of all nodes by `originated_at`. It is append-only.
Answers are never edited — corrections are new answer nodes that ref the node they
correct.

A **digest** is an answer node that summarises a range of prior nodes. It acts as a
checkpoint — the system can truncate nodes before the digest without losing meaning,
because the digest carries compressed state forward. This is what `activity.md` trimming
does, what a git squash does, what an accounting period close does.

## Refs

A node can ref multiple other nodes. Refs make a node discoverable from multiple axes
without duplicating it. One commit can ref the beat it closes, the spec it satisfies,
and the bug it fixes. One error page can ref the route, the user session, and the beat
whose code produced it.

Every node has one **primary ref** (its parent — what it is fundamentally about) and
zero or more **secondary refs** (cross-links to other nodes it touches).

## Graph Structure

Nodes form a directed acyclic graph:

- **Parent/child** — containment. A spec belongs to a PRD. A beat belongs to a spec.
  A button belongs to a page. Containment is the tree axis.
- **Depends on** — ordering. A beat cannot start until its dependencies are closed.
  Dependencies can cross the tree — a beat in feature A can block a beat in feature B.
  A form cannot be submitted until a prior form is complete. This is the DAG axis.

```
project (question, intent)
└── feature (question, intent)
    ├── beat (question, code)  →  commit (answer, closes beat)
    ├── beat (question, code)  depends_on: [prior beat]
    └── bug (answer+question, code)  →  fix commit (answer, closes bug)

deployment (question, deployment)
└── environment (answer, deployment)
    └── health check (answer, deployment)  — re-answered continuously

page (answer, ui)
├── button (question, ui)  →  interaction (answer)
└── form (question, ui)
    └── submission (answer, interaction)
        └── error (answer, interaction)  →  bug (question, code)
```

## Status

A question's status is derived from its answers and children:

| Status | Condition |
|---|---|
| `open` | No accepted answer yet, or last verdict was `false` |
| `in_progress` | Has a candidate answer with `accepted: pending` |
| `blocked` | Has one or more unresolved `depends_on` questions |
| `closed` | Has an answer with `accepted: true` |

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
