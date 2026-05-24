FactoryBot.define do
  factory :session do
    association :user
    sequence(:name) { |n| "セッション#{n}" }
    room_url { nil }
  end
end
