# frozen_string_literal: true

module Agents
  class AgentRunTurn < ApplicationRecord
    self.table_name = 'agents_agent_run_turns'

    KINDS = %w[agent_question human_input llm_response tool_result].freeze

    belongs_to :agent_run, class_name: 'Agents::AgentRun'

    validates :position, presence: true
    validates :kind, presence: true, inclusion: { in: KINDS }
    validates :content, presence: true
  end
end
