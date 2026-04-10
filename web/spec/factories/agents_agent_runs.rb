# frozen_string_literal: true

FactoryBot.define do
  factory :agents_agent_run, class: 'Agents::AgentRun' do
    run_id { SecureRandom.uuid }
    association :actor, factory: :ledger_actor
    association :node, factory: :ledger_node
    parent_run_id { nil }
    mode { 'build' }
    provider { 'claude' }
    model { 'opus' }
    prompt_sha256 { SecureRandom.hex(32) }
    status { 'running' }
    source_node_ids { [] }
  end
end
