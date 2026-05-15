# frozen_string_literal: true

class AddModeToAnalyticsLlmMetrics < ActiveRecord::Migration[8.0]
  def change
    add_column :analytics_llm_metrics, :mode, :string
  end
end
