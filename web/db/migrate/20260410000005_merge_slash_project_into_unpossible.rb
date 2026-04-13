# frozen_string_literal: true

class MergeSlashProjectIntoUnpossible < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE ledger_nodes
      SET project_id = up.id
      FROM ledger_projects up, ledger_projects slash
      WHERE slash.name = '/'
        AND up.name = 'unpossible'
        AND up.org_id = slash.org_id
        AND ledger_nodes.project_id = slash.id
    SQL

    execute "DELETE FROM ledger_projects WHERE name = '/'"
  end

  def down
    # irreversible
  end
end
