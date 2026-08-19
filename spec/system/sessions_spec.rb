require "rails_helper"

RSpec.describe "Sessions", type: :system do
  let(:modern_user_agent) do
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36"
  end

  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before do |example|
    page.driver.header "User-Agent", modern_user_agent unless example.metadata[:js]
  end

  def login(u)
    visit new_user_session_path
    fill_in "user_email", with: u.email
    fill_in "user_password", with: "password"
    click_button "Log in"
    expect(page).to have_css("h1", text: "素材一覧")
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

  def create_audio_asset(user:, display_name:)
    Asset.new(user: user, original_filename: "sound.mp3", display_name: display_name).tap do |asset|
      asset.file.attach(
        io: File.open(Rails.root.join("spec/fixtures/files/valid.png")),
        filename: "sound.mp3",
        content_type: "audio/mpeg",
        identify: false
      )
      asset.save!
    end
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

  it "Session詳細にセッション素材一覧を表示し、空セルを保ったまま素材詳細へ遷移できる" do
    session_record = create(:session, user: user, name: "素材グリッドセッション")
    scene1 = session_record.scenes.find_by!(position: Scene::DEFAULT_POSITION)
    scene2 = create(:scene, session: session_record, name: "追加シーン", position: 2)
    image_asset = create(:asset, user: user, display_name: "画像素材.png")
    audio_asset = create_audio_asset(user: user, display_name: "音声素材.mp3")
    standing_asset = create(:asset, user: user, display_name: "立ち絵素材.png")
    panel_asset = create(:asset, user: user, display_name: "装飾パネル素材.png")
    sound_effect_asset = create_audio_asset(user: user, display_name: "効果音素材.mp3")
    other_user = create(:user, email: "grid-other@example.com")
    hidden_asset = create(:asset, user: other_user, display_name: "他人素材.png")

    create(:usage, asset: image_asset, session: session_record, scene: scene2, role: :background)
    create(:usage, asset: audio_asset, session: session_record, scene: scene2, role: :bgm)
    create(:usage, asset: standing_asset, session: session_record, scene: scene2, role: :standing)
    create(:usage, asset: panel_asset, session: session_record, scene: scene2, role: :panel)
    create(:usage, asset: sound_effect_asset, session: session_record, scene: scene2, role: :sound_effect)
    create(:usage, asset: hidden_asset, session: session_record, scene: scene2, role: :cutin)

    login(user)
    visit game_session_path(session_record)

    expect(page).to have_css("h2", exact_text: "セッション素材一覧")
    expect(page).to have_css("th", text: "背景")
    expect(page).to have_css("th", text: "立ち絵")
    expect(page).to have_css("th", text: "カットイン")
    expect(page).to have_css("th", text: "装飾パネル")
    expect(page).to have_css("th", text: "BGM")
    expect(page).to have_css("th", text: "効果音")
    expect(page).to have_css("th", text: "その他")

    scene1_row = find(:xpath, "//tr[th[normalize-space()='#{scene1.name}']]")
    within(scene1_row) do
      expect(page).not_to have_content("画像素材.png")
      expect(page).not_to have_content("音声素材.mp3")
    end

    scene2_row = find(:xpath, "//tr[th[normalize-space()='追加シーン']]")
    within(scene2_row) do
      expect(page).to have_link("画像素材.png", href: asset_path(image_asset))
      expect(page).to have_link("立ち絵素材.png", href: asset_path(standing_asset))
      expect(page).to have_link("装飾パネル素材.png", href: asset_path(panel_asset))
      expect(page).to have_link("音声素材.mp3", href: asset_path(audio_asset))
      expect(page).to have_link("効果音素材.mp3", href: asset_path(sound_effect_asset))
      within("a[href='#{asset_path(image_asset)}']") do
        expect(page).to have_css("img[alt='']")
        expect(page).to have_css("span", exact_text: "画像素材.png")
      end
      within("a[href='#{asset_path(audio_asset)}']") do
        expect(page).to have_css("img[alt=''][src*='audio-placeholder']")
        expect(page).to have_css("span", exact_text: "音声素材.mp3")
      end
      within("a[href='#{asset_path(sound_effect_asset)}']") do
        expect(page).to have_css("img[alt=''][src*='audio-placeholder']")
        expect(page).to have_css("span", exact_text: "効果音素材.mp3")
      end
      expect(page).not_to have_content("他人素材.png")
      expect(page).not_to have_css("audio")
    end

    click_link "画像素材.png"

    expect(page).to have_current_path(asset_path(image_asset), ignore_query: true)
    expect(page).to have_css("h1", text: "画像素材.png")
  end

  it "Session詳細はUsageがなくてもセッション素材一覧を表示する" do
    session_record = create(:session, user: user, name: "空グリッドセッション")

    login(user)
    visit game_session_path(session_record)

    expect(page).to have_css("h2", exact_text: "セッション素材一覧")
    expect(page).to have_css("tr", text: "scene1")
    expect(page).not_to have_css("table a[href^='/assets/']")
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


  context "with JavaScript", js: true do
    it "allows keyboard focus and horizontal scrolling in both arrow-key directions when the asset grid has no usages" do
      region = nil
      session_record = create(:session, user: user, name: "空グリッドキーボード操作")
      login(user)
      page.current_window.resize_to(360, 800)
      visit game_session_path(session_record)

      region = find("[role='region'][tabindex='0'][aria-labelledby='session-assets-heading']")
      page.execute_script(<<~JS, region)
        const region = arguments[0]
        window.__arrowKeyDiagnostics = { capture: [], bubble: [] }
        const snapshot = (event) => ({
          key: event.key,
          code: event.code,
          targetIsRegion: event.target === region,
          defaultPrevented: event.defaultPrevented,
          scrollLeft: region.scrollLeft
        })
        region.addEventListener("keydown", (event) => {
          window.__arrowKeyDiagnostics.capture.push(snapshot(event))
        }, true)
        region.addEventListener("keydown", (event) => {
          window.__arrowKeyDiagnostics.bubble.push(snapshot(event))
        })
      JS
      expect(region).not_to have_css("a[href^='/assets/']")
      expect(page.evaluate_script("arguments[0].scrollWidth > arguments[0].clientWidth", region)).to be(true)

      page.execute_script("arguments[0].focus()", region)
      expect(page.evaluate_script("document.activeElement === arguments[0]", region)).to be(true)
      initial_scroll_left = page.evaluate_script("arguments[0].scrollLeft", region)

      region.native.send_keys(:arrow_right)
      Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
        page.evaluate_script("arguments[0].scrollLeft", region) > initial_scroll_left
      end
      right_scroll_left = page.evaluate_script("arguments[0].scrollLeft", region)

      region.native.send_keys(:arrow_left)
      Selenium::WebDriver::Wait.new(timeout: Capybara.default_max_wait_time).until do
        page.evaluate_script("arguments[0].scrollLeft", region) < right_scroll_left
      end
    ensure
      begin
        if region
          diagnostics = page.evaluate_script(<<~JS, region)
            ({
              active: document.activeElement === arguments[0],
              scrollLeft: arguments[0].scrollLeft,
              scrollWidth: arguments[0].scrollWidth,
              clientWidth: arguments[0].clientWidth,
              dataController: arguments[0].dataset.controller,
              dataAction: arguments[0].dataset.action,
              events: window.__arrowKeyDiagnostics
            })
          JS
          diagnostics["capabilities"] = page.driver.browser.capabilities.as_json
          warn "ARROW_KEY_DIAGNOSTICS=#{JSON.generate(diagnostics)}"
        end
      rescue StandardError => diagnostic_error
        warn "ARROW_KEY_DIAGNOSTICS_ERROR=#{diagnostic_error.class}: #{diagnostic_error.message}"
      ensure
        page.current_window.resize_to(1400, 1400) if page.driver.is_a?(Capybara::Selenium::Driver)
      end
    end

    it "keeps the previous state while loading and commits URL, selection, detail, flash, and history together" do
      first = create(:session, user: user, name: "切替前セッション")
      second = create(:session, user: user, name: "切替先セッション")
      login(user)
      visit edit_game_session_path(first)
      fill_in "session_name", with: "切替前セッション"
      click_button "更新"

      expect(page).to have_content("セッションを更新しました。")
      original_history_length = page.evaluate_script("history.length")

      page.driver.browser.network_conditions = { latency: 800 }
      click_link second.name

      expect(page).to have_current_path(game_session_path(first))
      expect(page).to have_css("a[href='#{game_session_path(first)}'][aria-current='page']", text: first.name)
      expect(page).not_to have_css("a[href='#{game_session_path(second)}'][aria-current]")
      expect(page).not_to have_css("li[aria-current]")
      expect(page).to have_content("セッション名: #{first.name}")
      expect(page).to have_content("セッションを読み込んでいます…")

      expect(page).to have_current_path(game_session_path(second))
      expect(page).to have_css("a[href='#{game_session_path(second)}'][aria-current='page']", text: second.name)
      expect(page).not_to have_css("a[href='#{game_session_path(first)}'][aria-current]")
      expect(page).not_to have_css("li[aria-current]")
      expect(page).to have_content("セッション名: #{second.name}")
      expect(page).not_to have_content("セッションを更新しました。")
      expect(page).not_to have_content("セッションを読み込んでいます…")
      expect(page).not_to have_content("セッションを読み込めませんでした。")
      expect(page.evaluate_script("history.length")).to eq(original_history_length)
    ensure
      page.driver.browser.delete_network_conditions
    end

    it "keeps the previous workspace after a network failure and retries successfully" do
      first = create(:session, user: user, name: "通信失敗元")
      second = create(:session, user: user, name: "再試行セッション")
      login(user)
      visit game_session_path(first)

      page.driver.browser.network_conditions = { offline: true }
      click_link second.name

      expect(page).to have_current_path(game_session_path(first))
      expect(page).to have_css("a[aria-current='page']", text: first.name)
      expect(page).to have_content("セッション名: #{first.name}")
      expect(page).to have_content("セッションを読み込めませんでした。")
      retry_button = find_button("再試行", visible: true)

      page.driver.browser.network_conditions = { offline: false }
      page.execute_script("arguments[0].click()", retry_button)

      expect(page).to have_current_path(game_session_path(second))
      expect(page).to have_css("a[aria-current='page']", text: second.name)
      expect(page).to have_content("セッション名: #{second.name}")
      expect(page).not_to have_content("セッションを読み込めませんでした。")
    ensure
      page.driver.browser.delete_network_conditions
    end

    it "keeps the previous state when the response has no matching Turbo Frame" do
      first = create(:session, user: user, name: "正常セッション")
      second = create(:session, user: user, name: "不正応答先")
      login(user)
      visit game_session_path(first)

      page.execute_script("arguments[0].href = arguments[1]", find_link(second.name), new_game_session_path)
      click_link second.name

      expect(page).to have_current_path(game_session_path(first))
      expect(page).to have_css("a[aria-current='page']", text: first.name)
      expect(page).to have_content("セッション名: #{first.name}")
      expect(page).to have_content("セッションを読み込めませんでした。")
      expect(page).to have_button("再試行")
    end

    it "applies only the final rapid selection" do
      first = create(:session, user: user, name: "競合元セッション")
      middle = create(:session, user: user, name: "古い要求セッション")
      last = create(:session, user: user, name: "最新要求セッション")
      allow(Sessions::AssetGridQuery).to receive(:new).and_wrap_original do |original, session:|
        sleep 0.8 if session.id == middle.id
        original.call(session: session)
      end

      login(user)
      visit game_session_path(first)

      click_link middle.name
      expect(page).to have_content("セッションを読み込んでいます…")
      click_link last.name

      expect(page).to have_current_path(game_session_path(last))
      expect(page).to have_css("a[aria-current='page']", text: last.name)
      expect(page).to have_content("セッション名: #{last.name}")
      expect(page).not_to have_content("セッション名: #{middle.name}")

      sleep 1
      expect(page).to have_current_path(game_session_path(last))
      expect(page).to have_content("セッション名: #{last.name}")
    end

    it "uses replace navigation, rebuilds on reload, and returns back to the previous page" do
      first = create(:session, user: user, name: "履歴一件目")
      second = create(:session, user: user, name: "履歴二件目")
      login(user)
      click_link "セッション一覧"
      expect(page).to have_current_path(game_sessions_path)

      click_link first.name
      expect(page).to have_current_path(game_session_path(first))
      click_link second.name
      expect(page).to have_current_path(game_session_path(second))

      page.refresh
      expect(page).to have_current_path(game_session_path(second))
      expect(page).to have_css("a[aria-current='page']", text: second.name)
      expect(page).to have_content("セッション名: #{second.name}")
      expect(page).not_to have_content("セッションを読み込んでいます…")
      expect(page).not_to have_content("セッションを読み込めませんでした。")

      page.go_back
      expect(page).to have_css("h1", text: "素材一覧")
    end

    it "preserves alternate-tab link navigation" do
      first = create(:session, user: user, name: "クリック条件元")
      second = create(:session, user: user, name: "クリック条件先")
      login(user)
      visit game_session_path(first)

      page.execute_script("arguments[0].target = '_blank'", find_link(second.name))
      new_window = window_opened_by { click_link second.name }

      expect(page).to have_current_path(game_session_path(first))
      expect(page).to have_content("セッション名: #{first.name}")

      within_window new_window do
        expect(page).to have_current_path(game_session_path(second))
        expect(page).to have_css("a[aria-current='page']", text: second.name)
        expect(page).to have_content("セッション名: #{second.name}")
      end
    end

    it "uses normal page navigation for workspace links other than Session selection" do
      create(:session, user: user, name: "通常リンク確認")
      login(user)
      visit game_sessions_path

      click_link "新規作成"

      expect(page).to have_current_path(new_game_session_path)
      expect(page).to have_content("セッション新規作成")
    end
  end
end
