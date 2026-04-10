# frozen_string_literal: true

module Sandbox
  class ContainerRun < ApplicationRecord
    self.table_name = "sandbox_container_runs"

    STATUSES = %w[pending running complete failed].freeze

    belongs_to :agent_run, class_name: "Agents::AgentRun", optional: true

    validates :image, presence: true
    validates :command, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }

    def duration_ms
      return nil unless started_at && finished_at

      ((finished_at - started_at) * 1000).to_i
    end
  end
end
