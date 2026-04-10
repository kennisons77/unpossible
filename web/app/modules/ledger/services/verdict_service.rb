# frozen_string_literal: true

module Ledger
  class VerdictService
    def self.call(answer_node, verdict)
      raise TransitionService::TransitionError, "only answer nodes can have a verdict" unless answer_node.kind == "answer"
      raise TransitionService::TransitionError, "verdict must be true or false" unless verdict == true || verdict == false

      parent = find_parent_question(answer_node)
      return answer_node unless parent

      if verdict
        TransitionService.close(parent, changed_by: "human") unless parent.status == "closed"
      else
        TransitionService.call(parent, "proposed", changed_by: "human", reason: "verdict rejected") if parent.status == "closed"
      end

      answer_node
    end

    def self.find_parent_question(answer_node)
      NodeEdge
        .where(child_id: answer_node.id, edge_type: "contains")
        .joins("INNER JOIN ledger_nodes ON ledger_nodes.id = ledger_node_edges.parent_id")
        .where("ledger_nodes.kind = ?", "question")
        .first
        &.then { |edge| Node.find(edge.parent_id) }
    end
    private_class_method :find_parent_question
  end
end
