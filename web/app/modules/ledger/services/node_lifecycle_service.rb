# frozen_string_literal: true

module Ledger
  class NodeLifecycleService
    class LifecycleError < StandardError; end

    VALID_TRANSITIONS = {
      "proposed"    => %w[refining in_review blocked closed],
      "refining"    => %w[in_review blocked closed],
      "in_review"   => %w[accepted blocked closed proposed],
      "accepted"    => %w[in_progress closed],
      "in_progress" => %w[blocked closed],
      "blocked"     => %w[proposed refining in_review accepted in_progress],
      "closed"      => %w[proposed] # reopen
    }.freeze

    # Transition a question node to a new status.
    def self.transition(node, new_status, changed_by: "system", reason: nil)
      raise LifecycleError, "only question nodes have lifecycle transitions" unless node.kind == "question"
      raise LifecycleError, "invalid status: #{new_status}" unless Node::STATUSES.include?(new_status)

      from = node.status
      allowed = VALID_TRANSITIONS[from] || []
      raise LifecycleError, "cannot transition from '#{from}' to '#{new_status}'" unless allowed.include?(new_status)

      if new_status == "in_progress"
        _assert_no_open_depends_on(node)
        _assert_no_open_research(node)
      end

      if new_status == "accepted"
        _assert_no_open_depends_on(node)
        _assert_no_open_research(node)
      end

      node.version = (node.version || 1) + 1
      node.status  = new_status
      node.save!

      NodeAuditEvent.create!(
        node: node, changed_by: changed_by,
        from_status: from, to_status: new_status, reason: reason
      )

      # Opening a closed node: reopen is a transition back to proposed
      _open_children_if_accepted(node) if new_status == "accepted"

      node
    end

    # Post a terminal answer node as acceptance of a question.
    # Closes the question if answer_type is terminal.
    def self.accept(question_node, answer_attrs, changed_by: "system")
      raise LifecycleError, "only question nodes can be accepted" unless question_node.kind == "question"

      answer = Node.new(
        answer_attrs.merge(
          kind: "answer",
          answer_type: "terminal",
          org_id: question_node.org_id
        )
      )
      answer.save!
      NodeEdge.create!(parent: question_node, child: answer, edge_type: "contains")

      _close_question(question_node, changed_by: changed_by)
      answer
    end

    # Post a rebuttal — a false verdict terminal answer that reopens the question.
    def self.rebut(question_node, answer_attrs, changed_by: "system")
      raise LifecycleError, "only question nodes can be rebutted" unless question_node.kind == "question"

      answer = Node.new(
        answer_attrs.merge(
          kind: "answer",
          answer_type: "terminal",
          org_id: question_node.org_id
        )
      )
      answer.save!
      NodeEdge.create!(parent: question_node, child: answer, edge_type: "contains")

      transition(question_node, "proposed", changed_by: changed_by, reason: "rebutted")
      answer
    end

    # Create a child question under a generative answer.
    def self.create_child_question(parent_answer, question_attrs)
      raise LifecycleError, "only answer nodes can have child questions" unless parent_answer.kind == "answer"
      raise LifecycleError, "terminal answers cannot have child questions" if parent_answer.answer_type == "terminal"

      child = Node.new(question_attrs.merge(kind: "question"))
      child.save!
      NodeEdge.create!(parent: parent_answer, child: child, edge_type: "contains")
      child
    end

    # Attach a research spike to any node. Blocks the parent until spike is closed.
    def self.attach_research(parent_node, spike_attrs)
      spike = Node.new(spike_attrs.merge(kind: "question", scope: "code"))
      spike.save!
      NodeEdge.create!(parent: parent_node, child: spike, edge_type: "research")
      spike
    end

    class << self
      private

      def _assert_no_open_depends_on(node)
        open_count = NodeEdge
          .where(child_id: node.id, edge_type: "depends_on")
          .joins("INNER JOIN ledger_nodes ON ledger_nodes.id = ledger_node_edges.parent_id")
          .where.not("ledger_nodes.status" => "closed")
          .count
        raise LifecycleError, "#{open_count} open depends_on dependency(s)" if open_count > 0
      end

      def _assert_no_open_research(node)
        open_count = NodeEdge
          .where(parent_id: node.id, edge_type: "research")
          .joins("INNER JOIN ledger_nodes ON ledger_nodes.id = ledger_node_edges.child_id")
          .where.not("ledger_nodes.status" => "closed")
          .count
        raise LifecycleError, "#{open_count} open research spike(s) must be closed first" if open_count > 0
      end

      def _close_question(node, changed_by:)
        from = node.status
        node.version = (node.version || 1) + 1
        node.status  = "closed"
        node.save!
        NodeAuditEvent.create!(
          node: node, changed_by: changed_by,
          from_status: from, to_status: "closed"
        )
      end

      def _open_children_if_accepted(answer_node)
        # When a generative answer's parent question is accepted, open child questions
        # that were waiting. (Children are created in proposed state; no action needed —
        # they become workable once the parent is accepted/closed.)
      end
    end
  end
end
