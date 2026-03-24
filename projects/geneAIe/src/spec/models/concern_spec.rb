# frozen_string_literal: true

require "rails_helper"

RSpec.describe Concern do
  describe "associations" do
    it { is_expected.to belong_to(:owner).class_name("User") }
    it { is_expected.to have_many(:documents).dependent(:nullify) }
  end

  describe "validations" do
    subject { build(:concern) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:owner_id) }
  end

  describe "defaults" do
    it "sets llm_proposed to true by default" do
      concern = Concern.new
      expect(concern.llm_proposed).to be true
    end

    it "leaves confirmed_at nil for LLM-proposed concerns" do
      concern = create(:concern)
      expect(concern.confirmed_at).to be_nil
    end
  end

  describe "scopes" do
    let!(:confirmed_concern) { create(:concern, :confirmed) }
    let!(:unconfirmed_concern) { create(:concern) }

    describe ".confirmed" do
      it "returns only confirmed concerns" do
        expect(described_class.confirmed).to eq([confirmed_concern])
      end
    end

    describe ".unconfirmed" do
      it "returns only unconfirmed concerns" do
        expect(described_class.unconfirmed).to eq([unconfirmed_concern])
      end
    end
  end

  describe "#confirm!" do
    it "sets confirmed_at to the current time" do
      concern = create(:concern)

      freeze_time do
        concern.confirm!
        expect(concern.confirmed_at).to eq(Time.current)
      end
    end
  end
end
