# frozen_string_literal: true

class CreateSandboxContainerRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :sandbox_container_runs, id: :uuid do |t|
      t.string :image, null: false
      t.text :command, null: false
      t.string :status, null: false, default: "pending"
      t.integer :exit_code
      t.text :stdout
      t.text :stderr
      t.datetime :started_at
      t.datetime :finished_at
      t.references :agent_run, null: true, type: :uuid, foreign_key: { to_table: :agents_agent_runs }

      t.timestamps
    end

    add_index :sandbox_container_runs, :status
  end
end
