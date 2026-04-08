# frozen_string_literal: true

class CreateLedgerNodeEdges < ActiveRecord::Migration[8.0]
  def change
    create_table :ledger_node_edges, id: :uuid do |t|
      t.uuid :parent_id, null: false
      t.uuid :child_id, null: false
      t.string :edge_type, null: false
      t.string :ref_type
      t.boolean :primary, null: false, default: false

      t.timestamps
    end

    add_foreign_key :ledger_node_edges, :ledger_nodes, column: :parent_id
    add_foreign_key :ledger_node_edges, :ledger_nodes, column: :child_id
    add_index :ledger_node_edges, %i[parent_id edge_type]
    add_index :ledger_node_edges, %i[child_id edge_type]
  end
end
