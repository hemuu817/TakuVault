require "rails_helper"

RSpec.describe "Assets", type: :system do
  let(:modern_user_agent) do
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
  end

  let(:user) { create(:user, email: "system@example.com") }

  before do
    page.driver.header "User-Agent", modern_user_agent
  end

  def log_in(as_user)
    visit new_user_session_path
    fill_in "user_email", with: as_user.email
    fill_in "user_password", with: "password"
    click_button "Log in"
  end

  it "複数選択アップロードで複数Assetが作成される" do
    log_in(user)

    visit new_asset_path
    attach_file "asset_files", [
      Rails.root.join("spec/fixtures/files/valid.png"),
      Rails.root.join("spec/fixtures/files/valid2.png")
    ]
    click_button "アップロード"

    expect(page).to have_current_path(new_asset_path, ignore_query: true)
    expect(page).to have_content("アップロードしました")

    click_link "一覧へ戻る"

    expect(page).to have_content("素材一覧")
    expect(page).to have_content("valid.png")
    expect(page).to have_content("valid2.png")
  end

  it "素材詳細で使用先を安定した順序で表示し、セッション詳細へ遷移できる" do
    asset = create(:asset, user: user, original_filename: "where_used.png", display_name: "where_used.png")
    other_user = create(:user, email: "mixed-session@example.com")
    beta_session = create(:session, user: user, name: "Bセッション")
    alpha_session = create(:session, user: user, name: "Aセッション")
    hidden_session = create(:session, user: other_user, name: "他人セッション")
    alpha_scene_2 = create(:scene, session: alpha_session, name: "scene2", position: 2)
    alpha_scene_3 = create(:scene, session: alpha_session, name: "scene3", position: 3)

    background_usage = create(:usage, asset: asset, session: alpha_session, scene: alpha_scene_2, role: :background)
    create(:usage, asset: asset, session: alpha_session, scene: alpha_scene_2, role: :cutin)
    create(:usage, asset: asset, session: alpha_session, scene: alpha_scene_3, role: :bgm)
    create(:usage, asset: asset, session: beta_session, scene: beta_session.scenes.find_by!(position: Scene::DEFAULT_POSITION), role: :other)
    create(:usage, asset: asset, session: hidden_session, scene: hidden_session.scenes.find_by!(position: Scene::DEFAULT_POSITION), role: :other)

    log_in(user)
    visit asset_path(asset)

    expect(page).to have_content("使用先")
    expect(page).to have_link("Aセッション", href: game_session_path(alpha_session))
    expect(page).to have_content("scene2")
    expect(page).to have_content("背景")
    expect(page).to have_content("カットイン")
    expect(page).to have_content("Bセッション")
    expect(page).to have_content("その他")
    expect(page).not_to have_content("他人セッション")

    session_names = page.all("table tbody tr td:first-child").map(&:text)
    scene_names = page.all("table tbody tr td:nth-child(2)").map(&:text)
    role_names = page.all("table tbody tr td:nth-child(3)").map(&:text)

    expect(session_names).to eq([ "Aセッション", "Aセッション", "Aセッション", "Bセッション" ])
    expect(scene_names).to eq([ "scene2", "scene2", "scene3", "scene1" ])
    expect(role_names).to eq([ "背景", "カットイン", "BGM", "その他" ])

    page.find("table tbody tr:first-child").click_link("Aセッション")
    expect(page).to have_current_path(game_session_path(background_usage.session), ignore_query: true)
    expect(page).to have_content("セッション詳細")
    expect(page).to have_content("Aセッション")
  end

  it "素材詳細で使用先がない場合は未整理状態と未整理一覧への導線を表示する" do
    asset = create(:asset, user: user, original_filename: "unused.png", display_name: "unused.png")

    log_in(user)
    visit asset_path(asset)

    expect(page).to have_content("使用先：未設定（未整理）")
    expect(page).to have_link("未整理一覧へ", href: uncategorized_assets_path)
  end

  it "他人の素材詳細URL直打ちは拒否される" do
    other_user = create(:user, email: "other-system@example.com")
    other_asset = create(:asset, user: other_user, original_filename: "other.png", display_name: "other.png")

    log_in(user)
    visit asset_path(other_asset)

    expect(page).to have_current_path(asset_path(other_asset), ignore_query: true)
    expect(page.status_code).to eq(404)
  end
end
