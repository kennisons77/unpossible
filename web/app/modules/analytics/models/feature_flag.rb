# frozen_string_literal: true

module Analytics
  class FeatureFlag < ApplicationRecord
    self.table_name = 'analytics_feature_flags'

    STATUSES = %w[active archived].freeze

    validates :key, presence: true, uniqueness: { scope: :org_id }
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :org_id, presence: true
    validate :hypothesis_present, on: :create

    def self.enabled?(org_id:, key:)
      flag = find_by(org_id: org_id, key: key)
      result = flag.nil? || flag.status == 'archived' ? false : flag.enabled

      fire_flag_called_event(org_id: org_id, key: key, enabled: result)

      result
    end

    def self.fire_flag_called_event(org_id:, key:, enabled:)
      AnalyticsEvent.create!(
        org_id: org_id,
        distinct_id: org_id,
        event_name: '$feature_flag_called',
        properties: { flag_key: key, variant: enabled ? 'enabled' : 'disabled', enabled: enabled },
        timestamp: Time.current,
        received_at: Time.current
      )
    rescue StandardError => e
      Rails.logger.warn("FeatureFlag: failed to fire $feature_flag_called for #{key}: #{e.message}")
    end
    private_class_method :fire_flag_called_event

    private

    def hypothesis_present
      # metadata.hypothesis required on creation per platform override
      errors.add(:metadata, "must include a hypothesis") if metadata.blank? || metadata['hypothesis'].blank?
    end
  end
end
