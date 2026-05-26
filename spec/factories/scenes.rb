FactoryBot.define do
  factory :scene do
    association :session
    sequence(:position) { |n| n + 1 }
    sequence(:name) { |n| "シーン#{n}" }
  end
end
