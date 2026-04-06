# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_actor_profile, class: "Ledger::ActorProfile" do
    name { "Test Agent" }
    provider { "openai" }
    model { "gpt-4o" }
    allowed_tools { [] }
    prompt_template { nil }
    org_id { SecureRandom.uuid }
  end
end
