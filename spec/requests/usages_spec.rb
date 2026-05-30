require "rails_helper"

RSpec.describe "Usages", type: :request do
  let(:user) { create(:user) }
  let(:session_record) { create(:session, user: user) }
  let(:scene) { session_record.scenes.find_by!(position: Scene::DEFAULT_POSITION) }

  before do
    sign_in user
  end

  describe "POST /usages" do
    it "creates usages in bulk" do
      assets = create_list(:asset, 2, user: user)

      post usages_path, params: {
        usage_mode: "bulk",
        asset_ids: assets.map(&:id),
        session_id: session_record.id,
        scene_id: scene.id,
        role: "background"
      }

      expect(response).to redirect_to(uncategorized_assets_path)
      expect(Usage.count).to eq(2)
    end

    it "creates one usage from an asset detail form" do
      asset = create(:asset, user: user)

      post usages_path, params: {
        asset_id: asset.id,
        session_id: session_record.id,
        scene_id: scene.id,
        role: "background"
      }

      expect(response).to redirect_to(asset_path(asset))
      expect(Usage.count).to eq(1)
    end

    it "returns 422 for a duplicate secondary creation" do
      asset = create(:asset, user: user)
      create(:usage, asset: asset, session: session_record, scene: scene, role: :background)

      post usages_path, params: {
        asset_id: asset.id,
        session_id: session_record.id,
        scene_id: scene.id,
        role: "background"
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Usage.count).to eq(1)
    end

    it "fails closed when another user's asset is mixed in" do
      asset = create(:asset, user: user)
      other_asset = create(:asset)

      post usages_path, params: {
        usage_mode: "bulk",
        asset_ids: [ asset.id, other_asset.id ],
        session_id: session_record.id,
        scene_id: scene.id,
        role: "background"
      }

      expect(response).to have_http_status(:not_found)
      expect(Usage.count).to eq(0)
    end

    it "returns 422 when bulk creation has no selected assets" do
      post usages_path, params: {
        usage_mode: "bulk",
        session_id: session_record.id,
        scene_id: scene.id,
        role: "background"
      }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("素材を選択してください。")
      expect(Usage.count).to eq(0)
    end
  end

  describe "GET /assets/uncategorized" do
    it "renders session-scoped scene select wiring" do
      create(:asset, user: user)
      session_record
      other_session = create(:session, user: user)
      other_scene = other_session.scenes.find_by!(position: Scene::DEFAULT_POSITION)
      post user_session_path, params: { user: { email: user.email, password: "password" } }

      get uncategorized_assets_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('data-controller="scene-select"')
      expect(response.body).to include('data-scene-select-target="session"')
      expect(response.body).to include('data-scene-select-target="scene"')
      expect(response.body).to include("data-session-id=\"#{session_record.id}\"")
      expect(response.body).to include("data-session-id=\"#{other_session.id}\"")
      expect(response.body).to include(other_scene.name)
    end
  end
end
