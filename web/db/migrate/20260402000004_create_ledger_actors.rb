# frozen_string_literal: true

class CreateLedgerActors < ActiveRecord::Migration[8.0]
  def change
    create_table :ledger_actors, id: :uuid do |t|
      t.references :actor_profile, null: false, type: :uuid, foreign_key: { to_table: :ledger_actor_profiles }
      t.references :node, null: false, type: :uuid, foreign_key: { to_table: :ledger_nodes }
      t.jsonb :tools_used, null: false, default: []

      t.datetime :created_at, null: false
    end
  end
end
