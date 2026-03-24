require "rails_helper"

RSpec.describe User do
  subject { build(:user) }

  describe "validations" do
    it { is_expected.to validate_presence_of(:email_address) }
    it { is_expected.to validate_uniqueness_of(:email_address).ignoring_case_sensitivity }
    it { is_expected.to have_secure_password }
  end

  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
  end

  describe "normalization" do
    it "downcases and strips email" do
      user = create(:user, email_address: "  ADMIN@Example.COM  ")
      expect(user.email_address).to eq("admin@example.com")
    end
  end
end
