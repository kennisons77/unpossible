# Sandbox Module — Rails Platform Override

Extends `specifications/sandbox.md`. Rails-specific implementation details only.

## Model
- `Sandbox::ContainerRun` — ActiveRecord, `app/modules/sandbox/models/container_run.rb`
- `status` enum: `pending / running / complete / failed`
- `duration` computed from `started_at` / `finished_at`

## Service
- `Sandbox::DockerDispatcher` — shells out to `docker run --rm`, command as argument array

## Files
- `web/app/modules/sandbox/models/container_run.rb`
- `web/app/modules/sandbox/services/docker_dispatcher.rb`

## Rails-specific Acceptance Criteria
- `ContainerRun` status enum validates
- `ContainerRun` record created before dispatch, updated with final status after
- `agent_run_id` is nullable at the DB level
