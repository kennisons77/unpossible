# frozen_string_literal: true

module Agents
  class AgentRun < ApplicationRecord
    self.table_name = 'agents_agent_runs'

    MODES = %w[plan build review reflect research].freeze
    STATUSES = %w[running waiting_for_input completed failed].freeze

    belongs_to :actor, class_name: 'Ledger::Actor'
    belongs_to :node, class_name: 'Ledger::Node'
    has_many :turns, class_name: 'Agents::AgentRunTurn', dependent: :destroy

    validates :run_id, presence: true, uniqueness: true
    validates :mode, presence: true, inclusion: { in: MODES }
    validates :provider, presence: true
    validates :model, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
  end
end
