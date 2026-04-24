# frozen_string_literal: true

class CreateAnalyticsLlmMetrics < ActiveRecord::Migration[8.0]
  def change
    create_table :analytics_llm_metrics, id: :uuid do |t|
      t.uuid :org_id, null: false
      t.string :provider, null: false
      t.string :model, null: false
      t.uuid :agent_run_id
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.decimal :cost_estimate_usd, precision: 10, scale: 6, null: false, default: 0

      t.timestamps
    end

    add_index :analytics_llm_metrics, %i[org_id provider model created_at], name: "idx_llm_metrics_org_provider_model"
  end
end
