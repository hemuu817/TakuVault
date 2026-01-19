require "rails_helper"

RSpec.describe "Assets", type: :request do
  let(:password) { "password" }
  let(:user)  { create(:user, password: password, password_confirmation: password) }
  let(:other) { create(:user, password: password, password_confirmation: password) }

  def build_uploaded_file(name = "valid.png")
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/valid.png"),
      "image/png",
      original_filename: name
    )
  end

  def create_asset_for(owner, filename: "owned.png")
    asset = Asset.new(
      user: owner,
      original_filename: filename,
      display_name: filename
    )
    asset.file.attach(build_uploaded_file(filename))
    asset.save!
    asset
  end

  # 本番と同じ経路でログインを成立させる（Devise helper に依存しない）
  def login_via_http!(as_user)
    post user_session_path, params: { user: { email: as_user.email, password: password } }

    # 成功時は通常 302（リダイレクト）。失敗すると 200 のまま再描画になりがち。
    # どちらでも「実際にログインできたか」は次のGETで判定するのが確実。
    get assets_path
    expect(response).to have_http_status(:ok),
      "login failed: status=#{response.status} location=#{response.headers['Location']}"
  end

  describe "GET /assets" do
    it "redirects to sign in when not logged in" do
      get assets_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns success when logged in" do
      login_via_http!(user)
      get assets_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /assets/:id" do
    it "returns 404 when accessing someone else's asset" do
      other_asset = create_asset_for(other)

      expect(other_asset).to be_persisted
      expect(other_asset.user_id).to eq(other.id)
      expect(user.id).not_to eq(other.id)

      login_via_http!(user)
      get asset_path(other_asset)

      expect(response).to have_http_status(:not_found),
        "status=#{response.status} location=#{response.headers['Location']}"
    end
  end

  describe "PATCH /assets/:id" do
    it "returns 404 when updating someone else's asset" do
      other_asset = create_asset_for(other)

      expect(other_asset).to be_persisted
      expect(other_asset.user_id).to eq(other.id)
      expect(user.id).not_to eq(other.id)

      login_via_http!(user)
      patch asset_path(other_asset), params: { asset: { display_name: "new" } }

      expect(response).to have_http_status(:not_found),
        "status=#{response.status} location=#{response.headers['Location']}"
    end
  end

  describe "DELETE /assets/:id" do
    it "returns 404 when deleting someone else's asset" do
      other_asset = create_asset_for(other)

      expect(other_asset).to be_persisted
      expect(other_asset.user_id).to eq(other.id)
      expect(user.id).not_to eq(other.id)

      login_via_http!(user)
      delete asset_path(other_asset)

      expect(response).to have_http_status(:not_found),
        "status=#{response.status} location=#{response.headers['Location']}"
    end
  end
end
