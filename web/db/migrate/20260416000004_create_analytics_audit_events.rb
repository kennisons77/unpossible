# frozen_string_literal: true

class CreateAnalyticsAuditEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_audit_events, id: :uuid do |t|
      t.uuid :org_id, null: false
      t.string :event_name, null: false
      t.string :severity, null: false
      t.jsonb :properties, null: false, default: {}

      t.timestamps
    end

    add_index :analytics_audit_events, %i[org_id created_at]
  end
end
