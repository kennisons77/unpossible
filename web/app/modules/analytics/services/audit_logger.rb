# frozen_string_literal: true

module Analytics
  class AuditLogger
    def self.log(org_id:, event_name:, severity: 'info', properties: {})
      Analytics::AuditLogJob.perform_later(
        org_id: org_id,
        event_name: event_name,
        severity: severity,
        properties: properties
      )
    rescue StandardError => e
      Rails.logger.error("AuditLogger.log failed: #{e.class}: #{e.message}")
    end
  end
end
