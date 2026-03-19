FactoryBot.define do
  factory :concern do
    association :owner, factory: :user
    sequence(:name) { |n| "Concern #{n}" }
    llm_proposed { true }
    confirmed_at { nil }

    trait :confirmed do
      confirmed_at { Time.current }
    end

    trait :human_created do
      llm_proposed { false }
      confirmed_at { Time.current }
    end
  end
end
