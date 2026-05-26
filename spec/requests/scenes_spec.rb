require "rails_helper"

RSpec.describe "Scenes", type: :request do
  let(:password) { "password" }
  let(:user) { create(:user, password: password, password_confirmation: password) }
  let(:other) { create(:user, password: password, password_confirmation: password) }

  def login_via_http!(as_user)
    post user_session_path, params: { user: { email: as_user.email, password: password } }
    get game_sessions_path
    expect(response).to have_http_status(:ok)
  end

  describe "POST /sessions/:session_id/scenes" do
    it "creates scenes from position 2" do
      session_record = create(:session, user: user)

      login_via_http!(user)
      post game_session_scenes_path(session_record), params: { scene: { name: "追加シーン" } }

      expect(response).to redirect_to(game_session_path(session_record))
      expect(session_record.scenes.order(:position).pluck(:position)).to eq([ 1, 2 ])
      expect(session_record.scenes.find_by(position: 2).name).to eq("追加シーン")
    end

    it "creates a scene name from position when name is blank" do
      session_record = create(:session, user: user)

      login_via_http!(user)
      post game_session_scenes_path(session_record), params: { scene: { name: "" } }

      expect(response).to redirect_to(game_session_path(session_record))
      expect(session_record.scenes.find_by(position: 2).name).to eq("scene2")
    end

    it "returns 404 for someone else's session" do
      other_session = create(:session, user: other)

      login_via_http!(user)
      post game_session_scenes_path(other_session), params: { scene: { name: "不正" } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /sessions/:session_id/scenes/:id" do
    it "allows changing default_scene name" do
      session_record = create(:session, user: user)
      default_scene = session_record.scenes.find_by!(position: 1)

      login_via_http!(user)
      patch game_session_scene_path(session_record, default_scene),
            params: { scene: { name: "導入" } }

      expect(response).to redirect_to(game_session_path(session_record))
      expect(default_scene.reload.name).to eq("導入")
      expect(default_scene.position).to eq(1)
    end

    it "returns 422 when trying to move default_scene" do
      session_record = create(:session, user: user)
      default_scene = session_record.scenes.find_by!(position: 1)

      login_via_http!(user)
      patch game_session_scene_path(session_record, default_scene),
            params: { scene: { name: "導入", position: 2 } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(default_scene.reload.name).to eq("scene1")
      expect(default_scene.position).to eq(1)
    end

    it "returns 422 without auto-naming when name is blank on update" do
      session_record = create(:session, user: user)
      scene = create(:scene, session: session_record, position: 2, name: "追加シーン")

      login_via_http!(user)
      patch game_session_scene_path(session_record, scene),
            params: { scene: { name: "" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(scene.reload.name).to eq("追加シーン")
    end
  end

  describe "DELETE /sessions/:session_id/scenes/:id" do
    it "returns 404 when deleting default_scene directly" do
      session_record = create(:session, user: user)
      default_scene = session_record.scenes.find_by!(position: 1)

      login_via_http!(user)
      delete game_session_scene_path(session_record, default_scene)

      expect(response).to have_http_status(:not_found)
      expect(Scene.exists?(default_scene.id)).to be(true)
    end

    it "deletes non-default scenes" do
      session_record = create(:session, user: user)
      scene = create(:scene, session: session_record, position: 2)

      login_via_http!(user)
      delete game_session_scene_path(session_record, scene)

      expect(response).to redirect_to(game_session_path(session_record))
      expect(Scene.exists?(scene.id)).to be(false)
    end
  end
end
