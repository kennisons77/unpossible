# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::ActorProfile, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:provider) }
    it { is_expected.to validate_presence_of(:model) }
    it { is_expected.to validate_presence_of(:org_id) }
  end

  describe "allowed_tools" do
    it "defaults to empty array" do
      profile = create(:ledger_actor_profile)
      expect(profile.allowed_tools).to eq([])
    end

    it "accepts a list of tool names" do
      profile = create(:ledger_actor_profile, allowed_tools: ["bash", "read_file"])
      expect(profile.allowed_tools).to eq(["bash", "read_file"])
    end
  end

  describe "prompt_template" do
    it "is nullable" do
      profile = build(:ledger_actor_profile, prompt_template: nil)
      expect(profile).to be_valid
    end
  end

  describe "factory" do
    it "produces a valid record" do
      expect(build(:ledger_actor_profile)).to be_valid
    end
  end
end
