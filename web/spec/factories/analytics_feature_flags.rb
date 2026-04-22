# frozen_string_literal: true

FactoryBot.define do
  factory :analytics_feature_flag, class: 'Analytics::FeatureFlag' do
    sequence(:key) { |n| "module.feature_#{n}" }
    enabled { false }
    status { 'active' }
    org_id { SecureRandom.uuid }
    metadata { { 'hypothesis' => 'Default test hypothesis' } }
  end
end
