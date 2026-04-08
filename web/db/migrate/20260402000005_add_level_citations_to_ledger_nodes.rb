# frozen_string_literal: true

class AddLevelCitationsToLedgerNodes < ActiveRecord::Migration[8.0]
  def change
    # level: sub-scope for intent nodes — ideology | concept | practice | specification
    # nil is valid for non-intent scopes
    add_column :ledger_nodes, :level, :string
    add_column :ledger_nodes, :citations, :jsonb, null: false, default: []

    add_index :ledger_nodes, %i[org_id scope level status]
  end
end
