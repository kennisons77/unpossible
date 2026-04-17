# frozen_string_literal: true

# Drop knowledge table (has FK to ledger_nodes) and all ledger tables.
# FK from agents_agent_runs removed in prior migration.
class DropLedgerAndKnowledgeTables < ActiveRecord::Migration[8.0]
  def up
    drop_table :knowledge_library_items, if_exists: true
    drop_table :ledger_node_audit_events, if_exists: true
    drop_table :ledger_actors, if_exists: true
    drop_table :ledger_node_edges, if_exists: true
    drop_table :ledger_nodes, if_exists: true
    drop_table :ledger_actor_profiles, if_exists: true
    drop_table :ledger_projects, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
