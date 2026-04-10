# frozen_string_literal: true

class CreateAgentsAgentRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :agents_agent_runs, id: :uuid do |t|
      t.uuid :run_id, null: false
      t.references :actor, null: false, type: :uuid, foreign_key: { to_table: :ledger_actors }
      t.references :node, null: false, type: :uuid, foreign_key: { to_table: :ledger_nodes }
      t.uuid :parent_run_id, null: true
      t.string :mode, null: false
      t.string :provider, null: false
      t.string :model, null: false
      t.string :prompt_sha256
      t.string :status, null: false, default: 'running'
      t.integer :input_tokens
      t.integer :output_tokens
      t.decimal :cost_estimate_usd, precision: 10, scale: 6
      t.integer :duration_ms
      t.boolean :response_truncated, default: false
      t.jsonb :source_node_ids, null: false, default: []

      t.timestamps
    end

    add_index :agents_agent_runs, :run_id, unique: true
    add_index :agents_agent_runs, :parent_run_id
    add_index :agents_agent_runs, %i[prompt_sha256 mode], name: 'idx_agent_runs_dedup'
  end
end
