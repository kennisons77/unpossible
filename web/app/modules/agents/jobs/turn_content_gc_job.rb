# frozen_string_literal: true

module Agents
  class TurnContentGcJob < ApplicationJob
    queue_as :agents

    RETENTION_DAYS = 30

    def perform(retention_days: RETENTION_DAYS)
      cutoff = retention_days.days.ago

      # Only purge turns belonging to completed runs older than the cutoff.
      # Failed and waiting_for_input runs are never purged — content may still be needed.
      purgeable_run_ids = AgentRun
        .where(status: "completed")
        .where(updated_at: ...cutoff)
        .pluck(:id)

      return if purgeable_run_ids.empty?

      AgentRunTurn
        .where(agent_run_id: purgeable_run_ids)
        .where(purged_at: nil)
        .in_batches
        .update_all(purged_at: Time.current, content: nil)
    end
  end
end
