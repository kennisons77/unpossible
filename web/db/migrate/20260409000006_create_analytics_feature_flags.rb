# frozen_string_literal: true

class CreateAnalyticsFeatureFlags < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_feature_flags, id: :uuid do |t|
      t.string :key, null: false
      t.boolean :enabled, null: false, default: false
      t.string :variant
      t.jsonb :metadata, default: {}
      t.string :status, null: false, default: 'active'
      t.uuid :org_id, null: false

      t.timestamps
    end

    add_index :analytics_feature_flags, %i[org_id key], unique: true, name: 'idx_feature_flags_org_key'
    add_index :analytics_feature_flags, :org_id
  end
end
