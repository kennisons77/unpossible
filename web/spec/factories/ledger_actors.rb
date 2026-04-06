# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_actor, class: "Ledger::Actor" do
    association :actor_profile, factory: :ledger_actor_profile
    association :node, factory: :ledger_node
    tools_used { [] }
  end
end
