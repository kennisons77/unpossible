# frozen_string_literal: true

module Analytics
  class LlmMetric < ApplicationRecord
    self.table_name = 'analytics_llm_metrics'

    validates :org_id, presence: true
    validates :provider, presence: true
    validates :model, presence: true
    validates :cost_estimate_usd, presence: true

    def update(*)
      raise NotImplementedError, 'LlmMetric is append-only'
    end

    def update!(*)
      raise NotImplementedError, 'LlmMetric is append-only'
    end

    def destroy
      raise NotImplementedError, 'LlmMetric is append-only'
    end

    def destroy!
      raise NotImplementedError, 'LlmMetric is append-only'
    end
  end
end
