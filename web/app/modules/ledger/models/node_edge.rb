# frozen_string_literal: true

module Ledger
  class NodeEdge < ApplicationRecord
    self.table_name = "ledger_node_edges"

    EDGE_TYPES = %w[contains depends_on refs research].freeze

    belongs_to :parent, class_name: "Ledger::Node"
    belongs_to :child,  class_name: "Ledger::Node"

    validates :edge_type, inclusion: { in: EDGE_TYPES }

    # A research edge means the child spike must be closed before the parent
    # can leave 'blocked'. Validated in NodeLifecycleService.
  end
end
