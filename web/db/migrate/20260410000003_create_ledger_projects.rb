# frozen_string_literal: true

class CreateLedgerProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :ledger_projects, id: :uuid do |t|
      t.string :name, null: false
      t.text :description
      t.uuid :org_id, null: false
      t.timestamps
    end

    add_index :ledger_projects, %i[org_id name], unique: true

    add_column :ledger_nodes, :project_id, :uuid
    add_index :ledger_nodes, :project_id
    add_foreign_key :ledger_nodes, :ledger_projects, column: :project_id

    # Migrate existing string project data
    reversible do |dir|
      dir.up do
        # Ensure an "unpossible" project exists for every org
        execute <<~SQL
          INSERT INTO ledger_projects (id, name, org_id, created_at, updated_at)
          SELECT DISTINCT gen_random_uuid(), 'unpossible', org_id, NOW(), NOW()
          FROM ledger_nodes
          ON CONFLICT DO NOTHING
        SQL

        execute <<~SQL
          INSERT INTO ledger_projects (id, name, org_id, created_at, updated_at)
          SELECT DISTINCT gen_random_uuid(), project, org_id, NOW(), NOW()
          FROM ledger_nodes
          WHERE project IS NOT NULL
          ON CONFLICT DO NOTHING
        SQL

        # Backfill nodes that had a project string
        execute <<~SQL
          UPDATE ledger_nodes
          SET project_id = lp.id
          FROM ledger_projects lp
          WHERE ledger_nodes.project = lp.name
            AND ledger_nodes.org_id = lp.org_id
        SQL

        # Assign remaining nodes (no project string) to "unpossible"
        execute <<~SQL
          UPDATE ledger_nodes
          SET project_id = lp.id
          FROM ledger_projects lp
          WHERE ledger_nodes.project_id IS NULL
            AND lp.name = 'unpossible'
            AND ledger_nodes.org_id = lp.org_id
        SQL

        change_column_null :ledger_nodes, :project_id, false
      end
    end

    remove_index :ledger_nodes, :project
    remove_column :ledger_nodes, :project, :string
  end
end
