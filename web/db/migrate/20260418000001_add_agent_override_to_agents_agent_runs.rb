# frozen_string_literal: true

class AddAgentOverrideToAgentsAgentRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :agents_agent_runs, :agent_override, :boolean, null: false, default: false
  end
end
