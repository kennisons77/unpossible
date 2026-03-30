# Stories Module

## What It Does

Owns the lifecycle of all units of work — epics, spikes, stories, tasks, and bugs — as a self-referential tree of `Story` records in Postgres. The DB owns status state and transition history. Spec files on disk are the human-readable cache of that state. The two are kept in sync; conflicts are surfaced in the UI for human resolution.

## Why It Exists

Markdown files alone cannot reliably track status transitions, timestamps, or relationships between work items without depending on the LLM to remember to update them. Moving state ownership into Postgres makes transitions deterministic and auditable — the LLM completes work, the system handles bookkeeping.

## Work Item Type Lookup Table

"Task" is overloaded — it means different things to humans, agents, and the DB. Use these canonical type names everywhere:

| Type | Alias avoided | Scope | Example |
|---|---|---|---|
| `epic` | initiative, project | Large body of work spanning multiple cycles | "Build knowledge module" |
| `spike` | research task | Time-boxed investigation, produces a doc not code | "Evaluate pgvector vs Qdrant" |
| `story` | feature, ticket | A discrete user-facing capability | "User can search specs by query" |
| `work_item` | task | A single agent or human unit of work derived from a story | "Add ContextRetriever#retrieve" |
| `bug` | defect, issue | Unintended behaviour in shipped code | "Embedder silently swallows 429s" |

`work_item` replaces `task` in human-facing contexts. `Task` remains the Rails model name internally to avoid a migration conflict with the existing tasks module — see tasks.md.

---

## Story Schema

Each `Story` record stores:
- `id` — UUID primary key
- `item_type` — epic / spike / story / work_item / bug
- `title` and `description`
- `status` — idea / research / spec / planned / in_progress / complete / archived / blocked
- `version` — integer, incremented on each status transition
- `spec_path` — relative path to the associated spec file on disk (nullable)
- `parent_id` — self-referential FK (nullable — nil for root epics)
- `depends_on_ids` — array of Story IDs this story is blocked by
- `assignee_type` — human / agent (who does the work)
- `assignee_id` — FK to `User` or `AgentProfile` depending on `assignee_type` (polymorphic)
- `disk_updated_at` — timestamp of last detected file change
- `db_updated_at` — timestamp of last DB state change
- `conflict` — boolean flag, true when disk and DB state diverge unresolvably
- `conflict_disk_state` — snapshot of file header at conflict time
- `conflict_db_state` — snapshot of DB state at conflict time
- `org_id` — for future multi-tenancy

### Agent Assignment

An `AgentProfile` record represents a named agent configuration (e.g. "Ralph — build loop", "Researcher — spike loop"). Assigning a story to an agent profile determines which loop type and prompt template handle it. This is the bridge between the human-facing Stories model and the agent execution config in the Tasks module.

`AgentProfile` stores:
- `name` — human-readable label
- `loop_type` — plan / build / review / reflect / research
- `provider` and `model` — default LLM for this agent
- `allowed_tools` — default tool list

## Status State Machine

```
idea → research → spec → planned → in_progress → complete → archived
                                        ↓
                                     failed → planned (retry)
                                        ↓
                                     blocked (needs human input)
```

Transitions are owned by the Rails API and build loop callbacks — never by the LLM directly. Each transition appends a `StoryEvent` record (see Audit Log below).

## Relationships

- **Parent/child** — a Story belongs to at most one parent. An epic contains stories; a story contains tasks.
- **Depends on** — a Story can depend on N other stories. A story cannot transition to `in_progress` while any unresolved dependency is not `complete`.
- **Conversations** — `StoryConversation` join records link a Story to vector DB chunk IDs from LLM conversations.
- **Commits** — `StoryCommit` join records link a Story to git SHAs.

## File Watcher

`Stories::SpecWatcherJob` is a background job that monitors `specs/**/*.md` for changes and drives the disk → DB sync.

- Runs on a 10-second poll interval in Phase 0 (no inotify dependency)
- On new file: creates a Story record, parses status header if present, sets `disk_updated_at`
- On changed file: re-parses status header, applies last-write-wins logic against `db_updated_at`
- On deleted file: sets Story status to `archived`, does not delete the record
- Triggers `Knowledge::IndexerJob` after any change so the vector store stays current
- Idempotent — running twice on an unchanged file produces no side effects

Phase 2+: replace polling with a filesystem event listener (Listen gem or OS-level inotify).

