require "rails_helper"

RSpec.describe "Sessions", type: :system do
  let(:modern_user_agent) do
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
  end

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    page.driver.header "User-Agent", modern_user_agent
  end

  def login(u)
    visit new_user_session_path
    fill_in "user_email", with: u.email
    fill_in "user_password", with: "password"
    click_button "Log in"
  end

  def navigate_to_new_session_from_assets
    expect(page).to have_content("素材一覧")
    click_link "セッション一覧"
    expect(page).to have_content("セッション一覧")
    click_link "新規作成"
    expect(page).to have_content("セッション新規作成")
  end

  def navigate_to_sessions_from_assets
    expect(page).to have_content("素材一覧")
    click_link "セッション一覧"
    expect(page).to have_content("セッション一覧")
  end

  it "素材一覧とセッション一覧を相互に移動できる" do
    login(user)

    navigate_to_sessions_from_assets
    click_link "素材一覧"

    expect(page).to have_content("素材一覧")
  end

  it "Session作成 → default_scene（position=1）が生成される" do
    login(user)

    navigate_to_new_session_from_assets
    fill_in "session_name", with: "テストセッション"
    click_button "登録"

    expect(page).to have_content("テストセッション")
    created = Session.find_by!(name: "テストセッション")
    expect(created.scenes.where(position: 1).count).to eq(1)
    expect(created.scenes.find_by!(position: 1).name).to eq("scene1")
  end

  it "Session詳細からSceneを追加・編集・削除できる" do
    login(user)

    navigate_to_new_session_from_assets
    fill_in "session_name", with: "シーン操作セッション"
    click_button "登録"

    click_link "シーンを追加"
    fill_in "scene_name", with: "追加シーン"
    click_button "登録"

    expect(page).to have_content("2.")
    expect(page).to have_content("追加シーン")

    click_link "編集", href: edit_game_session_scene_path(Session.find_by!(name: "シーン操作セッション"), Scene.find_by!(name: "追加シーン"))
    fill_in "scene_name", with: "更新シーン"
    click_button "更新"

    expect(page).to have_content("更新シーン")
    within("li", text: "更新シーン") do
      click_button "削除"
    end

    expect(page).not_to have_content("更新シーン")
  end

  it "room_urlリンクにtargetとrelが付く" do
    login(user)

    navigate_to_new_session_from_assets
    fill_in "session_name", with: "URL付きセッション"
    fill_in "session_room_url", with: "https://ccfolia.com/rooms/example"
    click_button "登録"

    link = find_link("https://ccfolia.com/rooms/example")
    expect(link[:target]).to eq("_blank")
    expect(link[:rel]).to eq("noopener noreferrer")
  end

  it "room_url に不正スキームを入力すると保存できない" do
    login(user)

    navigate_to_new_session_from_assets
    fill_in "session_name", with: "不正URLセッション"
    fill_in "session_room_url", with: "javascript:alert(1)"
    click_button "登録"

    expect(Session.where(name: "不正URLセッション")).to be_empty
  end

  it "他人のSession URLを直打ちすると404になる" do
    login(user)
    other_session = create(:session, user: other_user)

    visit game_session_path(other_session)

    expect(page.status_code).to eq(404)
  end

  it "Sessionを削除すると一覧から消える" do
    login(user)
    session_record = create(:session, user: user, name: "削除対象セッション")

    visit game_sessions_path
    expect(page).to have_content("削除対象セッション")

    within("li", text: "削除対象セッション") do
      click_button "削除"
    end

    expect(page).to have_current_path(game_sessions_path)
    expect(page).to have_content("セッションを削除しました。")
    expect(page).not_to have_content("削除対象セッション")
    expect(Session.where(id: session_record.id)).to be_empty
  end
end
