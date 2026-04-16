# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_project, class: "Ledger::Project" do
    name { "test-project" }
    org_id { SecureRandom.uuid }
  end
end
