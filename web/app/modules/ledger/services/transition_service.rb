# frozen_string_literal: true

module Ledger
  class TransitionService
    class TransitionError < StandardError; end

    VALID_TRANSITIONS = {
      "proposed"    => %w[refining in_review in_progress blocked closed],
      "refining"    => %w[in_review blocked closed],
      "in_review"   => %w[accepted blocked closed proposed],
      "accepted"    => %w[in_progress closed],
      "in_progress" => %w[blocked closed],
      "blocked"     => %w[proposed refining in_review accepted in_progress],
      "closed"      => %w[proposed]
    }.freeze

    def self.call(node, new_status, changed_by: "system", reason: nil)
      raise TransitionError, "only question nodes have lifecycle transitions" unless node.kind == "question"
      raise TransitionError, "invalid status: #{new_status}" unless Node::STATUSES.include?(new_status)

      from = node.status
      allowed = VALID_TRANSITIONS[from] || []
      raise TransitionError, "cannot transition from '#{from}' to '#{new_status}'" unless allowed.include?(new_status)

      assert_no_open_blockers(node) if %w[in_progress accepted].include?(new_status)

      node.version = (node.version || 1) + 1
      node.status  = new_status
      node.save!

      NodeAuditEvent.create!(
        node: node, changed_by: changed_by,
        from_status: from, to_status: new_status, reason: reason
      )

      node
    end

    def self.close(node, changed_by: "system")
      from = node.status
      node.version = (node.version || 1) + 1
      node.status  = "closed"
      node.save!
      NodeAuditEvent.create!(
        node: node, changed_by: changed_by,
        from_status: from, to_status: "closed"
      )
      node
    end

    class << self
      private

      def assert_no_open_blockers(node)
        open_deps = NodeEdge
          .where(child_id: node.id, edge_type: "depends_on")
          .joins("INNER JOIN ledger_nodes ON ledger_nodes.id = ledger_node_edges.parent_id")
          .where.not("ledger_nodes.status" => "closed")
          .count
        raise TransitionError, "#{open_deps} open dependency(s) must be closed first" if open_deps > 0

        open_research = NodeEdge
          .where(parent_id: node.id, edge_type: "research")
          .joins("INNER JOIN ledger_nodes ON ledger_nodes.id = ledger_node_edges.child_id")
          .where.not("ledger_nodes.status" => "closed")
          .count
        raise TransitionError, "#{open_research} open research spike(s) must be closed first" if open_research > 0
      end
    end
  end
end
