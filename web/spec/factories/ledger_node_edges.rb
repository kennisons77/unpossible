# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_node_edge, class: "Ledger::NodeEdge" do
    association :parent, factory: :ledger_node
    association :child, factory: :ledger_node
    edge_type { "contains" }
    ref_type { nil }
    primary { false }
  end
end
