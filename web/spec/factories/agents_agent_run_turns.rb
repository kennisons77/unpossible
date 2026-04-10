# frozen_string_literal: true

FactoryBot.define do
  factory :agents_agent_run_turn, class: 'Agents::AgentRunTurn' do
    association :agent_run, factory: :agents_agent_run
    sequence(:position) { |n| n }
    kind { 'llm_response' }
    content { 'Sample turn content' }
    purged_at { nil }
  end
end
