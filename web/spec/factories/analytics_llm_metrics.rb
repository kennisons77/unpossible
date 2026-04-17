# frozen_string_literal: true

FactoryBot.define do
  factory :analytics_llm_metric, class: 'Analytics::LlmMetric' do
    org_id { SecureRandom.uuid }
    sequence(:provider) { |n| "provider_#{n}" }
    sequence(:model) { |n| "model_#{n}" }
    input_tokens { 100 }
    output_tokens { 50 }
    cost_estimate_usd { 0.001234 }
  end
end
