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

    expect(page).to have_css("h1", text: "where_used.png")
    expect(page).to have_css("h2", exact_text: "詳細")
    expect(page).to have_css("th", text: "種類")
    expect(page).to have_link("Aセッション", href: game_session_path(alpha_session))
    expect(page).to have_content("scene2")
    expect(page).to have_content("背景")
    expect(page).to have_content("カットイン")
    expect(page).to have_content("Bセッション")
    expect(page).to have_content("その他")
    expect(page).not_to have_content("他人セッション")

    session_names = page.all("table tbody tr td:first-child").map(&:text)
    scene_names = page.all("table tbody tr .usage-scene-select").map { |select| select.find("option[selected]").text }
    role_names = page.all("table tbody tr .usage-role-select").map { |select| select.find("option[selected]").text }

    expect(session_names).to eq([ "Aセッション", "Aセッション", "Aセッション", "Bセッション" ])
    expect(scene_names).to eq([ "scene2", "scene2", "scene3", "scene1" ])
    expect(role_names).to eq([ "背景", "カットイン", "BGM", "その他" ])
    first_scene_select = page.all("table tbody tr .usage-scene-select").first
    first_role_select = page.all("table tbody tr .usage-role-select").first
    expect(first_scene_select.find("option[selected]").text).to eq("scene2")
    expect(first_scene_select.all("option").map(&:text)).to contain_exactly(
      "選択してください",
      "scene1",
      "scene2",
      "scene3"
    )
    expect(first_role_select.find("option[selected]").text).to eq("背景")
    expect(first_role_select.all("option").map(&:text)).to eq([ "選択してください", "背景", "立ち絵", "カットイン", "装飾パネル", "BGM", "効果音", "その他" ])

    first_scene_select.select("scene3")
    first_role_select.select("効果音")
    expect(first_scene_select.value).to eq(alpha_scene_3.id.to_s)
    expect(first_role_select.value).to eq("sound_effect")
    click_button "更新", match: :first

    expect(page).to have_current_path(asset_path(asset), ignore_query: true)
    expect(page).to have_content("詳細を更新しました。")
    expect(background_usage.reload.session).to eq(alpha_session)
    expect(background_usage.scene).to eq(alpha_scene_3)
    expect(background_usage.role).to eq("sound_effect")
    expect(page).to have_content("効果音")

    updated_row = find(:xpath, "//select[@id='usage_scene_id_#{background_usage.id}']/ancestor::tr")
    updated_row.click_link("Aセッション")
    expect(page).to have_current_path(game_session_path(alpha_session), ignore_query: true)

    expect(page).to have_content("セッション詳細")
    expect(page).to have_content("Aセッション")
  end

  it "素材詳細の追加フォームで追加roleを選択してWhere usedへ表示できる" do
    asset = create(:asset, user: user, original_filename: "new_where_used.png", display_name: "new_where_used.png")
    session_record = create(:session, user: user, name: "追加先セッション")
    scene = session_record.scenes.find_by!(position: Scene::DEFAULT_POSITION)

    log_in(user)
    visit asset_path(asset)

    add_form = find(:xpath, "//input[@name='asset_id' and @value='#{asset.id}']/ancestor::form")
    within(add_form) do
      role_select = find("select[name='role']")
      expect(role_select.all("option").map(&:text)).to eq([ "選択してください", "背景", "立ち絵", "カットイン", "装飾パネル", "BGM", "効果音", "その他" ])

      find("select[name='session_id']").select("追加先セッション")
      find("select[name='scene_id']").select("追加先セッション / #{scene.name}")
      role_select.select("装飾パネル")
      click_button "詳細を追加"
    end

    expect(page).to have_current_path(asset_path(asset), ignore_query: true)
    expect(page).to have_content("詳細を追加しました。")
    expect(page).to have_link("追加先セッション", href: game_session_path(session_record))
    expect(page).to have_content(scene.name)
    expect(page).to have_content("装飾パネル")
    expect(asset.usages.reload.map(&:role)).to eq([ "panel" ])
  end

  it "素材詳細で使用先がない場合は未整理状態と未整理一覧への導線を表示する" do
    asset = create(:asset, user: user, original_filename: "unused.png", display_name: "unused.png")

    log_in(user)
    visit asset_path(asset)

    expect(page).to have_css("h1", text: "unused.png")
    expect(page).to have_css("h2", exact_text: "詳細")
    expect(page).to have_content("詳細：未設定（未整理）")
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
