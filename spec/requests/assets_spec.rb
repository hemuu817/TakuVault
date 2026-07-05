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

  def build_spoofed_png_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/valid.png"),
      "audio/mpeg",
      original_filename: "spoofed.png"
    )
  end

  def build_invalid_png_upload
    Rack::Test::UploadedFile.new(
      Rails.root.join("spec/fixtures/files/fake.png"),
      "image/png",
      original_filename: "fake.png"
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

    it "shows only owned assets" do
      create_asset_for(user, filename: "owner_only.png")
      create_asset_for(other, filename: "other_user.png")

      login_via_http!(user)
      get assets_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("owner_only.png")
      expect(response.body).not_to include("other_user.png")
    end
  end

  describe "GET /assets/:id" do
    it "redirects to sign in when not logged in" do
      asset = create_asset_for(user)

      get asset_path(asset)

      expect(response).to redirect_to(new_user_session_path)
    end

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

  describe "GET /assets/new" do
    it "redirects to sign in when not logged in" do
      get new_asset_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "POST /assets" do
    it "redirects to sign in when not logged in" do
      post assets_path, params: { asset: { files: [ build_uploaded_file ] } }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "returns 422 when no files are provided" do
      login_via_http!(user)

      post assets_path, params: { asset: { files: [] } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when files count exceeds the limit" do
      stub_const("Assets::UploadValidator::MAX_FILES_PER_UPLOAD", 1)
      login_via_http!(user)

      post assets_path, params: {
        asset: { files: [ build_uploaded_file("a.png"), build_uploaded_file("b.png") ] }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 when bulk create rejects the upload" do
      login_via_http!(user)
      allow(Assets::BulkCreate).to receive(:call)
        .and_return(Assets::BulkCreate::Result.new(error: :invalid_content_type))

      post assets_path, params: { asset: { files: [ build_uploaded_file("a.png") ] } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "ignores submitted kind and stores the blob-derived kind" do
      login_via_http!(user)

      post assets_path, params: {
        asset: {
          files: [ build_uploaded_file("tamper.png") ],
          kind: "audio"
        }
      }

      expect(response).to redirect_to(new_asset_path)
      expect(Asset.last).to be_image
    end

    it "送信されたcontent_typeではなくサーバ側で確定したBlob content_typeからkindを保存する" do
      login_via_http!(user)

      post assets_path, params: {
        asset: {
          files: [ build_spoofed_png_upload ]
        }
      }

      asset = Asset.last
      expect(response).to redirect_to(new_asset_path)
      expect(asset.file.blob.content_type).to eq("image/png")
      expect(asset).to be_image
    end

    it "形式不正ファイルをotherとして保存しない" do
      login_via_http!(user)

      expect do
        post assets_path, params: {
          asset: {
            files: [ build_invalid_png_upload ]
          }
        }
      end.not_to change(Asset, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /assets/:id/edit" do
    it "redirects to sign in when not logged in" do
      asset = create_asset_for(user)

      get edit_asset_path(asset)

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "PATCH /assets/:id" do
    it "redirects to sign in when not logged in" do
      asset = create_asset_for(user)

      patch asset_path(asset), params: { asset: { display_name: "new" } }

      expect(response).to redirect_to(new_user_session_path)
    end

    it "falls back to original_filename when display_name is blank" do
      asset = create_asset_for(user, filename: "keep_name.png")

      login_via_http!(user)
      patch asset_path(asset), params: { asset: { display_name: "" } }

      expect(response).to redirect_to(asset_path(asset))
      expect(asset.reload.display_name).to eq("keep_name.png")
    end

    it "ignores submitted kind when updating display_name" do
      asset = create_asset_for(user, filename: "keep_kind.png")
      expect(asset).to be_image

      login_via_http!(user)
      patch asset_path(asset), params: { asset: { display_name: "renamed", kind: "audio" } }

      expect(response).to redirect_to(asset_path(asset))
      expect(asset.reload.display_name).to eq("renamed")
      expect(asset).to be_image
    end

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
    it "redirects to sign in when not logged in" do
      asset = create_asset_for(user)

      delete asset_path(asset)

      expect(response).to redirect_to(new_user_session_path)
    end

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
