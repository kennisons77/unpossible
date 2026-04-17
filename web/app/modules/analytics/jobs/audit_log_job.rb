# frozen_string_literal: true

module Analytics
  class AuditLogJob < ApplicationJob
    queue_as :analytics

    def perform(org_id:, event_name:, severity:, properties: {})
      Analytics::AuditEvent.create!(
        org_id: org_id,
        event_name: event_name,
        severity: severity,
        properties: properties
      )
    end
  end
end
