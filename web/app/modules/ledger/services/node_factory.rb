# frozen_string_literal: true

module Ledger
  class NodeFactory
    def self.accept(question_node, answer_attrs, changed_by: "system")
      raise TransitionService::TransitionError, "only question nodes can be accepted" unless question_node.kind == "question"

      answer = Node.new(answer_attrs.merge(kind: "answer", answer_type: "terminal", org_id: question_node.org_id))
      answer.save!
      NodeEdge.create!(parent: question_node, child: answer, edge_type: "contains")
      TransitionService.close(question_node, changed_by: changed_by)
      answer
    end

    def self.rebut(question_node, answer_attrs, changed_by: "system")
      raise TransitionService::TransitionError, "only question nodes can be rebutted" unless question_node.kind == "question"

      answer = Node.new(answer_attrs.merge(kind: "answer", answer_type: "terminal", org_id: question_node.org_id))
      answer.save!
      NodeEdge.create!(parent: question_node, child: answer, edge_type: "contains")
      TransitionService.call(question_node, "proposed", changed_by: changed_by, reason: "rebutted")
      answer
    end

    def self.create_child_question(parent_answer, question_attrs)
      raise TransitionService::TransitionError, "only answer nodes can have child questions" unless parent_answer.kind == "answer"
      raise TransitionService::TransitionError, "terminal answers cannot have child questions" if parent_answer.answer_type == "terminal"

      child = Node.new(question_attrs.merge(kind: "question"))
      child.save!
      NodeEdge.create!(parent: parent_answer, child: child, edge_type: "contains")
      child
    end

    def self.attach_research(parent_node, spike_attrs)
      spike = Node.new(spike_attrs.merge(kind: "question", scope: "code"))
      spike.save!
      NodeEdge.create!(parent: parent_node, child: spike, edge_type: "research")
      spike
    end
  end
end
