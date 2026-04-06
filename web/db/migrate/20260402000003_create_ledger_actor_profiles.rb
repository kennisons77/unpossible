# frozen_string_literal: true

class CreateLedgerActorProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :ledger_actor_profiles, id: :uuid do |t|
      t.string :name, null: false
      t.string :provider, null: false
      t.string :model, null: false
      t.jsonb :allowed_tools, null: false, default: []
      t.text :prompt_template
      t.uuid :org_id, null: false

      t.timestamps
    end

    add_index :ledger_actor_profiles, :org_id
  end
end
