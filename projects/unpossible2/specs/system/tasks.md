# Tasks Module

## What It Does

Owns the task schema that drives agent execution. The task record — not the LLM — determines which tools are available, which model to use, and which prompt template to apply. Parses `IMPLEMENTATION_PLAN.md` into structured task records after each plan loop.

## Why It Exists

Tasks living only in markdown means the LLM decides everything about how to execute them. Moving task configuration into a schema makes tool selection and model choice deterministic — controlled by the system, not the agent.

## Task Schema

Each task record stores:
- `title` and `description` — from the plan checkbox
- `status` — pending / in_progress / complete / failed / blocked
- `loop_type` — plan / build / review / reflect / research
- `provider` and `model` — which LLM to use (overridable per task)
- `prompt_template` — provider-tailored prompt (nullable — falls back to `PROMPT_{mode}.md`)
- `reviewer_provider` and `reviewer_model` — for the producer/reviewer pattern
- `allowed_tools` — list of tool names the agent may use for this task
- `task_ref` — stable identifier derived from the checkbox text (SHA256)
- `depends_on_ids` — list of task refs this task depends on

## Plan Parsing

A plan parser job runs after each plan loop completes. It:
1. Reads `IMPLEMENTATION_PLAN.md` from the configured workspace path
2. Parses `- [ ]` (pending) and `- [x]` (complete) checkboxes
3. Upserts task records keyed on `task_ref`
4. Preserves manually set `provider`/`model` overrides — does not overwrite them on re-parse

MD remains the source of truth. The database is the query layer.

## Promote Flow

`POST /api/tasks/:id/promote` advances a task to the next stage. The shell command `./loop.sh promote <id>` is a thin wrapper calling this endpoint.

## Acceptance Criteria

- Unchecked plan item → task with status: pending
- Checked plan item → task with status: complete
- Re-running the plan parser is idempotent
- Manually set provider/model on a task is not overwritten by re-parse
- Malformed `IMPLEMENTATION_PLAN.md` logs a warning and continues — does not raise
- `GET /api/tasks` filters by status and loop_type
- `POST /api/tasks/:id/promote` changes status to in_progress
- Unauthenticated requests return 401
