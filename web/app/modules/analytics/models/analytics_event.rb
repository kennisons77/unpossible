# frozen_string_literal: true

module Analytics
  class AnalyticsEvent < ApplicationRecord
    self.table_name = 'analytics_events'

    validates :org_id, presence: true
    validates :distinct_id, presence: true
    validates :event_name, presence: true
    validates :timestamp, presence: true
    validates :received_at, presence: true

    def update(*)
      raise NotImplementedError, 'AnalyticsEvent is append-only'
    end

    def update!(*)
      raise NotImplementedError, 'AnalyticsEvent is append-only'
    end

    def destroy
      raise NotImplementedError, 'AnalyticsEvent is append-only'
    end

    def destroy!
      raise NotImplementedError, 'AnalyticsEvent is append-only'
    end
  end
end
