# frozen_string_literal: true

module Analytics
  class AuditEvent < ApplicationRecord
    self.table_name = 'analytics_audit_events'

    SEVERITIES = %w[info warning critical].freeze

    validates :org_id, presence: true
    validates :event_name, presence: true
    validates :severity, presence: true, inclusion: { in: SEVERITIES }

    def update(*)
      raise NotImplementedError, 'AuditEvent is append-only'
    end

    def update!(*)
      raise NotImplementedError, 'AuditEvent is append-only'
    end

    def destroy
      raise NotImplementedError, 'AuditEvent is append-only'
    end

    def destroy!
      raise NotImplementedError, 'AuditEvent is append-only'
    end
  end
end
