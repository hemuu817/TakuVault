require "rails_helper"

RSpec.describe Usage, type: :model do
  describe ".roles" do
    it "既存roleの整数値を維持したまま追加roleを末尾に追加している" do
      expect(Usage.roles).to eq(
        "background" => 0,
        "cutin" => 1,
        "bgm" => 2,
        "other" => 3,
        "standing" => 4,
        "panel" => 5,
        "sound_effect" => 6
      )
    end
  end

  describe "DISPLAY_ROLE_ORDER" do
    it "セッション素材一覧の固定表示順と一致している" do
      expect(Usage::DISPLAY_ROLE_ORDER).to eq(%w[
        background
        standing
        cutin
        panel
        bgm
        sound_effect
        other
      ])
    end

    it "enumと完全に同じroleを含んでいる" do
      expect(Usage::DISPLAY_ROLE_ORDER).to match_array(Usage.roles.keys)
    end
  end

  describe "ROLE_KIND_CANDIDATES" do
    it "表示対象の全roleに候補kindを定義している" do
      expect(Usage::ROLE_KIND_CANDIDATES.keys).to match_array(Usage::DISPLAY_ROLE_ORDER)
    end

    it "Assetで許可されたkindのみを候補にしている" do
      candidate_kinds = Usage::ROLE_KIND_CANDIDATES.values.flatten.uniq

      expect(candidate_kinds).to match_array(Asset.kinds.keys)
    end
  end

  it "DBで許可された追加roleをすべて保存できる" do
    %w[standing panel sound_effect].each do |role|
      usage = create(:usage, role: role)

      expect(usage.reload.role).to eq(role)
    end
  end

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
