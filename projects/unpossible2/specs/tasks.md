# Tasks Module

## What It Does

Owns the task schema that drives agent asks. The task record — not the LLM — determines which tools are available, which model to use, and which prompt template to apply. Parses `IMPLEMENTATION_PLAN.md` into structured task records after each plan loop.

## Why It Exists

Currently tasks live only in markdown and the LLM decides everything about how to execute them. This is non-deterministic. Moving task configuration into a schema means the system controls tool selection and model choice, not the agent.

## Task Schema

Each task record stores:
- `title` and `description` — from the plan checkbox
- `status` — pending / in_progress / complete / failed
- `loop_type` — plan / build / review / reflect
- `provider` and `model` — which LLM to use (overridable per task)
- `prompt_template` — provider-tailored prompt (nullable — falls back to PROMPT_{mode}.md)
- `reviewer_provider` and `reviewer_model` — for the producer/reviewer pattern
- `allowed_tools` — jsonb array of tool names the agent may use
- `task_ref` — SHA256 of the checkbox text, used to match back to IMPLEMENTATION_PLAN.md

## Plan Parsing

`Tasks::PlanParserJob` runs after each plan loop completes. It:
1. Reads `IMPLEMENTATION_PLAN.md` from the configured workspace path
2. Parses `- [ ]` and `- [x]` checkboxes
3. Upserts task records keyed on `task_ref`
4. Preserves manually set `provider`/`model` overrides — does not overwrite them on re-parse

MD remains the source of truth. The DB is the query layer.

## Promote Flow

`POST /api/tasks/:id/promote` advances a task/idea to the next stage. This is the API equivalent of `./loop.sh promote <id>`. The shell command becomes a thin wrapper calling this endpoint.

## Acceptance Criteria

- Unchecked plan item → task with status: pending
- Checked plan item → task with status: complete
- Re-running PlanParserJob is idempotent
- Manually set provider/model on a task is not overwritten by re-parse
- Malformed IMPLEMENTATION_PLAN.md logs a warning and continues — does not raise
- `GET /api/tasks` filters by status and loop_type
- `POST /api/tasks/:id/promote` changes status to in_progress
- Unauthenticated requests return 401
