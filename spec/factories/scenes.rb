FactoryBot.define do
  factory :scene do
    association :session
    position { 1 }
    name { "デフォルト" }
  end
end
