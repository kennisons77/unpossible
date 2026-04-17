# frozen_string_literal: true

class AddOrgIdToSandboxContainerRuns < ActiveRecord::Migration[8.0]
  def change
    add_column :sandbox_container_runs, :org_id, :uuid, null: false
    add_index :sandbox_container_runs, :org_id
  end
end
