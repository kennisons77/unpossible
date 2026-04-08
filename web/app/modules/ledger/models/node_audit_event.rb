# frozen_string_literal: true

module Ledger
  # Append-only record of every status transition on a Node.
  # Never updated or deleted — corrections are new rows.
  class NodeAuditEvent < ApplicationRecord
    self.table_name = "ledger_node_audit_events"

    CHANGED_BY_VALUES = %w[human agent system].freeze

    belongs_to :node, class_name: "Ledger::Node"

    validates :changed_by, inclusion: { in: CHANGED_BY_VALUES }
    validates :to_status, presence: true
    validates :recorded_at, presence: true

    before_validation { self.recorded_at ||= Time.current }

    # Audit events are immutable
    before_update { raise ActiveRecord::ReadOnlyRecord }
    before_destroy { raise ActiveRecord::ReadOnlyRecord }
  end
end
