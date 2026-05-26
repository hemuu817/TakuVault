require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  describe "DELETE /sessions/:id" do
    it "deletes the session and its default_scene" do
      session_record = create(:session, user: user)
      default_scene = session_record.scenes.find_by!(position: 1)

      delete game_session_path(session_record)

      expect(response).to redirect_to(game_sessions_path)
      expect(Session.where(id: session_record.id)).to be_empty
      expect(Scene.where(id: default_scene.id)).to be_empty
    end

    it "does not show a success notice when destroy fails" do
      session_record = create(:session, user: user)
      allow_any_instance_of(Session).to receive(:destroy).and_return(false)

      delete game_session_path(session_record)

      expect(response).to redirect_to(game_session_path(session_record))
      expect(flash[:notice]).to be_nil
      expect(flash[:alert]).to eq("セッションを削除できませんでした。")
    end
  end
end
