# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::NodeAuditEvent, type: :model do
  subject(:event) { build(:ledger_node_audit_event) }

  describe "factory" do
    it "produces a valid record" do
      expect(event).to be_valid
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:node).class_name("Ledger::Node") }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:changed_by).in_array(described_class::CHANGED_BY_VALUES) }
    it { is_expected.to validate_presence_of(:to_status) }

    it "rejects an invalid changed_by" do
      event.changed_by = "robot"
      expect(event).not_to be_valid
      expect(event.errors[:changed_by]).to be_present
    end

    it "accepts all valid changed_by values" do
      described_class::CHANGED_BY_VALUES.each do |val|
        expect(build(:ledger_node_audit_event, changed_by: val)).to be_valid
      end
    end

    it "allows from_status to be nil" do
      event.from_status = nil
      expect(event).to be_valid
    end
  end

  describe "recorded_at default" do
    it "sets recorded_at before validation when blank" do
      event.recorded_at = nil
      event.valid?
      expect(event.recorded_at).to be_present
    end
  end

  describe "append-only immutability" do
    let!(:persisted) { create(:ledger_node_audit_event) }

    it "raises ReadOnlyRecord on update" do
      expect { persisted.update!(reason: "changed") }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it "raises ReadOnlyRecord on destroy" do
      expect { persisted.destroy! }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end
  end
end
