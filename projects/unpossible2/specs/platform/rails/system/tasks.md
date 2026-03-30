# Tasks Module — Rails Platform Override

Extends `specs/tasks.md`. Rails-specific implementation details only.

## Models
- `Task` — ActiveRecord model under `app/modules/tasks/models/task.rb`
- `Idea` — ActiveRecord model under `app/modules/tasks/models/idea.rb`
- `task_ref` is SHA256 of checkbox text, used as upsert key

## Background Jobs
- `Tasks::PlanParserJob` — Active Job, enqueued on `tasks` queue via Solid Queue
- `Tasks::IdeaParserJob` — parses `IDEAS.md`, upserts `Idea` records

## Schema Details
- `allowed_tools` — jsonb array, default `[]`
- `depends_on_ids` — jsonb array, default `[]`
- `task_ref` — string, indexed

## Controllers
- `Tasks::TasksController` — index (filter by status, loop_type), show, update, promote
- `Tasks::IdeasController` — index, show, promote

## Files
- `app/app/modules/tasks/models/task.rb`
- `app/app/modules/tasks/models/idea.rb`
- `app/app/modules/tasks/jobs/plan_parser_job.rb`
- `app/app/modules/tasks/services/plan_parser.rb`
- `app/app/modules/tasks/controllers/tasks/tasks_controller.rb`
- `app/app/modules/tasks/controllers/tasks/ideas_controller.rb`

## Rails-specific Acceptance Criteria
- `Task` enum validates status and loop_type
- `allowed_tools` and `depends_on_ids` default to `[]` at the DB level
- `PlanParserJob` enqueued on `tasks` queue
- `POST /api/ideas/:id/promote` creates spec file and updates `IDEAS.md` atomically
- Promoting a non-ready idea returns 422
