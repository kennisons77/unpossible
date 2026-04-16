# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_project, class: "Ledger::Project" do
    sequence(:name) { |n| "test-project-#{n}" }
    org_id { SecureRandom.uuid }
  end
end
