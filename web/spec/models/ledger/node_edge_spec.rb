# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::NodeEdge, type: :model do
  subject(:edge) { build(:ledger_node_edge) }

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:edge_type).in_array(described_class::EDGE_TYPES) }

    it "rejects an invalid edge_type" do
      edge.edge_type = "invalid"
      expect(edge).not_to be_valid
      expect(edge.errors[:edge_type]).to be_present
    end

    it "accepts all valid edge_types" do
      described_class::EDGE_TYPES.each do |type|
        expect(build(:ledger_node_edge, edge_type: type)).to be_valid
      end
    end
  end

  describe "ref_type" do
    it "is nullable" do
      edge.ref_type = nil
      expect(edge).to be_valid
    end

    it "accepts a string value" do
      edge.ref_type = "spec"
      expect(edge).to be_valid
    end
  end

  describe "primary flag" do
    it "defaults to false" do
      edge = create(:ledger_node_edge)
      expect(edge.primary).to be false
    end

    it "can be set to true" do
      edge = create(:ledger_node_edge, primary: true)
      expect(edge.primary).to be true
    end
  end

  describe "fan-in" do
    it "allows multiple parents pointing to the same child" do
      child = create(:ledger_node)
      parent1 = create(:ledger_node)
      parent2 = create(:ledger_node)
      create(:ledger_node_edge, parent: parent1, child: child)
      create(:ledger_node_edge, parent: parent2, child: child)
      expect(described_class.where(child: child).count).to eq(2)
    end
  end

  describe "depends_on blocks in_progress transition" do
    it "is enforced at the service layer — model records the edge" do
      question = create(:ledger_node, kind: "question", status: "proposed")
      blocker  = create(:ledger_node, kind: "question", status: "proposed")
      edge = create(:ledger_node_edge, parent: blocker, child: question, edge_type: "depends_on")
      expect(edge.edge_type).to eq("depends_on")
      expect(edge).to be_persisted
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:parent).class_name("Ledger::Node") }
    it { is_expected.to belong_to(:child).class_name("Ledger::Node") }
  end

  describe "factory" do
    it "produces a valid edge" do
      expect(build(:ledger_node_edge)).to be_valid
    end
  end
end
