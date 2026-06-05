require "rails_helper"

RSpec.describe Usage, type: :model do
  it "enforces allowed role values at the database level" do
    usage = create(:usage)

    expect {
      Usage.insert_all!([
        {
          asset_id: usage.asset.id,
          session_id: usage.session.id,
          scene_id: usage.scene.id,
          role: 99,
          created_at: Time.current,
          updated_at: Time.current
        }
      ])
    }.to raise_error(ActiveRecord::StatementInvalid)
  end

  describe ".for_where_used" do
    it "returns only usages tied to the current user's sessions and preloads session and scene" do
      user = create(:user)
      other_user = create(:user)
      asset = create(:asset, user: user)
      visible_session = create(:session, user: user, name: "Aセッション")
      visible_scene = visible_session.scenes.find_by!(position: Scene::DEFAULT_POSITION)
      hidden_session = create(:session, user: other_user, name: "Zセッション")
      hidden_scene = hidden_session.scenes.find_by!(position: Scene::DEFAULT_POSITION)
      visible_usage = create(:usage, asset: asset, session: visible_session, scene: visible_scene, role: :background)
      create(:usage, asset: asset, session: hidden_session, scene: hidden_scene, role: :cutin)

      usages = asset.usages.for_where_used(user).to_a

      expect(usages).to eq([ visible_usage ])
      expect(usages.first.association(:session)).to be_loaded
      expect(usages.first.association(:scene)).to be_loaded
    end
  end
end
