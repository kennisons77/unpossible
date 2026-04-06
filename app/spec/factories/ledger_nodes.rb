# frozen_string_literal: true

FactoryBot.define do
  factory :ledger_node, class: "Ledger::Node" do
    kind { "question" }
    scope { "code" }
    body { "What needs to be done?" }
    title { "Sample question" }
    author { "human" }
    stable_ref { SecureRandom.hex(32) }
    org_id { SecureRandom.uuid }
    recorded_at { Time.current }
    status { "open" }

    trait :answer do
      kind { "answer" }
      answer_type { "terminal" }
      accepted { "pending" }
      status { nil }
    end

    trait :generative_answer do
      kind { "answer" }
      answer_type { "generative" }
      accepted { "pending" }
      status { nil }
    end

    trait :terminal_answer do
      kind { "answer" }
      answer_type { "terminal" }
      accepted { "pending" }
      status { nil }
    end
  end
end
