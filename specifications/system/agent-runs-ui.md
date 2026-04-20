---
name: agent-runs-ui
kind: concept
status: proposed
description: Browse agent run history, inspect turns, see cost breakdowns in a browser
modules: [agents]
---

# Agent Runs UI

## Problem

Agent run history, turn content, and cost/token data are only accessible via API.
There is no way to browse runs, inspect turns, or see cost breakdowns in a browser.

## Views

### Run History — `GET /agent_runs`
- Paginated list of agent runs, most recent first
- Columns: mode, status, provider/model, input/output tokens, cost, duration, created_at
- Filterable by mode and status

### Run Detail — `GET /agent_runs/:id`
- Run metadata (mode, status, provider, model, cost, duration)
- Ordered list of turns with kind badge (agent_question, human_input, llm_response, tool_result)
- Turn content rendered as markdown
- Link to parent run if present
- `source_ref` displayed if present

## Constraints

- Server-rendered HTML (ERB), no JS framework
- Reuse existing layout and styling patterns
- Auth follows the same pattern as ApplicationController (authenticate!, bypassable with DISABLE_AUTH)
