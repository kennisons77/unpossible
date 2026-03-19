FactoryBot.define do
  factory :document_field do
    association :document
    sequence(:field_name) { |n| "field_#{n}" }
    value { 'sample value' }
    source { :llm }

    trait :from_ocr do
      source { :ocr }
    end

    trait :from_human do
      source { :human }
    end
  end
end
