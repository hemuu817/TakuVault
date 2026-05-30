FactoryBot.define do
  factory :usage do
    association :asset
    session { asset.user.sessions.create!(name: "Usage session") }
    scene { session.scenes.find_by!(position: Scene::DEFAULT_POSITION) }
    role { :background }
  end
end
