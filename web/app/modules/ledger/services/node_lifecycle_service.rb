# frozen_string_literal: true

module Ledger
  class NodeLifecycleService
    class LifecycleError < StandardError; end

    # Transition a question node to a new status.
    # Raises LifecycleError if the transition is not allowed.
    def self.transition(node, new_status)
      raise LifecycleError, "only question nodes have lifecycle transitions" unless node.kind == "question"
      raise LifecycleError, "invalid status: #{new_status}" unless Node::STATUSES.include?(new_status)

      if new_status == "in_progress"
        open_blockers = NodeEdge
          .where(child: node, edge_type: "depends_on")
          .joins("INNER JOIN ledger_nodes ON ledger_nodes.id = ledger_node_edges.parent_id")
          .where.not("ledger_nodes.status" => "closed")
          .count

        raise LifecycleError, "cannot move to in_progress: #{open_blockers} open dependency(s)" if open_blockers > 0
      end

      node.version = (node.version || 1) + 1
      node.status = new_status
      node.save!
      node
    end

    # Record a verdict (true/false) on an answer node.
    # Raises LifecycleError if the node is not an answer.
    def self.record_verdict(answer_node, verdict, accepted_by_id:)
      raise LifecycleError, "only answer nodes accept verdicts" unless answer_node.kind == "answer"
      raise LifecycleError, "verdict must be true or false" unless [true, false].include?(verdict)

      accepted_by = Array(answer_node.accepted_by) + [accepted_by_id.to_s]
      answer_node.accepted_by = accepted_by

      if verdict
        threshold = answer_node.acceptance_threshold || 1
        if accepted_by.size >= threshold
          answer_node.accepted = "true"
          answer_node.save!
          _close_parent_question(answer_node)
          _open_children_if_generative(answer_node)
        else
          answer_node.accepted = "pending"
          answer_node.save!
        end
      else
        answer_node.accepted = "false"
        answer_node.save!
        _reopen_parent_question(answer_node)
      end

      answer_node
    end

    # Create a child question under a parent answer.
    # Raises LifecycleError if the parent is a terminal answer.
    def self.create_child_question(parent_answer, question_attrs)
      raise LifecycleError, "only answer nodes can have child questions" unless parent_answer.kind == "answer"
      raise LifecycleError, "terminal answers cannot have child questions" if parent_answer.answer_type == "terminal"

      child = Node.new(question_attrs.merge(kind: "question"))
      child.save!

      NodeEdge.create!(parent: parent_answer, child: child, edge_type: "contains")
      child
    end

    class << self
      private

      def _close_parent_question(answer_node)
        parent_edge = NodeEdge.find_by(child: answer_node, edge_type: "contains")
        return unless parent_edge

        parent = parent_edge.parent
        return unless parent.kind == "question"

        parent.version = (parent.version || 1) + 1
        parent.status = "closed"
        parent.save!
      end

      def _reopen_parent_question(answer_node)
        parent_edge = NodeEdge.find_by(child: answer_node, edge_type: "contains")
        return unless parent_edge

        parent = parent_edge.parent
        return unless parent.kind == "question" && parent.status == "closed"

        parent.version = (parent.version || 1) + 1
        parent.status = "open"
        parent.save!
      end

      def _open_children_if_generative(answer_node)
        return unless answer_node.answer_type == "generative"

        NodeEdge
          .where(parent: answer_node, edge_type: "contains")
          .joins("INNER JOIN ledger_nodes ON ledger_nodes.id = ledger_node_edges.child_id")
          .where("ledger_nodes.kind" => "question")
          .each do |edge|
            child = edge.child
            next unless child.status == "open"

            # Children are already open; nothing to do — they become workable once parent is accepted
          end
      end
    end
  end
end
