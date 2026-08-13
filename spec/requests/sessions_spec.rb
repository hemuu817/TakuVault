require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /sessions" do
    it "renders the integrated workspace without selecting the first session" do
      older = create(:session, user: user, name: "古いセッション", created_at: 2.days.ago)
      newer = create(:session, user: user, name: "新しいセッション", created_at: 1.day.ago)

      expect(Sessions::AssetGridQuery).not_to receive(:new)

      get game_sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<!DOCTYPE html>", "<body")
      expect(Nokogiri::HTML5(response.body).at_css("turbo-frame#session-workspace")).to be_present
      expect(response.body).to include("セッションが選択されていません")
      expect(response.body.index(newer.name)).to be < response.body.index(older.name)
      expect(response.body).not_to include("aria-current=\"page\"")
      expect(response.body).to include("href=\"#{uncategorized_assets_path}\"")
      expect(response.body).to include("未整理の素材")
    end

    it "renders the empty state and creation link when there are no sessions" do
      get game_sessions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("セッションがまだありません")
      expect(response.body).to include("最初のセッションを作成")
    end

    it "only lists sessions in the policy scope" do
      owned = create(:session, user: user, name: "自分のセッション")
      other = create(:session, user: create(:user), name: "他人のセッション")

      get game_sessions_path

      expect(response.body).to include(owned.name)
      expect(response.body).not_to include(other.name)
    end

    it "disables Turbo caching" do
      get game_sessions_path

      expect(response.body).to include('<meta name="turbo-cache-control" content="no-cache">')
    end

    it "returns the complete unselected workspace in a Turbo Frame response" do
      create(:session, user: user, name: "一覧セッション")

      get game_sessions_path, headers: { "Turbo-Frame" => "session-workspace" }

      document = Nokogiri::HTML5(response.body)
      frames = document.css("turbo-frame#session-workspace")
      expect(response).to have_http_status(:ok)
      expect(frames.one?).to be(true)
      expect(frames.first.text).to include("一覧セッション", "セッションが選択されていません")
      expect(frames.first["data-turbo-action"]).to eq("replace")
      expect(frames.first["target"]).to eq("_top")
    end
  end

  describe "GET /sessions/:id" do
    it "renders the session list and only the selected session detail" do
      selected = create(:session, user: user, name: "選択中セッション")
      another = create(:session, user: user, name: "別セッション")
      query = instance_double(Sessions::AssetGridQuery, call: Sessions::AssetGridQuery.new(session: selected).call)

      expect(Sessions::AssetGridQuery).to receive(:new).once.with(session: selected).and_return(query)

      get game_session_path(selected)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<!DOCTYPE html>", "<body")
      expect(response.body).to include(selected.name, another.name, "セッション詳細")
      expect(response.body).to include("aria-current=\"page\"")
    end

    it "returns the selected list and detail as one Turbo Frame" do
      selected = create(:session, user: user, name: "Frame選択中")
      another = create(:session, user: user, name: "Frame一覧項目")

      get game_session_path(selected), headers: { "Turbo-Frame" => "session-workspace" }

      document = Nokogiri::HTML5(response.body)
      frames = document.css("turbo-frame#session-workspace")
      expect(response).to have_http_status(:ok)
      expect(frames.one?).to be(true)
      expect(frames.first.text).to include(selected.name, another.name, "セッション詳細")
      expect(frames.first.at_css("a[aria-current='page']").text).to include(selected.name)
      expect(frames.first.at_css("a[href='#{game_session_path(another)}']")["data-turbo-frame"]).to eq("session-workspace")
      expect(frames.first.css("[data-session-switcher-target='list'], [data-session-switcher-target='detail']")).to be_empty
    end

    it "disables Turbo caching" do
      selected = create(:session, user: user)

      get game_session_path(selected)

      expect(response.body).to include('<meta name="turbo-cache-control" content="no-cache">')
    end

    it "returns 404 for a missing session" do
      get game_session_path(0)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for another user's session" do
      other_session = create(:session, user: create(:user))

      get game_session_path(other_session)

      expect(response).to have_http_status(:not_found)
    end

    it "does not retain flash consumed by the previous workspace response" do
      selected = create(:session, user: user)

      post game_sessions_path, params: { session: { name: "通知元セッション" } }
      follow_redirect!
      expect(response.body).to include("セッションを作成しました。")

      get game_session_path(selected)
      expect(response.body).not_to include("セッションを作成しました。")
    end
  end

  describe "DELETE /sessions/:id" do
    it "deletes the selected session and returns to the unselected workspace" do
      session_record = create(:session, user: user)
      default_scene = session_record.scenes.find_by!(position: 1)

      delete game_session_path(session_record), params: { selected_session_id: session_record.id }

      expect(response).to redirect_to(game_sessions_path)
      expect(Session.where(id: session_record.id)).to be_empty
      expect(Scene.where(id: default_scene.id)).to be_empty
    end

    it "deletes an unselected session and keeps the selected session" do
      selected = create(:session, user: user)
      deleted = create(:session, user: user)

      delete game_session_path(deleted), params: { selected_session_id: selected.id }

      expect(response).to redirect_to(game_session_path(selected))
      expect(Session.exists?(deleted.id)).to be(false)
    end

    it "deletes from the unselected workspace and remains unselected" do
      deleted = create(:session, user: user)

      delete game_session_path(deleted)

      expect(response).to redirect_to(game_sessions_path)
    end

    it "keeps the selected session when deletion fails" do
      selected = create(:session, user: user)
      deleted = create(:session, user: user)
      allow_any_instance_of(Session).to receive(:destroy).and_return(false)

      delete game_session_path(deleted), params: { selected_session_id: selected.id }

      expect(response).to redirect_to(game_session_path(selected))
      expect(flash[:notice]).to be_nil
      expect(flash[:alert]).to eq("セッションを削除できませんでした。")
    end

    it "returns to the selected target when its deletion fails" do
      session_record = create(:session, user: user)
      allow_any_instance_of(Session).to receive(:destroy).and_return(false)

      delete game_session_path(session_record), params: { selected_session_id: session_record.id }

      expect(response).to redirect_to(game_session_path(session_record))
      expect(flash[:notice]).to be_nil
      expect(flash[:alert]).to eq("セッションを削除できませんでした。")
    end

    it "returns to the unselected workspace when deletion fails without a selection" do
      session_record = create(:session, user: user)
      allow_any_instance_of(Session).to receive(:destroy).and_return(false)

      delete game_session_path(session_record)

      expect(response).to redirect_to(game_sessions_path)
      expect(flash[:notice]).to be_nil
      expect(flash[:alert]).to eq("セッションを削除できませんでした。")
    end

    invalid_selected_ids = {
      "an empty string" => "",
      "a missing ID" => 99_999_999,
      "an array" => [ "1" ],
      "a hash" => { id: "1" },
      "a partially numeric string" => "1abc",
      "zero" => "0",
      "a negative number" => "-1",
      "whitespace" => "   "
    }

    invalid_selected_ids.each do |description, selected_session_id|
      it "treats #{description} as unselected" do
        deleted = create(:session, user: user)

        delete game_session_path(deleted), params: { selected_session_id: selected_session_id }

        expect(response).to redirect_to(game_sessions_path)
      end
    end

    it "treats another user's session ID as unselected" do
      deleted = create(:session, user: user)
      other_session = create(:session, user: create(:user))

      delete game_session_path(deleted), params: { selected_session_id: other_session.id }

      expect(response).to redirect_to(game_sessions_path)
    end
  end
end
