> **SUPERSEDED by `specs/system/reference-graph/spec.md`**

# Ledger UI

- **Status:** Draft
- **Created:** 2026-04-02

## Intent

Read-only views of the ledger for human review. No editing — state changes happen via
API or the loop. The goal is to make the question/answer hierarchy navigable without
tribal knowledge.

## Three Views

### Current

The active node the loop is executing against, plus its full ancestor chain.

- Shows the in-progress question (scope: code, status: in_progress)
- Renders each ancestor node from root to leaf as a collapsible markdown block
- Each ancestor shows: title, level (if intent), status, author, recorded_at
- Citations rendered as inline links below the body
- Audit trail for the active node shown as a timestamped list at the bottom

### Open

All non-closed questions, filterable and browsable.

- Default sort: oldest `originated_at` first
- Filters: scope, level (intent only), status (proposed/refining/in_review/accepted/in_progress/blocked), author, has_blockers (yes/no)
- Each row: title, scope, level, status, originated_at, blocker count
- Clicking a row navigates to the node detail page

### Condensed

Full project tree, collapsible, with text search.

- Root nodes (no parent) listed at top level
- Each node expandable to show children (contains edges)
- Closed nodes collapsed by default; non-closed nodes expanded
- Text search filters the visible tree by title and body
- Clicking any node navigates to the node detail page

## Node Detail Page

Reachable from any view. URL: `/ledger/nodes/:id`

- Title, scope, level, kind, status, resolution, author, recorded_at, originated_at
- Body rendered as markdown (fenced code blocks syntax-highlighted)
- Citations listed as: `[label](url)` — one per line
- Parent chain: breadcrumb of `contains` ancestors up to root
- Children: linked list of child nodes (title + status)
- Depends-on: linked list of dependency nodes (title + status)
- Refs: linked list of cross-linked nodes (title + ref_type)
- Audit trail: table of NodeAuditEvents — from_status → to_status, changed_by, reason, recorded_at

## Acceptance Criteria

- All three views render without JS (server-rendered HTML)
- Markdown body rendered with syntax-highlighted fenced code blocks
- Citations render as hyperlinks
- Audit trail present on every node detail page
- Text search in condensed view filters by title and body (case-insensitive, no full-text index required in Phase 0)
- Unauthenticated requests redirect to login

## Out of Scope (Phase 0)

- Editing nodes in the UI
- Invalidation / verdict submission in the UI
- Real-time updates (no websockets)
- Multi-project switching (single org, single project)
