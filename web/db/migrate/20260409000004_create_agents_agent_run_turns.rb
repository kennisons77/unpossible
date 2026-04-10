# frozen_string_literal: true

class CreateAgentsAgentRunTurns < ActiveRecord::Migration[8.0]
  def change
    create_table :agents_agent_run_turns, id: :uuid do |t|
      t.references :agent_run, null: false, type: :uuid, foreign_key: { to_table: :agents_agent_runs }
      t.integer :position, null: false
      t.string :kind, null: false
      t.text :content, null: false
      t.datetime :purged_at, null: true

      t.timestamps
    end

    add_index :agents_agent_run_turns, %i[agent_run_id position], unique: true
  end
end
