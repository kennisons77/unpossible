# frozen_string_literal: true

FactoryBot.define do
  factory :analytics_event, class: 'Analytics::AnalyticsEvent' do
    org_id { SecureRandom.uuid }
    distinct_id { SecureRandom.uuid }
    sequence(:event_name) { |n| "test.event_#{n}" }
    properties { {} }
    timestamp { Time.current }
    received_at { Time.current }
  end
end
