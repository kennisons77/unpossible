# frozen_string_literal: true

module Agents
  class AgentRun < ApplicationRecord
    self.table_name = 'agents_agent_runs'

    MODES = %w[plan build review reflect research].freeze
    STATUSES = %w[running waiting_for_input completed failed].freeze

    has_many :turns, class_name: 'Agents::AgentRunTurn', dependent: :destroy

    validates :org_id, presence: true
    validates :run_id, presence: true, uniqueness: true
    validates :mode, presence: true, inclusion: { in: MODES }
    validates :provider, presence: true
    validates :model, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
  end
end
