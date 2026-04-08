# frozen_string_literal: true

class CreateLedgerNodes < ActiveRecord::Migration[8.0]
  def change
    create_table :ledger_nodes, id: :uuid do |t|
      t.string :kind, null: false
      t.string :answer_type
      t.string :scope, null: false
      t.text :body, null: false
      t.string :title
      t.string :spec_path
      t.string :author, null: false
      t.string :stable_ref, null: false
      t.integer :version, null: false, default: 1
      t.string :status
      t.string :resolution
      t.string :accepted
      t.jsonb :accepted_by, null: false, default: []
      t.integer :acceptance_threshold, null: false, default: 1
      t.boolean :conflict, null: false, default: false
      t.text :conflict_disk_state
      t.text :conflict_db_state
      t.uuid :org_id, null: false
      t.timestamptz :recorded_at, null: false
      t.timestamptz :originated_at

      t.timestamps
    end

    add_index :ledger_nodes, :stable_ref
    add_index :ledger_nodes, %i[org_id scope status]
  end
end
