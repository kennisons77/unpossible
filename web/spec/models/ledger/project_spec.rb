# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Project, type: :model do
  subject(:project) { build(:ledger_project) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:org_id) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:org_id) }
  end

  describe "associations" do
    it { is_expected.to have_many(:nodes).class_name("Ledger::Node").dependent(:restrict_with_error) }
  end

  describe "factory" do
    it "produces a valid project" do
      expect(build(:ledger_project)).to be_valid
    end
  end
end
