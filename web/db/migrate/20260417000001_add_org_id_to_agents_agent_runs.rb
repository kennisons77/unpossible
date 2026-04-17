# frozen_string_literal: true

class AddOrgIdToAgentsAgentRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :agents_agent_runs, :org_id, :uuid, null: false
    add_index :agents_agent_runs, :org_id
  end
end
