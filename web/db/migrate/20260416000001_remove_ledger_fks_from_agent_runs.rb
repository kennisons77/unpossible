# frozen_string_literal: true

# Remove FK columns pointing to ledger tables before those tables are dropped.
# Replaces actor_id + node_id (UUID FKs) with source_ref (string, nullable).
class RemoveLedgerFksFromAgentRuns < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :agents_agent_runs, column: :actor_id
    remove_foreign_key :agents_agent_runs, column: :node_id
    remove_column :agents_agent_runs, :actor_id, :uuid
    remove_column :agents_agent_runs, :node_id, :uuid
    add_column :agents_agent_runs, :source_ref, :string
  end
end
