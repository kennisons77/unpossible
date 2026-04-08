# frozen_string_literal: true

class CreateLedgerNodeAuditEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :ledger_node_audit_events, id: :uuid do |t|
      t.uuid :node_id, null: false
      t.string :changed_by, null: false  # author enum: human | agent | system
      t.string :from_status
      t.string :to_status, null: false
      t.text :reason
      t.timestamptz :recorded_at, null: false
    end

    add_index :ledger_node_audit_events, :node_id
    add_index :ledger_node_audit_events, :recorded_at
  end
end