---

## Disk ↔ DB Sync

### File → DB (spec created or changed)
- A file watcher detects new or modified `specs/**/*.md` files
- If no Story exists for the path, one is created (type defaults to `story`, status to `spec`)
- The status header block is parsed and used to seed the DB record
- `disk_updated_at` is set to the file's mtime

### DB → File (UI or API state change)
- On any status transition via the Rails API, the spec file header is rewritten:
  ```
  **Status:** <status>
  **Version:** <version>
  **Last Updated:** <date>
  ```
- `db_updated_at` is updated

### Conflict Detection
- On every sync event, compare `disk_updated_at` vs `db_updated_at`
- Last timestamp wins — the newer side is applied to the older
- **Exception — git revert:** if a file's content SHA matches a previously seen older SHA, the sync never auto-resolves. The conflict flag is set, both states are stored, and the story appears in the conflict queue in the UI.

### Conflict Resolution UI
- Rails dashboard surfaces all stories where `conflict: true`
- Shows a diff of `conflict_disk_state` vs `conflict_db_state`
- User chooses: "Use file" / "Use DB" / "Edit manually"
- Resolution clears the conflict flag and writes the chosen state to both sides

## Comments and Notes

`StoryComment` records append human or agent commentary to any Story. They are the primary mechanism for capturing reasoning, decisions, and observations that don't belong in the spec file itself.

### Schema

- `id` — UUID primary key
- `story_id` — FK to Story
- `author_type` — human / agent
- `author_id` — FK to `User` or `AgentProfile` (polymorphic)
- `body` — markdown text
- `created_at` — immutable once written
- `library_item_id` — FK to the `LibraryItem` chunk created when this comment was indexed (nullable until indexed)
- `org_id`

Comments are append-only — no edits, no deletes. Corrections are new comments.

### Indexing

After a comment is saved, `Knowledge::IndexerJob` indexes the `body` as a single `LibraryItem` chunk tagged with `story_id`. This makes the comment available to `ContextRetriever` for future LLM interactions scoped to that story tree.

Agent-authored comments (loop observations, reviewer notes, RALPH_WAITING explanations) are written via `POST /api/stories/:id/comments` with `author_type: agent`.

### Acceptance Criteria

- `POST /api/stories/:id/comments` creates a StoryComment and triggers indexing
- Comment body is indexed as a LibraryItem chunk with `story_id` set
- `ContextRetriever#retrieve` with `story_id` returns relevant comment chunks alongside spec chunks
- Comments are immutable — no update or destroy endpoints
- Agent can post comments with `author_type: agent` and a valid `AgentProfile` id
- Unauthenticated requests return 401

---

## Audit Log

`StoryEvent` records are append-only:
- `story_id`, `from_status`, `to_status`, `actor` (user ID or "agent"), `occurred_at`
- Never deleted, never updated

## Vector DB Integration

LLM conversations tagged with a `story_id` are indexed into the vector store with that tag. `ContextRetriever` accepts an optional `story_id` to scope retrieval to conversations and specs associated with a specific story tree.

## Acceptance Criteria

- `Stories::SpecWatcherJob` polls every 10 seconds and detects new, changed, and deleted spec files
- Deleted spec file → Story status set to `archived`, record preserved
- SpecWatcherJob triggers `Knowledge::IndexerJob` after any file change
- New spec file detected → Story record created with `item_type: story`, status `spec`, and `spec_path` set
- Last-write-wins sync: newer `disk_updated_at` overrides DB state and vice versa
- Git revert detected (file SHA matches prior known SHA) → conflict flag set, never auto-resolved
- Conflict queue in Rails UI shows diff of both states with resolve actions
- Resolving a conflict writes chosen state to both disk and DB atomically
- Story cannot transition to `in_progress` while a `depends_on` story is not `complete`
- `StoryConversation` links a story to vector DB chunk IDs
- `StoryCommit` links a story to a git SHA
- Assigning a story to an `AgentProfile` sets `assignee_type: agent` and `assignee_id`
- `AgentProfile` can be created with name, loop_type, provider, model, allowed_tools
- `GET /api/stories` filters by item_type, status, parent_id, assignee_id
- `POST /api/stories/:id/transition` advances status, appends StoryEvent, rewrites spec header
- Unauthenticated requests return 401
- `org_id` present on all records from day one
