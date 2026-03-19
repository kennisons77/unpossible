FactoryBot.define do
  factory :document do
    association :owner, factory: :user
    stage { :acquired }
    review_required { false }

    trait :with_concern do
      association :concern
    end

    trait :categorized do
      stage { :categorized }
      association :concern
      document_type { 'utility_bill' }
      confidence_score { 0.85 }
    end

    trait :needing_review do
      review_required { true }
      review_reason { 'Low confidence score' }
    end
  end
end
