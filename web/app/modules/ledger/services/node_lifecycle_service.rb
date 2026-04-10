# frozen_string_literal: true

module Ledger
  # Thin facade — delegates to TransitionService, VerdictService, and NodeFactory.
  # Kept for backward compatibility; prefer calling the specific service directly.
  class NodeLifecycleService
    LifecycleError = TransitionService::TransitionError

    def self.transition(node, new_status, changed_by: "system", reason: nil)
      TransitionService.call(node, new_status, changed_by: changed_by, reason: reason)
    end

    def self.record_verdict(answer_node, verdict, accepted_by_id: "system")
      VerdictService.call(answer_node, verdict)
    end

    def self.accept(question_node, answer_attrs, changed_by: "system")
      NodeFactory.accept(question_node, answer_attrs, changed_by: changed_by)
    end

    def self.rebut(question_node, answer_attrs, changed_by: "system")
      NodeFactory.rebut(question_node, answer_attrs, changed_by: changed_by)
    end

    def self.create_child_question(parent_answer, question_attrs)
      NodeFactory.create_child_question(parent_answer, question_attrs)
    end

    def self.attach_research(parent_node, spike_attrs)
      NodeFactory.attach_research(parent_node, spike_attrs)
    end
  end
end
