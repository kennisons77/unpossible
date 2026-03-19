FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@sovereign.local" }
    password { "test-password-123" }

    after(:build) do |user|
      user.password_confirmation = user.password
    end
  end
end
