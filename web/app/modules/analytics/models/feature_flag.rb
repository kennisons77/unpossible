# frozen_string_literal: true

module Analytics
  class FeatureFlag < ApplicationRecord
    self.table_name = 'analytics_feature_flags'

    STATUSES = %w[active archived].freeze

    validates :key, presence: true, uniqueness: { scope: :org_id }
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :org_id, presence: true

    def self.enabled?(org_id:, key:)
      flag = find_by(org_id: org_id, key: key)
      return false if flag.nil? || flag.status == 'archived'

      flag.enabled
    end
  end
end
