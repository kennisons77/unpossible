# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into version control.

ActiveRecord::Schema[8.0].define(version: 2026_04_18_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgvector"
  enable_extension "plpgsql"

  create_table "agents_agent_run_turns", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "agent_run_id", null: false
    t.integer "position", null: false
    t.string "kind", null: false
    t.text "content"
    t.datetime "purged_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_run_id", "position"], name: "index_agents_agent_run_turns_on_agent_run_id_and_position", unique: true
  end

  create_table "agents_agent_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "run_id", null: false
    t.uuid "parent_run_id"
    t.string "mode", null: false
    t.string "provider", null: false
    t.string "model", null: false
    t.string "prompt_sha256"
    t.string "status", null: false, default: "running"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.decimal "cost_estimate_usd", precision: 10, scale: 6
    t.integer "duration_ms"
    t.boolean "response_truncated", default: false
    t.jsonb "source_node_ids", null: false, default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "source_ref"
    t.uuid "org_id", null: false
    t.boolean "agent_override", null: false, default: false
    t.index ["org_id"], name: "index_agents_agent_runs_on_org_id"
    t.index ["parent_run_id"], name: "index_agents_agent_runs_on_parent_run_id"
    t.index ["prompt_sha256", "mode"], name: "idx_agent_runs_dedup"
    t.index ["run_id"], name: "index_agents_agent_runs_on_run_id", unique: true
  end

  create_table "analytics_audit_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "org_id", null: false
    t.string "event_name", null: false
    t.string "severity", null: false
    t.jsonb "properties", null: false, default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["org_id", "created_at"], name: "index_analytics_audit_events_on_org_id_and_created_at"
  end

  create_table "analytics_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "org_id", null: false
    t.string "distinct_id", null: false
    t.string "event_name", null: false
    t.string "node_id"
    t.jsonb "properties", null: false, default: {}
    t.timestamptz "timestamp", null: false
    t.timestamptz "received_at", null: false
    t.index ["node_id"], name: "index_analytics_events_on_node_id"
    t.index ["org_id", "event_name", "timestamp"], name: "index_analytics_events_on_org_id_and_event_name_and_timestamp"
  end

  create_table "analytics_feature_flags", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.boolean "enabled", null: false, default: false
    t.string "variant"
    t.jsonb "metadata", default: {}
    t.string "status", null: false, default: "active"
    t.uuid "org_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["org_id", "key"], name: "idx_feature_flags_org_key", unique: true
    t.index ["org_id"], name: "index_analytics_feature_flags_on_org_id"
  end

  create_table "analytics_llm_metrics", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "org_id", null: false
    t.string "provider", null: false
    t.string "model", null: false
    t.uuid "agent_run_id"
    t.integer "input_tokens", null: false, default: 0
    t.integer "output_tokens", null: false, default: 0
    t.decimal "cost_estimate_usd", precision: 10, scale: 6, null: false, default: "0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["org_id", "provider", "model", "created_at"], name: "index_analytics_llm_metrics_on_org_id_and_provider_and_model_and_created_at"
  end

  create_table "sandbox_container_runs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "image", null: false
    t.text "command", null: false
    t.string "status", null: false, default: "pending"
    t.integer "exit_code"
    t.text "stdout"
    t.text "stderr"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.uuid "agent_run_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "org_id", null: false
    t.index ["agent_run_id"], name: "index_sandbox_container_runs_on_agent_run_id"
    t.index ["org_id"], name: "index_sandbox_container_runs_on_org_id"
    t.index ["status"], name: "index_sandbox_container_runs_on_status"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  add_foreign_key "agents_agent_run_turns", "agents_agent_runs", column: "agent_run_id"
  add_foreign_key "sandbox_container_runs", "agents_agent_runs", column: "agent_run_id"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
