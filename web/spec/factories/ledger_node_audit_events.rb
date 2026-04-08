# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_node_audit_event, class: "Ledger::NodeAuditEvent" do
    association :node, factory: :ledger_node
    changed_by { "human" }
    from_status { "proposed" }
    to_status { "refining" }
    reason { "Status transition" }
    recorded_at { Time.current }
  end
end
