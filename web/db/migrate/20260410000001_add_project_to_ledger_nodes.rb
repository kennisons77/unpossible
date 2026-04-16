# frozen_string_literal: true

class AddProjectToLedgerNodes < ActiveRecord::Migration[8.0]
  def change
    add_column :ledger_nodes, :project, :string
    add_index :ledger_nodes, :project
  end
end
