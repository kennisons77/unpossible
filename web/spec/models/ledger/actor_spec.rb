# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ledger::Actor, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:actor_profile).class_name("Ledger::ActorProfile") }
    it { is_expected.to belong_to(:node).class_name("Ledger::Node") }
  end

  describe "tools_used" do
    it "defaults to empty array" do
      actor = create(:ledger_actor)
      expect(actor.tools_used).to eq([])
    end

    it "accepts a list of tool names" do
      actor = create(:ledger_actor, tools_used: ["bash", "write_file"])
      expect(actor.tools_used).to eq(["bash", "write_file"])
    end
  end

  describe "factory" do
    it "produces a valid record" do
      expect(build(:ledger_actor)).to be_valid
    end
  end
end
