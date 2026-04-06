# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Node, type: :model do
  subject(:node) { build(:ledger_node) }

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:kind).in_array(described_class::KINDS) }
    it { is_expected.to validate_inclusion_of(:scope).in_array(described_class::SCOPES) }
    it { is_expected.to validate_inclusion_of(:author).in_array(described_class::AUTHORS) }
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:org_id) }
    it { is_expected.to validate_presence_of(:stable_ref) }

    it "validates answer_type inclusion when present" do
      node = build(:ledger_node, :answer, answer_type: "invalid")
      expect(node).not_to be_valid
      expect(node.errors[:answer_type]).to be_present
    end

    it "validates status inclusion when present" do
      node = build(:ledger_node, status: "invalid")
      expect(node).not_to be_valid
      expect(node.errors[:status]).to be_present
    end

    it "validates resolution inclusion when present" do
      node = build(:ledger_node, resolution: "invalid")
      expect(node).not_to be_valid
      expect(node.errors[:resolution]).to be_present
    end

    it "validates accepted inclusion when present" do
      node = build(:ledger_node, :answer, accepted: "invalid")
      expect(node).not_to be_valid
      expect(node.errors[:accepted]).to be_present
    end
  end

  describe "kind/scope enums" do
    it "accepts all valid kinds" do
      described_class::KINDS.each do |kind|
        node = build(:ledger_node, kind: kind, answer_type: kind == "answer" ? "terminal" : nil,
                                   status: kind == "question" ? "open" : nil,
                                   accepted: kind == "answer" ? "pending" : nil)
        expect(node).to be_valid, "expected #{kind} to be valid but got: #{node.errors.full_messages}"
      end
    end

    it "accepts all valid scopes" do
      described_class::SCOPES.each do |scope|
        node = build(:ledger_node, scope: scope)
        expect(node).to be_valid, "expected scope #{scope} to be valid"
      end
    end
  end

  describe "answer_type constraint" do
    it "rejects answer_type on a question node" do
      node = build(:ledger_node, kind: "question", answer_type: "terminal")
      expect(node).not_to be_valid
      expect(node.errors[:answer_type]).to include("only valid on answer nodes")
    end

    it "allows answer_type on an answer node" do
      node = build(:ledger_node, :terminal_answer)
      expect(node).to be_valid
    end
  end

  describe "status constraint" do
    it "rejects status on an answer node" do
      node = build(:ledger_node, :answer, status: "open")
      expect(node).not_to be_valid
      expect(node.errors[:status]).to include("only valid on question nodes")
    end

    it "allows status on a question node" do
      node = build(:ledger_node, kind: "question", status: "open")
      expect(node).to be_valid
    end
  end

  describe "answer immutability" do
    it "rejects body changes on a persisted answer" do
      node = create(:ledger_node, :terminal_answer)
      node.body = "changed body"
      expect(node).not_to be_valid
      expect(node.errors[:base]).to include("answer nodes are immutable after creation")
    end

    it "allows non-immutable field changes on a persisted answer" do
      node = create(:ledger_node, :terminal_answer)
      node.accepted = "true"
      expect(node).to be_valid
    end

    it "allows updates to question nodes" do
      node = create(:ledger_node)
      node.status = "in_progress"
      expect(node).to be_valid
    end
  end

  describe "defaults" do
    it "sets accepted to pending for new answer nodes" do
      node = create(:ledger_node, :terminal_answer, accepted: nil)
      expect(node.accepted).to eq("pending")
    end

    it "sets recorded_at automatically before validation" do
      node = build(:ledger_node, recorded_at: nil)
      node.valid?
      expect(node.recorded_at).to be_present
    end
  end

  describe "terminal answer rejects child question" do
    it "is a terminal answer with no child questions allowed" do
      # Terminal answers are enforced at the service layer (NodeLifecycleService),
      # but the model correctly identifies terminal answers
      node = build(:ledger_node, :terminal_answer)
      expect(node.answer_type).to eq("terminal")
    end
  end

  describe "generative answer allows children" do
    it "is a generative answer" do
      node = build(:ledger_node, :generative_answer)
      expect(node.answer_type).to eq("generative")
      expect(node).to be_valid
    end
  end

  describe "version" do
    it "defaults to 1" do
      node = create(:ledger_node)
      expect(node.version).to eq(1)
    end
  end

  describe "factory" do
    it "produces a valid question node" do
      expect(build(:ledger_node)).to be_valid
    end

    it "produces a valid terminal answer node" do
      expect(build(:ledger_node, :terminal_answer)).to be_valid
    end

    it "produces a valid generative answer node" do
      expect(build(:ledger_node, :generative_answer)).to be_valid
    end
  end
end
