# frozen_string_literal: true

class AddDurationMsToAnalyticsLlmMetrics < ActiveRecord::Migration[8.0]
  def change
    add_column :analytics_llm_metrics, :duration_ms, :integer
  end
end
