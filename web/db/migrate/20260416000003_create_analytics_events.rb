# frozen_string_literal: true

class CreateAnalyticsEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_events, id: :uuid do |t|
      t.uuid :org_id, null: false
      t.string :distinct_id, null: false
      t.string :event_name, null: false
      t.string :node_id
      t.jsonb :properties, null: false, default: {}
      t.timestamptz :timestamp, null: false
      t.timestamptz :received_at, null: false
    end

    add_index :analytics_events, %i[org_id event_name timestamp]
    add_index :analytics_events, :node_id
  end
end
