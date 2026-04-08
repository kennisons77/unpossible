# frozen_string_literal: true

class RedesignLedgerNodeStatuses < ActiveRecord::Migration[8.0]
  def up
    # Status: replace old set with new unified set
    # Resolution: drop icebox, keep done/duplicate/deferred/wont_do
    # Acceptance: drop accepted, accepted_by, acceptance_threshold (acceptance is now a terminal answer node)
    # NodeEdge: add 'research' edge type (no schema change needed — edge_type is a string column)

    # Rename old status column, add new one, migrate data, drop old
    rename_column :ledger_nodes, :status, :status_old
    add_column :ledger_nodes, :status, :string

    execute <<~SQL
      UPDATE ledger_nodes SET status = CASE status_old
        WHEN 'open'        THEN 'proposed'
        WHEN 'in_progress' THEN 'in_progress'
        WHEN 'blocked'     THEN 'blocked'
        WHEN 'closed'      THEN 'closed'
        ELSE 'proposed'
      END
    SQL

    remove_column :ledger_nodes, :status_old

    # Resolution: remove icebox (migrate to deferred)
    execute "UPDATE ledger_nodes SET resolution = 'deferred' WHERE resolution = 'icebox'"

    # Drop acceptance columns
    remove_column :ledger_nodes, :accepted
    remove_column :ledger_nodes, :accepted_by
    remove_column :ledger_nodes, :acceptance_threshold

    # Update indexes
    remove_index :ledger_nodes, %i[org_id scope status], if_exists: true
    remove_index :ledger_nodes, %i[org_id scope level status], if_exists: true
    add_index :ledger_nodes, %i[org_id scope level status]
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
