---
name: prd-to-tasks
command: make prd-to-tasks
description: Break a PRD into vertical-slice tasks in the task system
model: sonnet
loop_type: plan
principles: [planning]
---

Read the PRD file provided and break it into tasks. Write each task to the task system via the API at `$UNPOSSIBLE_API_URL`.

## Process

1. **Read the PRD** — locate and read the PRD file. Identify all acceptance criteria.
2. **Explore the codebase** — understand what already exists. Do not create tasks for completed work.
3. **Draft vertical slices** — each task must cut through all integration layers (data, logic, interface). No horizontal slices. The first task should be a tracer bullet: the thinnest possible end-to-end slice that proves the integration works.
4. **Identify dependencies** — for each task, note which other tasks it depends on. Record as `depends_on_ids`.
5. **Confirm with user** — present the full task list before writing anything. Get approval.
6. **Write tasks** — POST each task to `$UNPOSSIBLE_API_URL/api/tasks`. Include title, description, acceptance criteria, `depends_on_ids`, and `loop_type`.

## Task Shape

```json
{
  "title": "",
  "description": "",
  "acceptance_criteria": "",
  "loop_type": "build",
  "depends_on_ids": [],
  "allowed_tools": []
}
```

Do not mark any task complete. Do not write any code.
