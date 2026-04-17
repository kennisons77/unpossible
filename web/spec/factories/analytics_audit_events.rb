# frozen_string_literal: true

FactoryBot.define do
  factory :analytics_audit_event, class: 'Analytics::AuditEvent' do
    org_id { SecureRandom.uuid }
    sequence(:event_name) { |n| "test.audit_event_#{n}" }
    severity { 'info' }
    properties { {} }
  end
end
