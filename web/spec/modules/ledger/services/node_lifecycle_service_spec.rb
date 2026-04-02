# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::NodeLifecycleService do
  let(:org_id) { SecureRandom.uuid }

  def question(attrs = {})
    create(:ledger_node, { kind: "question", status: "open", org_id: org_id }.merge(attrs))
  end

  def terminal_answer(attrs = {})
    create(:ledger_node, :terminal_answer, { org_id: org_id }.merge(attrs))
  end

  def generative_answer(attrs = {})
    create(:ledger_node, :generative_answer, { acceptance_threshold: 1, org_id: org_id }.merge(attrs))
  end

  # UAT-1: question lifecycle
  describe ".transition" do
    context "when transitioning a question through valid statuses" do
      it "moves open → in_progress" do
        node = question
        described_class.transition(node, "in_progress")
        expect(node.reload.status).to eq("in_progress")
      end

      it "moves in_progress → closed" do
        node = question(status: "in_progress")
        described_class.transition(node, "closed")
        expect(node.reload.status).to eq("closed")
      end

      it "increments version on each transition" do
        node = question
        expect { described_class.transition(node, "in_progress") }
          .to change { node.reload.version }.by(1)
      end
    end

    context "when called on an answer node" do
      it "raises LifecycleError" do
        answer = terminal_answer
        expect { described_class.transition(answer, "closed") }
          .to raise_error(Ledger::NodeLifecycleService::LifecycleError, /only question nodes/)
      end
    end

    context "when called with an invalid status" do
      it "raises LifecycleError" do
        node = question
        expect { described_class.transition(node, "flying") }
          .to raise_error(Ledger::NodeLifecycleService::LifecycleError, /invalid status/)
      end
    end
  end

  # UAT-2: dependency enforcement
  describe ".transition with depends_on edges" do
    context "when a dependency is not closed" do
      it "blocks the in_progress transition" do
        blocker = question(status: "open")
        node = question
        create(:ledger_node_edge, parent: blocker, child: node, edge_type: "depends_on")

        expect { described_class.transition(node, "in_progress") }
          .to raise_error(Ledger::NodeLifecycleService::LifecycleError, /open dependency/)
      end
    end

    context "when all dependencies are closed" do
      it "allows the in_progress transition" do
        blocker = question(status: "closed")
        node = question
        create(:ledger_node_edge, parent: blocker, child: node, edge_type: "depends_on")

        expect { described_class.transition(node, "in_progress") }.not_to raise_error
        expect(node.reload.status).to eq("in_progress")
      end
    end
  end

  # UAT-3: generative answer opens children / verdict handling
  describe ".record_verdict" do
    context "when called on a non-answer node" do
      it "raises LifecycleError" do
        node = question
        expect { described_class.record_verdict(node, true, accepted_by_id: "user-1") }
          .to raise_error(Ledger::NodeLifecycleService::LifecycleError, /only answer nodes/)
      end
    end

    context "when verdict is not a boolean" do
      it "raises LifecycleError" do
        answer = terminal_answer
        expect { described_class.record_verdict(answer, "yes", accepted_by_id: "user-1") }
          .to raise_error(Ledger::NodeLifecycleService::LifecycleError, /true or false/)
      end
    end

    context "with a true verdict meeting the threshold" do
      it "sets accepted to true" do
        answer = terminal_answer(acceptance_threshold: 1)
        described_class.record_verdict(answer, true, accepted_by_id: "user-1")
        expect(answer.reload.accepted).to eq("true")
      end

      it "closes the parent question" do
        parent = question
        answer = terminal_answer(acceptance_threshold: 1)
        create(:ledger_node_edge, parent: parent, child: answer, edge_type: "contains")

        described_class.record_verdict(answer, true, accepted_by_id: "user-1")
        expect(parent.reload.status).to eq("closed")
      end

      it "increments the parent question version when closing" do
        parent = question
        answer = terminal_answer(acceptance_threshold: 1)
        create(:ledger_node_edge, parent: parent, child: answer, edge_type: "contains")

        expect { described_class.record_verdict(answer, true, accepted_by_id: "user-1") }
          .to change { parent.reload.version }.by(1)
      end
    end

    context "with a true verdict below the threshold" do
      it "keeps accepted as pending" do
        answer = terminal_answer(acceptance_threshold: 2)
        described_class.record_verdict(answer, true, accepted_by_id: "user-1")
        expect(answer.reload.accepted).to eq("pending")
      end
    end

    context "with a false verdict" do
      it "sets accepted to false" do
        answer = terminal_answer
        described_class.record_verdict(answer, false, accepted_by_id: "user-1")
        expect(answer.reload.accepted).to eq("false")
      end

      it "re-opens a closed parent question" do
        parent = question(status: "closed")
        answer = terminal_answer
        create(:ledger_node_edge, parent: parent, child: answer, edge_type: "contains")

        described_class.record_verdict(answer, false, accepted_by_id: "user-1")
        expect(parent.reload.status).to eq("open")
      end

      it "increments the parent question version when re-opening" do
        parent = question(status: "closed")
        answer = terminal_answer
        create(:ledger_node_edge, parent: parent, child: answer, edge_type: "contains")

        expect { described_class.record_verdict(answer, false, accepted_by_id: "user-1") }
          .to change { parent.reload.version }.by(1)
      end

      it "does not re-open a parent that is not closed" do
        parent = question(status: "in_progress")
        answer = terminal_answer
        create(:ledger_node_edge, parent: parent, child: answer, edge_type: "contains")

        described_class.record_verdict(answer, false, accepted_by_id: "user-1")
        expect(parent.reload.status).to eq("in_progress")
      end
    end
  end

  # Terminal answer rejects child creation
  describe ".create_child_question" do
    context "when parent is a terminal answer" do
      it "raises LifecycleError" do
        answer = terminal_answer
        expect do
          described_class.create_child_question(answer, {
            body: "child?", scope: "code", author: "human",
            stable_ref: SecureRandom.hex(16), org_id: org_id
          })
        end.to raise_error(Ledger::NodeLifecycleService::LifecycleError, /terminal answers/)
      end
    end

    context "when parent is a generative answer" do
      it "creates the child question" do
        answer = generative_answer
        child = described_class.create_child_question(answer, {
          body: "child?", scope: "code", author: "human",
          stable_ref: SecureRandom.hex(16), org_id: org_id
        })
        expect(child).to be_persisted
        expect(child.kind).to eq("question")
      end

      it "creates a contains edge from parent to child" do
        answer = generative_answer
        child = described_class.create_child_question(answer, {
          body: "child?", scope: "code", author: "human",
          stable_ref: SecureRandom.hex(16), org_id: org_id
        })
        edge = Ledger::NodeEdge.find_by(parent: answer, child: child, edge_type: "contains")
        expect(edge).to be_present
      end
    end

    context "when called on a question node" do
      it "raises LifecycleError" do
        node = question
        expect do
          described_class.create_child_question(node, {
            body: "child?", scope: "code", author: "human",
            stable_ref: SecureRandom.hex(16), org_id: org_id
          })
        end.to raise_error(Ledger::NodeLifecycleService::LifecycleError, /only answer nodes/)
      end
    end
  end

  # Version increments on every status transition
  describe "version tracking" do
    it "increments version on each successive transition" do
      node = question
      initial_version = node.version

      described_class.transition(node, "in_progress")
      described_class.transition(node, "blocked")
      described_class.transition(node, "in_progress")
      described_class.transition(node, "closed")

      expect(node.reload.version).to eq(initial_version + 4)
    end
  end
end
